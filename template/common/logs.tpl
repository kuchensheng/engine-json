package common

import (
	"fmt"
	"github.com/gorilla/websocket"
	"github.com/kuchensheng/bintools/http"
	"github.com/kuchensheng/bintools/logger"
	"github.com/patrickmn/go-cache"
	http2 "net/http"
	"reflect"
	"runtime"
	"strings"
	"time"
)

var channelMap = cache.New(time.Minute, 10*time.Second)
var END = "EOF"
var format = "2006-01-02 15:04:05.999"

type LogStruct struct {
	PK      string
	TraceId string
	Logger  *logger.Logger
}

func (p LogStruct) Info(msg string, args ...any) {
	//日志格式:$DATE $TIME [funcName] [traceId] msg
	push(p.PK, "info", msg, p, buildMsg, args)
	p.Logger.Info(msg, args...)
}

func (p LogStruct) Warn(msg string, args ...any) {
	//日志格式:$DATE $TIME [funcName] [traceId]
	push(p.PK, "warn", msg, p, buildMsg, args)
	p.Logger.Warn(msg, args...)
}

func (p LogStruct) Error(msg string, args ...any) {
	//日志格式:$DATE $TIME [funcName] [traceId] msg
	push(p.PK, "error", msg, p, buildMsg, args)
	p.Logger.Error(msg, args...)
}

func buildMsg(level, msg string, p LogStruct, args ...any) string {
	_, f, line, _ := runtime.Caller(3)
	if !(len(args) == 1 && reflect.ValueOf(args[0].([]any)[0]).Len() == 0) {
		msg = fmt.Sprintf(msg, args[0].([]any)[0].([]any)...)
	}
	return fmt.Sprintf("%s [%s] %s:%d [%s] %s", now(), strings.ToUpper(level), f, line, p.TraceId, msg)
}

func now() string {
	return time.Now().Format(format)
}
func StartListener(pk string) {
	ch := make(chan string, 128)
	ch <- "连接成功"
	channelMap.SetDefault(pk, ch)
}
func StopListener(pk string) {
	channelMap.Delete(pk)
}
func push(pk string, level, msg string, p LogStruct, data func(level, msg string, p LogStruct, args ...any) string, args ...any) {
	if c, ok := channelMap.Get(pk); ok {
		c.(chan string) <- data(level, msg, p, args)
	} else {
		//未初始化，不执行push操作
	}
}

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http2.Request) bool {
		return true
	},
}

//LogServer 建立websocket，用于向客户端持续传输业务日志，直到执行完毕或者超时
//注意：参数api = 请求路径，method = 请求方法
func LogServer(context *http.Context) {
	logger := context.Logger()
	if upgrade, err := upgrader.Upgrade(context.Writer, context.Request, nil); err != nil {
		logger.Warn("无法建立websocket连接:%v", err)
		context.JSON(http2.StatusBadRequest, http.NewErrorWithMsg(1080400, "无法建立websocket连接", err))
		context.Abort()
		return
	} else {
		defer upgrade.Close()
		if api, ok := context.GetQuery("api"); !ok {
			upgrade.WriteMessage(websocket.TextMessage, []byte("api参数不能为空"))
			return
		} else if method, ok := context.GetQuery("method"); !ok {
			upgrade.WriteMessage(websocket.TextMessage, []byte("method参数不能为空"))
			return
		} else {
			version, _ := context.GetQuery("version")
			pk := GetKey(api, method, version)
			StartListener(pk)
			//持续监听
			Pull(pk, upgrade, &logger)
			//移除缓存
			StopListener(pk)
		}
	}
}
func Pull(pk string, conn *websocket.Conn, logger *logger.Logger) string {
	defer func() {
		conn.Close()
	}()
	if c, ok := channelMap.Get(pk); ok {
		for {
			select {
			case value := <-c.(chan string):
				conn.WriteMessage(websocket.TextMessage, []byte(value))
			case <-time.After(5 * time.Second):
				logger.Warn("5s内未取到值,结束监听")
				conn.WriteMessage(websocket.TextMessage, []byte(END))
				return END
			}
		}

	}
	return END
}
