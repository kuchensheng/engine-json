package {{.Code}}

import (
	"bytes"
	"{{.Path}}/common"
	"errors"
	"fmt"
	"github.com/kuchensheng/bintools/http"
	"io/ioutil"
	"strings"
)

func deferHandler() error {
	if x := recover(); x != nil {
		return x.(error)
	}
	return nil
}

func CheckParameter(parameters []common.ApixParameter, parameterMap map[string]any) error {
	for _, parameter := range parameters {
		location := parameter.In
		required := parameter.Required
		if location != common.KEY_BODY {
			//直接判断
			if _, ok := parameterMap[getKey(location, parameter.Name)]; !ok && required {
				//判断不通过
				return newError(location, parameter.Name)
			}
		} else if e := checkBody(parameter.Schema, parameterMap); e != nil {
			return e
		}
	}
	return nil
}

func checkBody(schema common.ApixSchema, parameterMap map[string]any) error {
	if len(schema.Properties) == 0 {
		return nil
	}
	if v, ok := parameterMap[common.KEY_REQ_BODY]; !ok {
		return newError(common.KEY_BODY, "未获取到请求体内容")
	} else {
		var express []string
		switch schema.Type {
		case common.OBJECT:
			for _, property := range schema.Properties {
				if e := checkProperty(v, express, property); e != nil {
					return e
				}
			}
		case common.ARRAY:
			for _, child := range schema.Children {
				if e := checkProperty(v, express, child); e != nil {
					return e
				}
			}
		default:
			return nil
		}
		return nil
	}
}

func checkProperty(v any, express []string, property common.ApixProperty) error {
	required := property.Required
	name := property.Name
	express = append(express, name)
	switch property.Type {
	case common.OBJECT:
		if len(property.Properties) > 0 {
			for _, apixProperty := range property.Properties {
				if e := checkProperty(v, express, apixProperty); e != nil {
					return e
				}
			}
		}
	case common.ARRAY:
		if len(property.Children) > 0 {
			for _, child := range property.Children {
				if e := checkProperty(v, express, child); e != nil {
					return e
				}
			}
		}
	default:
		if _, ok := common.ReadByJsonPath(v.([]byte), express); !ok && required {
			//校验不通过
			return newError(common.KEY_BODY, name)
		}
	}
	return nil
}

func getKey(location, name string) (key string) {
	key = strings.Join([]string{common.KEY_REQ, location, name}, common.KEY_REQ_CONNECTOR)
	return
}

func SetParameterMap(ctx *http.Context) map[string]any {
	parameter := make(map[string]any)
	//获取请求体
	if data, err := readRequestBody(ctx); err == nil {
		parameter[common.KEY_REQ_BODY] = data
	}

	//获取请求头参数
	for s, values := range ctx.Request.Header {
		parameter[getKey(common.KEY_HEADER, strings.ToLower(s))] = values[0]
	}
	//获取query参数
	for s, values := range ctx.Request.URL.Query() {
		parameter[getKey(common.KEY_QUERY, s)] = values[0]
	}
	//获取表单参数
	for s, values := range ctx.Request.Form {
		parameter[getKey(common.KEY_FORM, s)] = values[0]
	}
	form := ctx.Request.MultipartForm
	if form != nil {
		for s, values := range form.Value {
			parameter[getKey(common.KEY_FORM, s)] = values[0]
		}
		for s, files := range form.File {
			parameter[getKey(common.KEY_FORM, s)] = files[0]
		}
	}

	//获取cookie参数
	for _, cookie := range ctx.Request.Cookies() {
		parameter[getKey(common.KEY_COOKIE, cookie.Name)] = cookie.Value
	}
	ctx.Set(common.PARAMETERMAP, parameter)
	return parameter
}

func readRequestBody(ctx *http.Context) ([]byte, error) {
	defer deferHandler()
	logger := ctx.Logger()
	if d, e := ctx.GetRawData(); e != nil {
		logger.Error("读取请求体内容异常，%v", e)
		return nil, e
	} else {
		ctx.Request.Body = ioutil.NopCloser(bytes.NewBuffer(d))
		return d, nil
	}

}

func newError(location, name string) error {
	return errors.New(fmt.Sprintf("%s参数缺失，%s=null", location, name))
}