package common

const (
	KEY_TOKEN         = "$"
	KEY_REQ_CONNECTOR = "."
	KEY_REQ           = "$req"
	KEY_REQ_BODY      = KEY_REQ + KEY_REQ_CONNECTOR + "data"
	KEY_BODY          = "body"
	KEY_QUERY         = "query"
	KEY_HEADER        = "header"
	KEY_COOKIE        = "cookie"
	KEY_PATH          = "path"
	KEY_FORM          = "form"
	KEY_DATA          = "data"
	KEY_REQ_QUERY     = KEY_REQ + KEY_REQ_CONNECTOR + KEY_QUERY
	KEY_REQ_HEADER    = KEY_REQ + KEY_REQ_CONNECTOR + KEY_HEADER
	KEY_REQ_COOKIE    = KEY_REQ + KEY_REQ_CONNECTOR + KEY_COOKIE
	KEY_REQ_PATH      = KEY_REQ + KEY_REQ_CONNECTOR + KEY_PATH
	KEY_REQ_FORM      = KEY_REQ + KEY_REQ_CONNECTOR + KEY_FORM
)

const (
	RESULTMAP    = "resultMap"
	PARAMETERMAP = "parameterMap"

	TRACER = "tracer"
)

const (
	OBJECT = "object"
	ARRAY  = "array"
)

const (
	TENANT_ID = "isc-tenant-id"
	APPCODE   = "appCode"
	DEFAULT   = "default"
)

type Pair[T, R any] struct {
	First  T
	Second R
}

func (p *Pair[T, R]) GetFirst() T {
	return p.First
}

func (p *Pair[T, R]) GetSecond() R {
	return p.Second
}

func (p *Pair[T, R]) UpdateSecond(data R) {
	p.Second = data
}