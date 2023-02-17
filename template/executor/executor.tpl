package main

import (
	"{{.Path}}/common"
	"{{.Path}}/{{.Code}}"
	"fmt"
	"github.com/kuchensheng/bintools/http"
	_ "github.com/kuchensheng/bintools/logger"
	"encoding/json"
)

var testVar = {{.}}
var apixData = func() common.ApixData {
	var data common.ApixData
	var str = `{{.ApixDataStr}}`
	if err := json.Unmarshal([]byte(str), &data); err != nil {
		panic(err)
	}
	return data
}()
func Executor{{.Key}}(ctx *http.Context){
	log := ctx.Logger()
	log.Info("当前请求:%s,Method:%s,执行文件:[Executor{{.Key}}]", ctx.Request.URL.Path, ctx.Request.Method)
	paramterMap := {{.Code}}.SetParameterMap(ctx)

	if err := {{.Code}}.CheckParameter(apixData.Rule.Api.Parameters,paramterMap);err != nil {
		log.Warn("缺少必填参数:%v", err)
		ctx.JSON(400,http.BusinessError{
			Code: 20400,
			Message: fmt.Sprintf("缺少必填参数:%s", err.Error()),
			Data: err,
		})
		ctx.Abort()
		return
	}
	ctx.Set(common.RESULTMAP,make(map[string]any))

	if err := executeStep(ctx, "", apixData.Rule.Steps); err != nil {
		log.Warn("流程执行失败:%v", err)
		ctx.JSON(400,http.BusinessError{
			Code: 20400,
			Message: fmt.Sprintf("流程执行失败:%s", err.Error()),
			Data: err,
		})
		ctx.Abort()
		return
	}
	log.Info("流程步骤执行完毕，开始组装结果映射...")
	if result,err := common.BuildSuccessResponse(ctx, apixData.Rule.Response);err != nil {
		log.Warn("结果组装执行失败:%v", err)
		ctx.JSON(400,http.BusinessError{
			Code: 20400,
			Message: fmt.Sprintf("流程执行失败:%s", err.Error()),
			Data: err,
		})
		return
	} else {
		ctx.JSONoK(result)
	}
}

//todo 下个迭代，这里将直接用模板生成执行代码，而不是先解析再执行
//executeStep 执行步骤
func executeStep(ctx *http.Context, PrevId string, sts []common.ApixStep) error {
	defer func() {
		if x := recover(); x != nil {
			ctx.Logger().Error("无法执行服务节点,%v",x.(error))
		}
	}()
	subList := func(parentId string) []common.ApixStep {
		var result []common.ApixStep
		for _, st := range sts {
			if st.PrevId == parentId {
				result = append(result, st)
			}
		}
		return result
	}
	var stepMaps = listToMap(sts)
	subSts := subList(PrevId)
	if len(subSts) < 1 {
		return nil
	}
	for _, step := range subSts {
		if err := runStep(step, ctx, stepMaps); err != nil {
			return err
		}
		//执行子节点
		if err := executeStep(ctx, step.GraphId, sts); err != nil {
			return err
		}
	}
	return nil
}

func listToMap(steps []common.ApixStep) map[string]common.ApixStep {
	result := make(map[string]common.ApixStep)
	for _, step := range steps {
		result[step.GraphId] = step
	}
	return result
}

func runStep(step common.ApixStep, ctx *http.Context, stepMap map[string]common.ApixStep) error {
	log := ctx.Logger()
	log.Info("执行步骤节点:%s", step.GraphId)

	if step.Language == "javascript" {
		// 执行JS脚本内容
		if e := {{.Code}}.ExecuteJavaScript(ctx, step); e != nil {
			return e
		}
	} else if step.Predicate != nil {
		//执行判断逻辑
		if ok, e := {{.Code}}.ExecPredicates(ctx, step); e != nil {
			return e
		} else {
			nextStep := stepMap[step.ThenGraphId]
			if !ok {
				nextStep = stepMap[step.ElseGraphId]
			}
			if e = runStep(nextStep, ctx, stepMap); e != nil {
				return e
			}
		}
	} else {
		//执行普通的服务请求
		if e := {{.Code}}.ExecServer(ctx, step); e != nil {
			return e
		}
	}
	return nil
}