package scanner

import (
	"encoding/json"
	"engine-json/domain"
	"github.com/kuchensheng/bintools/http"
	"github.com/kuchensheng/bintools/logger"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"text/template"
)

const (
	GlobalPrefix     = "/api/app/orc/"
	GlobalTestPrefix = "/api/app/test/orc/"
)

var TemplateBasePath = "/home/template/"
var ProductBasePath = "/home"
var (
	Default_Tenant  = "system"
	Default_AppCode = "default"
	suffix_tpl      = ".tpl"
	suffix_modtpl   = ".tpl"
	suffix_go       = ".go"
	dir_executor    = "executor"
	dir_common      = "common"
	dir_middleware  = "middleware"
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

type Data struct {
	Api         string
	Method      string
	Code        string
	Path        string
	Key         string
	ApixDataStr string
	goFilePath  string
}

func commonFn(root, suffix, dst string) error {
	return filepath.Walk(TemplateBasePath+root, func(path string, info fs.FileInfo, err error) error {
		if info.IsDir() {
			return nil
		}

		fpDir := filepath.Join(dst, root)
		if _, err = os.Stat(fpDir); err != nil && os.IsNotExist(err) {
			err = os.MkdirAll(fpDir, 666)
		}
		f := filepath.Join(fpDir, info.Name())
		if suffix == suffix_modtpl {
			if !strings.HasSuffix(path, suffix) {
				return nil
			}
			f = strings.ReplaceAll(f, suffix, "")
		} else {
			f = strings.ReplaceAll(f, suffix, suffix_go)
		}
		fw, _ := os.OpenFile(f, os.O_CREATE|os.O_RDWR|os.O_TRUNC, 666)
		defer fw.Close()
		t := template.Must(template.ParseFiles(path))
		return t.Execute(fw, "")
	})
}

type mainData struct {
	Path  string
	Datas []Data
}

func executor(dst, path1 string, apixData []Data) error {
	return filepath.Walk(TemplateBasePath+"executor", func(path string, info fs.FileInfo, err error) error {
		if info.IsDir() {
			return nil
		}

		if info.Name() != "main.tpl" {
			for _, data := range apixData {
				fd := filepath.Join(dst, data.Code)
				if _, err = os.Stat(fd); err != nil && os.IsNotExist(err) {
					err = os.MkdirAll(fd, 666)
				}
				f := filepath.Join(dst, data.Code, strings.ReplaceAll(info.Name(), suffix_tpl, suffix_go))
				if info.Name() == "executor.tpl" {
					//放到main包中
					f = filepath.Join(dst, strings.ReplaceAll(info.Name(), suffix_tpl, suffix_go))
				}
				if strings.HasSuffix(info.Name(), suffix_modtpl) {
					data.Path = path1
					f = filepath.Join(dst, strings.ReplaceAll(info.Name(), suffix_modtpl, ""))
				}
				if fw, e := os.OpenFile(f, os.O_CREATE|os.O_RDWR|os.O_TRUNC, 666); e != nil {
					return e
				} else {
					t := template.Must(template.ParseFiles(path))
					err = t.Execute(fw, data)
					fw.Close()
					if err != nil {
						logger.GlobalLogger.Error("无法转换,%v", err)
					}
					return err
				}
			}
		} else {
			md := mainData{
				Path:  path1,
				Datas: apixData,
			}
			if fw, e := os.OpenFile(filepath.Join(dst, "main.go"), os.O_CREATE|os.O_TRUNC|os.O_RDWR, 666); e != nil {
				panic(e)
			} else {
				t := template.Must(template.ParseFiles(path))
				err = t.Execute(fw, md)
				fw.Close()
				if err != nil {
					logger.GlobalLogger.Error("无法转换,%v", err)
				}
				return err
			}
		}
		return nil
	})
}

func methodConvert(method string) string {
	method = strings.ToLower(method)
	method = strings.ToUpper(method[:1]) + method[1:]
	return method

}

//ToGoFile 将data数据转换为go源码
func ToGoFile(ctx *http.Context, scan func() ([]domain.ApixData, error)) string {
	log := ctx.Logger()
	tenantId := ctx.GetHeader("isc-tenant-id")
	if tenantId == "" {
		tenantId = Default_Tenant
	}
	appCode, _ := ctx.GetQuery("appCode")
	if appCode == "" {
		appCode = Default_AppCode
	}
	if datas, err := scan(); err != nil {
		panic(err)
	} else {
		code := GetPackage(ctx)
		path := tenantId + "-" + appCode
		fpDir := filepath.Join(ProductBasePath, path)
		if _, err = os.Stat(fpDir); err != nil && os.IsNotExist(err) {
			err = os.MkdirAll(fpDir, 666)
		}
		err = commonFn(dir_common, suffix_tpl, fpDir)
		if err != nil {
			panic(err)
		}
		err = commonFn(dir_middleware, suffix_tpl, fpDir)
		if err != nil {
			panic(err)
		}
		var templateData []Data
		for _, dt := range datas {
			key := GetKey(dt.Rule.Api.Path, dt.Rule.Api.Method, "")
			fp := filepath.Join(fpDir, key+suffix_go)
			api := dt.Rule.Api
			byteDt, _ := json.Marshal(dt)
			data := Data{
				ApixDataStr: string(byteDt),
				Key:         key,
				Code:        code,
				Path:        path,
				Api:         api.Path,
				Method:      methodConvert(api.Method),
				goFilePath:  fp,
			}
			templateData = append(templateData, data)
		}
		if err = executor(fpDir, tenantId+"-"+appCode, templateData); err != nil {
			log.Error("模板执行异常,%v", err)
			panic(err)
		}
		return filepath.Join(fpDir, "main.go")
	}
}
