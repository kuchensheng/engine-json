package middleware

import (
	"bytes"
	"encoding/json"
	"github.com/kuchensheng/bintools/http"
	"github.com/kuchensheng/bintools/trace/trace"
	"io/ioutil"
	http2 "net/http"
)

func ServerTrace() func(ctx *http.Context) {
	return func(ctx *http.Context) {
		server := trace.NewServerTracer(ctx.Request)
		logger := ctx.Logger()
		logger.Info("接收到请求[%s],开启链路跟踪", ctx.Request.URL.Path)
		ctx.Set("tracer", server)
		ctx.Next()
		//执行完毕后，结束链路跟踪
		if ctx.Request.Response != nil && ctx.Request.Response.StatusCode != 200 {
			if msg, err := readRespBody(ctx.Request.Response); err != nil {
				//无法读取响应体内容
				server.EndServerTracer(trace.WARNING, "")
			} else {
				e := http.BusinessError{}
				if err = json.Unmarshal(msg, &e); err != nil {
					//不是BusinessErr
					server.EndTrace(trace.ERROR, string(msg))
				} else {
					server.EndServerTracer(trace.WARNING, string(msg))
				}
			}
		}
	}
}

func readRespBody(resp *http2.Response) (data []byte, err error) {
	if data, err = ioutil.ReadAll(resp.Body); err != nil {
		return nil, err
	} else {
		bufReader := bytes.NewBuffer(data)
		resp.Body = ioutil.NopCloser(bufReader)
		return data, nil
	}
}
