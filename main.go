package main

import (
	"engine-json/domain"
	"engine-json/middleware"
	"engine-json/scanner"
	"flag"
	"fmt"
	"github.com/kuchensheng/bintools/http"
	"os"
	"path"
)

func main() {
	wd, _ := os.Getwd()
	port := flag.Int("port", 38234, "启动端口，默认38234")
	templateBasePath := flag.String("tb", "", "模型文件地址")
	productBasePath := flag.String("pb", "", "go源码存放地址")
	enablePermission := flag.Bool("ep", false, "是否开启登录验证,默认false")
	flag.Parse()
	permissionUrl := flag.String("caUrl", "http://10.30.30.95:32100/api/permission/auth/status", "登录验证地址")
	middleware.UpdatePermissionUrl(*permissionUrl)
	if templateBasePath != nil && *templateBasePath != "" {
		scanner.TemplateBasePath = *templateBasePath
	}
	if productBasePath != nil && *productBasePath != "" {
		scanner.ProductBasePath = *productBasePath
	}
	e := http.Default()
	e.Use(middleware.ServerTrace(), middleware.Cors())
	if *enablePermission == true {
		e.Use(middleware.LoginFilter())
	}
	//将dsl编译成go源码,上传单个dsl文件
	e.Post(scanner.GlobalPrefix+"dsl", func(ctx *http.Context) {
		if file, err := ctx.FormFile("file"); err != nil {
			ctx.JSON(400, http.BusinessError{1080500, err.Error(), e})
			return
		} else {
			var tenantId string
			if t, ok := ctx.Get("isc-tenant-id"); ok {
				tenantId = fmt.Sprintf("%v", t)
			}
			savePath := path.Join(wd, "/home/example", tenantId, file.Filename)
			result := scanner.ToGoFile(ctx, func() ([]domain.ApixData, error) {
				return scanner.ScanDslFile(ctx, file, savePath)
			})
			ctx.JSONoK(result)
			return
		}
	})
	//将dsl翻译成go源码，给定dsl路径
	e.Post(scanner.GlobalPrefix+"dsl/path", func(ctx *http.Context) {
		file, ok := ctx.GetQuery("path")
		if !ok {
			ctx.JSON(400, "path是必填参数")
		}
		result := scanner.ToGoFile(ctx, func() ([]domain.ApixData, error) {
			return scanner.ScanDsl(ctx, file)
		})
		ctx.JSONoK(result)
		return
	})
	//将多个dsl编译成二进制文件
	e.Post(scanner.GlobalPrefix+"build", func(ctx *http.Context) {
		ctx.Logger().Info("我是第三个")
	})
	e.Run(*port)
}
