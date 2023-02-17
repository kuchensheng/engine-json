package {{.Code}}

import (
	"bytes"
	"encoding/json"
	"{{.Path}}/common"
	"errors"
	"fmt"
	"github.com/kuchensheng/bintools/http"
	"github.com/kuchensheng/bintools/trace/trace"
	"io/ioutil"
	http2 "net/http"
	"net/url"
	"strconv"
	"strings"
)


//执行服务节点
func ExecServer(ctx *http.Context, step common.ApixStep) error {
	log := ctx.Logger()
	if step.Path == "" {
		log.Warn("当前服务节点[%s]的Path为空,将不做任何执行", step.GraphId)
		return nil
	}
	var _tracer *trace.ServerTracer
	if t, ok := ctx.Get(common.TRACER); ok {
		_tracer = t.(*trace.ServerTracer)
	}
	//获取包名
	pk := common.GetPackage(ctx)
	logger := common.LogStruct{PK: pk, TraceId: _tracer.TracId, Logger: &log}
	logger.Info("开始执行服务节点[%s],Path = %s", step.GraphId, step.Path)
	if request, err := buildRequest(ctx, step); err != nil {
		logger.Error("无法构建请求[%s%s]:%s", step.Domain, step.Path, err.Error())
		return common.NewException(step.GraphId, "", err.Error())
	} else if request != nil {
		logger.Info("发起请求:%s,method :%s", request.URL.String(), request.Method)
		if result, err1 := _tracer.Call(request); err1 != nil {
			logger.Error("服务节点执行失败:%s", err1.Error())
			return common.NewException(step.GraphId, "", err1.Error())
		} else {
			logger.Info("服务节点执行成功:%s", result)
			common.SetResultValue(ctx, fmt.Sprintf("%s%s%s", common.KEY_TOKEN, step.GraphId, ".$resp.data"), result)
			return nil
		}
	}
	return nil
}

func buildRequest(ctx *http.Context, step common.ApixStep) (*http2.Request, error) {
	scheme := "http://" //
	if step.Protocol == "https" {
		scheme = "https://"
	}
	if step.Path == "" || step.Domain == "" || step.Method == "" {
		return nil, nil
	}
	domain := strings.ReplaceAll(step.Domain, "/", "")
	path := step.Path
	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}

	strUrl := fmt.Sprintf("%s%s%s", scheme, domain, path)
	url, _ := url.Parse(strUrl)
	request := &http2.Request{
		Method: step.Method,
		URL:    url,
		Header: make(map[string][]string),
		Form:   make(map[string][]string),
	}
	request.Header = ctx.Request.Header
	request.Header.Del("Accept-Encoding")
	for _, parameter := range step.Parameters {
		location := parameter.In
		switch location {
		case common.KEY_BODY:
			schema := parameter.Schema
			schemaType := schema.Type
			if schemaType == common.OBJECT && schema.Properties != nil && len(schema.Properties) > 0 {
				body := make(map[string]any)
				for _, property := range schema.Properties {
					if v := common.GetBodyParameterValue(ctx, property.Default); v != nil {
						body[property.Name] = v
					}
				}
				data, _ := json.Marshal(body)
				request.Body = ioutil.NopCloser(bytes.NewBuffer(data))
				request.Header.Set("Content-Length", strconv.Itoa(len(data)))
			}

		case common.KEY_QUERY:
			if v := common.GetNotBodyParameterValue(ctx, parameter.Default); v != nil {
				url.Query().Add(parameter.Name, v.(string))
			}
		case common.KEY_HEADER:
			if v := common.GetNotBodyParameterValue(ctx, parameter.Default); v != nil {
				request.Header.Set(parameter.Name, v.(string))
			}
		case common.KEY_COOKIE:
			if v := common.GetNotBodyParameterValue(ctx, parameter.Default); v != nil {
				request.AddCookie(&http2.Cookie{
					Name:  parameter.Name,
					Value: v.(string),
				})
			}
		case common.KEY_FORM:
			if v := common.GetNotBodyParameterValue(ctx, parameter.Default); v != nil {
				request.Form.Add(parameter.Name, v.(string))
			}
		default:
			return nil, errors.New("不支持的参数形式")
		}
	}
	return request, nil
}