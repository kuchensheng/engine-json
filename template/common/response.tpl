package common

import (
	"github.com/kuchensheng/bintools/http"
	"github.com/kuchensheng/bintools/trace/trace"
)

//BuildSuccessResponse 组装响应结果
func BuildSuccessResponse(ctx *http.Context, responses map[string]ApixResponse) (any, error) {
	logger := ctx.Logger()
	v, _ := ctx.Get(TRACER)
	tracer := v.(*trace.ServerTracer)
	pk := GetPackage(ctx)
	ls := LogStruct{PK: pk, TraceId: tracer.TracId,Logger: &logger}
	ls.Info("开始组装响应结果...")
	defer func() {
		if x := recover(); x != nil {
			ls.Error("结果组装失败:%s", x.(error).Error())
		} else {
			ls.Info("结果组装完毕")
		}
	}()
	for s, response := range responses {
		if s == "200" {
			schema := readSchema(ctx, response.Schema)
			ls.Info("组装结果:%s", schema)
			return schema, nil
		}
	}
	return nil, nil
}

func readSchema(ctx *http.Context, schema ApixSchema) any {
	schemaType := schema.Type
	switch schemaType {
	case OBJECT:
		result := make(map[string]any)
		for s, property := range schema.Properties {
			result[s] = readProperty(ctx, property)
		}
		return result
	case ARRAY:
		var result []any
		for _, child := range schema.Children {
			result = append(result, readProperty(ctx, child))
		}
		return result
	default:
		return GetContextValue(ctx, schema.Default)
	}
}

func readProperty(ctx *http.Context, property ApixProperty) any {
	propertyType := property.Type
	switch propertyType {
	case OBJECT:
		result := make(map[string]any)
		for s, apixProperty := range property.Properties {
			result[s] = readProperty(ctx, apixProperty)
		}
		return result
	case ARRAY:
		var result []any
		for _, child := range property.Children {
			result = append(result, readProperty(ctx, child))
		}
		return result
	default:
		return GetContextValue(ctx, property.Default)
	}
}