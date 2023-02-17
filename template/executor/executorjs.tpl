package {{.Code}}

import (
	"{{.Path}}/common"
	"fmt"
	"github.com/dop251/goja"
	"github.com/dop251/goja_nodejs/require"
	"github.com/kuchensheng/bintools/http"
	"github.com/kuchensheng/bintools/logger"
	"github.com/kuchensheng/bintools/trace/trace"
	"runtime/debug"
	"strconv"
	"strings"
	"time"
)

var scriptEnginFunc = func(context *http.Context) *goja.Runtime {
	scriptEngine := goja.New()
	scriptEngine.Set("ctx", context)
	scriptEngine.Set("getValueByKey", func(ctx *http.Context, key string) any {
		value := common.GetContextValue(ctx, key)
		logger := ctx.Logger()
		logger.Info("获取键=%s的值：%v", key, value)
		if value != nil {
			return value
		}
		return ""
	})
	scriptEngine.Set("setValueByKey", func(ctx *http.Context, key string, value any) {
		common.SetResultValue(ctx, key, value)
	})
	registry := new(require.Registry)
	registry.Enable(scriptEngine)
	//设定最长执行时间：1分钟
	time.AfterFunc(time.Minute, func() {
		scriptEngine.Interrupt("timeout")
	})
	return scriptEngine
}

//ExecuteJavaScript 执行JS脚本,返回执行结果或者错误信息
func ExecuteJavaScript(ctx *http.Context, step common.ApixStep) error {
	logger := ctx.Logger()
	tracer, _ := ctx.Get(common.TRACER)
	if tracer == nil {
		tracer = trace.NewServerTracer(ctx.Request)
		ctx.Set(common.TRACER, tracer)
	}

	serverTracer := tracer.(*trace.ServerTracer)
	clientTracer := serverTracer.NewClientWithHeader(&ctx.Request.Header)
	pk := common.GetPackage(ctx)
	ls := common.LogStruct{PK: pk, TraceId: serverTracer.TracId}
	ls.Info("开始执行JS脚本...")
	clientTracer.TraceName = "执行脚本节点:" + step.GraphId
	defer func() {
		if x := recover(); x != nil {
			ls.Error("JS脚本执行异常，panic is :%v", x)
			fmt.Printf("%s\n", debug.Stack())
			clientTracer.EndTraceError(x.(error))
		}
	}()
	ls.Info("初始化JS引擎...")
	//初始化JS引擎
	scriptEngine := scriptEnginFunc(ctx)
	ls.Info("JS引擎初始化完成，开始执行JS脚本优化...")
	script := replaceScript(step.Script.Script,&logger)
	ls.Info("JS脚本优化完成，开始执行JS脚本：%s", script)
	if v, err := scriptEngine.RunString(script); err != nil {
		ls.Error("JS脚本执行错误,%s", err.Error())
		clientTracer.EndTraceError(err)
		return common.NewException(step.GraphId, "", err.Error())
	} else {
		ls.Info("JS脚本执行完成，开始解析执行结果...")
		clientTracer.EndTraceOk()
		var result any
		if v != nil || v.ExportType() != nil {
			result = v.Export()
		} else {
			result = v.String()
		}
		ls.Info("获取JS执行结果:%+v", result)
		common.SetResultValue(ctx, fmt.Sprintf("%s%s%s", common.KEY_TOKEN, step.GraphId, ".$resp.export"), result)
		return nil
	}
}

func replaceScript(script string,logger *logger.Logger) string {
	logger.Info("替换前的脚本内容:%s", script)
	split := strings.Split(script, "\n")
	var placeholder []common.Pair[string, string]
	var noSpaceLines []string
	for _, s := range split {
		if s != "" && strings.TrimSpace(s) != "" {
			noSpaceLines = append(noSpaceLines, s)
		}
	}
	for i, s := range noSpaceLines {
		s = strings.TrimSpace(s)
		if strings.HasPrefix(s, "return") {
			sb := strings.Builder{}
			for _, c := range placeholder {
				sb.WriteString("\n")
				sb.WriteString(fmt.Sprintf(`setValueByKey(ctx,"%s",%v)`, strings.TrimSpace(c.Second), c.First))
			}
			split[i] = fmt.Sprintf("%s\n%s\n", s, sb.String())
			placeholder = nil
		}

		if validToken(s) {
			noSpaceLines[i], placeholder = replaceGetOrSetValue(s, placeholder)
		}
	}

	script = strings.Join(noSpaceLines, "\n")
	for _, c := range placeholder {
		script = strings.ReplaceAll(script, c.Second, c.First)
	}
	sb := strings.Builder{}
	sb.Write([]byte(script))
	for _, c := range placeholder {
		sb.WriteString("\n")
		sb.WriteString(fmt.Sprintf(`setValueByKey(ctx,"%s",%v)`, strings.TrimSpace(c.Second), c.First))
	}
	script = sb.String()

	logger.Info("替换后的脚本内容:%s", script)
	return script
}

func replaceGetOrSetValue(s string, placeholder []common.Pair[string, string]) (string, []common.Pair[string, string]) {
	if strings.Contains(s, "=") {
		keys := strings.Split(s, "=")
		first := strings.TrimSpace(keys[0])
		first, placeholder = replaceGetOrSetValue(first, placeholder)
		second := strings.TrimSpace(keys[1])
		second, placeholder = replaceGetOrSetValue(second, placeholder)
		//获取值
		if validToken(second) {
			keys[1] = fmt.Sprintf(`getValueByKey(ctx,"%s")`, second)
		}
		//赋值动作
		if validToken(first) {
			random := "a" + strconv.FormatInt(time.Now().UnixMilli(), 10)
			placeholder = append(placeholder, common.Pair[string, string]{random, keys[0]})
			keys[0] = random
			if !strings.HasPrefix(keys[0], "let") {
				keys[0] = "let " + keys[0]
			}
		}
		return strings.Join(keys, "="), placeholder
	} else if strings.Contains(s, ":") {
		keys := strings.Split(s, ":")
		//first := strings.TrimSpace(keys[0])
		second := strings.TrimSpace(keys[1])
		containsComman := strings.Contains(second, ",")
		if containsComman {
			second = strings.ReplaceAll(second, ",", "")
		}

		//获取值
		if validToken(second) {
			keys[1] = fmt.Sprintf(`getValueByKey(ctx,"%s")`, second)
		}
		if containsComman {
			keys[1] = keys[1] + ","
		}
		return strings.Join(keys, ":"), placeholder
	}
	return s, placeholder
}

func validToken(content string) bool {
	return strings.Contains(content, common.KEY_TOKEN) && strings.Contains(content, common.KEY_REQ_CONNECTOR)
}
