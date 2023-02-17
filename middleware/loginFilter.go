package middleware

import (
	"encoding/json"
	"github.com/kuchensheng/bintools/http"
	"github.com/kuchensheng/bintools/logger"
	"io/ioutil"
	http2 "net/http"
	"time"
)

const KeyTenant = "isc-tenant-id"
const KeyToken = "token"
const (
	TokenNull       = "token为空"
	TokenInvaluable = "无效的token"
)

var permissionUrl = "http://isc-permission-service:32100/api/permission/auth/status"

type Status struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    struct {
		UserId     string   `json:"userId"`
		LoginName  string   `json:"loginName"`
		RoleId     []string `json:"roleId"`
		NickName   string   `json:"nickname"`
		TenantId   string   `json:"tenantId"`
		UserType   string   `json:"userType"`
		SuperAdmin bool     `json:"superAdmin"`
		Token      string   `json:"token"`
	} `json:"data"`
}

func LoginFilter() func(ctx *http.Context) {
	return func(ctx *http.Context) {
		ctx.Logger().Info("登录校验,uri=%s", ctx.Request.URL.Path)
		token := ctx.GetHeader(KeyToken)
		fn := func(c *http.Context, msg string) {
			c.JSON(401, http.BusinessError{
				Code:    20401,
				Message: msg,
			})
			c.Abort()
			return
		}
		if token == "" {
			fn(ctx, TokenNull)
		}
		s := &Status{}
		//检查token有效性
		if !tokenChen(token, s) {
			fn(ctx, TokenInvaluable)
		}
		ctx.SetHeader(KeyTenant, s.Data.TenantId)
		ctx.Next()
	}
}

func tokenChen(token string, status *Status) bool {
	req, _ := http2.NewRequest(http2.MethodGet, permissionUrl, nil)
	client := http2.Client{
		Timeout: 1 * time.Second,
	}
	req.Header = make(http2.Header)
	req.Header.Set(KeyToken, token)
	if resp, err := client.Do(req); err == nil {
		if resp.StatusCode != http2.StatusOK {
			logger.GlobalLogger.Warn("无法读取status信息,响应码:%d", resp.StatusCode)
			return false
		}
		data, _ := ioutil.ReadAll(resp.Body)
		if e := json.Unmarshal(data, status); e == nil {
			return status.Data.Token == token
		} else {
			logger.GlobalLogger.Warn("无法读取status信息,%v", e)
			return false
		}

	} else {
		logger.GlobalLogger.Warn("无法请求status信息,%v", err)
		return false
	}
}

func UpdatePermissionUrl(url string) {
	permissionUrl = url
}
