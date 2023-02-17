package scanner

import (
	"encoding/json"
	"engine-json/domain"
	"github.com/kuchensheng/bintools/http"
	"github.com/kuchensheng/bintools/logger"
	"io"
	"io/fs"
	"io/ioutil"
	"mime/multipart"
	"os"
	"path/filepath"
)

//ScanDsl 扫描dsl文件,并读取dsl文件内容
func ScanDsl(ctx *http.Context, dir string) (apixData []domain.ApixData, err error) {
	var datas []domain.ApixData
	if f, e := os.Stat(dir); e != nil {
		ctx.Logger().Warn("目录或文件不存在")
		return nil, e
	} else if f.IsDir() {
		filepath.Walk(dir, func(path string, info fs.FileInfo, err error) error {
			if info.IsDir() {
				return nil
			}
			ad := domain.ApixData{}
			if data, e := ioutil.ReadFile(path); e != nil {
				ctx.Logger().Warn("无法读取dsl文件,%v", err)
				return err
			} else if err = json.Unmarshal(data, &ad); err != nil {
				logger.GlobalLogger.Warn("无法翻译dsl文件,%v", err)
				return err
			} else {
				datas = append(datas, ad)
			}
			return nil
		})
	} else {
		bytes := make([]byte, f.Size())
		f1, _ := os.Open(dir)
		if _, err = f1.Read(bytes); err != nil {
			return nil, err
		} else {
			ad := domain.ApixData{}
			if err = json.Unmarshal(bytes, &ad); err != nil {
				return
			}
			datas = append(datas, ad)
		}
	}

	return datas, nil
}

func ScanDslFile(ctx *http.Context, file *multipart.FileHeader, dst string) (apixData []domain.ApixData, err error) {
	ctx.Logger().Info("读取文件内容:%s", file.Filename)
	src, err := file.Open()
	if err != nil {
		return nil, err
	}
	defer src.Close()
	data, err := io.ReadAll(src)
	ad := domain.ApixData{}
	if err = json.Unmarshal(data, &ad); err != nil {
		return
	}
	return append(apixData, ad), nil
}
