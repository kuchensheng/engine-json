package middleware

import (
	"github.com/kuchensheng/bintools/http"
	http2 "net/http"
)

func Cors() func(ctx *http.Context) {
	return func(context *http.Context) {
		method := context.Request.Method
		context.SetHeader("Access-Control-Allow-Origin", "*")
		context.SetHeader("Access-Control-Allow-Headers", "Content-Type,AccessToken,X-CSRF-Token, Authorization, Token")
		context.SetHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
		context.SetHeader("Access-Control-Expose-Headers", "Content-Length, Access-Control-Allow-Origin, Access-Control-Allow-Headers, Content-Type")
		context.SetHeader("Access-Control-Allow-Credentials", "true")
		if method == "OPTIONS" {
			context.Status(http2.StatusNoContent)
			context.Abort()
		}
		context.Next()
	}
}
