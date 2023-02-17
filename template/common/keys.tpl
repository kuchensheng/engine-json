package common

import (
	"github.com/kuchensheng/bintools/http"
	"strings"
)

const (
	GlobalPrefix     = "/api/app/orc/"
	GlobalTestPrefix = "/api/app/test/orc/"
)

func GetPackage(ctx *http.Context) string {
	method := strings.ToLower(ctx.Request.Method)
	version := ctx.GetHeader("version")
	return GetKey(ctx.Request.URL.Path, method, version)
}

func GetKey(uri, method, version string) string {
	key := strings.Join([]string{uri, method, version}, "")
	key = strings.ReplaceAll(key, GlobalPrefix, "")
	key = strings.ReplaceAll(key, GlobalTestPrefix, "")
	key = strings.ReplaceAll(key, "/", "")
	key = strings.ReplaceAll(key, "-", "")
	return key
}
