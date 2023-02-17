package main

import (
	"{{.Path}}/middleware"
	"flag"
	"github.com/kuchensheng/bintools/http"
)

func main() {
	port := flag.Int("port", 38200, "服务启动端口，默认38200")
	flag.Parse()
	e := http.Default()
	e.Use(middleware.ServerTrace(),middleware.Cors())
    {{range .Datas}}
	e.{{.Method}}("{{.Api}}", Executor{{.Key}})
	{{end}}

	e.Run(*port)
}
