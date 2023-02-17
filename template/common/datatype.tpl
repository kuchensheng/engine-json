package common

type ApixProperty struct {
	Name       string                  `json:"name"`       // 属性名称
	Default    string                  `json:"default"`    // 属性的默认值
	In         string                  `json:"in"`         // 属性的填充位置，resBody，只有在响应参数内才看这个值
	Type       string                  `json:"type"`       // 属性的数据类型，如果是 array，则需要读 subType
	SubType    string                  `json:"subtype"`    // 属性的子类型，如果是 object，就需要读取 Children 的内容
	Children   []ApixProperty          `json:"children"`   // 数组属性所对应的子属性，属性类型为 array 并且 subType 为 object 时，读取这里的子属性
	Properties map[string]ApixProperty `json:"properties"` // 属性类型为 object 时，其对应的子对象所具备的属性
	Required   bool                    `json:"required"`   // 是否必填
}

type ApixSchema struct {
	Type       string                  `json:"type"`       // Schema 的类型，object 或 array
	Properties map[string]ApixProperty `json:"properties"` // Schema 对象所具备的属性
	SubType    string                  `json:"subtype"`    // 属性的子类型，如果是 object，就需要读取 Children 的内容
	Children   []ApixProperty          `json:"children"`   // 数组属性所对应的子属性，属性类型为 array 并且 subType 为 object 时，读取这里的子属性
	Default    string                  `json:"default"`    // 属性的默认值, Type 不是 object 或 array 时，将取得表达式所描述的值并予以返回，Type 是 object 时，将获取表达式对应的对象或数组，并直接返回
}

type ApixParameter struct {
	Name     string     `json:"name"`     // 参数名称
	Type     string     `json:"type"`     // 参数数据类型
	In       string     `json:"in"`       // 参数的填充位置，query/body/path，为path的时候只能放在最后
	Schema   ApixSchema `json:"schema"`   // 参数的具体信息，当 type 为 object 或 array 时生效
	Default  string     `json:"default"`  // 参数的默认值，可以从全局 request 或上一个节点的 response 内获取数据
	Required bool       `json:"required"` // 是否必填
	// 二期新增
	SaveToLocal bool   `json:"saveToLocal"` // 是否保存上传的文件，仅当 type 为 file 时生效（如果为 false，则对文件参数进行传递，传给下一个 API）
	SavePath    string `json:"savePath"`    // 文件的保存路径，仅当 type 为 file 以及 saveToLocal 为 true 时生效
}

type ApixApi struct {
	Path           string          `json:"path"`           // Api 的请求路径，该路径在OS内全局唯一
	Protocol       string          `json:"protocol"`       // 请求协议，只能是http或https
	Method         string          `json:"method"`         // 请求方法，GET/POST/PUT/DELETE/OPTION
	Domain         string          `json:"domain"`         // Api 的域名（可选，不填的情况默认refer为当前服务）
	Parameters     []ApixParameter `json:"parameters"`     // Api 的请求参数
	RequireLogin   bool            `json:"requireLogin"`   // API 是否需要登录
	RequireKeyAuth bool            `json:"requireKeyAuth"` // API 是否需要授权服务的授权验证
}

type ApixSetCookie struct {
	Name    string `json:"name"`    // 要写入的 Cookie 名称
	Default string `json:"default"` //  要设置的值的来源
}

type ApixResponse struct {
	Schema    ApixSchema               `json:"schema"`    // Api 响应的数据结构定义
	SetCookie map[string]ApixSetCookie `json:"setCookie"` // Api 响应后，要写入的 cookie 内容
}

type ApixScript struct {
	Language string `json:"language"` // 脚本语言的类型，目前只能填 javascript/goscript
	Script   string `json:"script"`   // Api 替换为脚本代码后，所需要执行的脚本代码
}

type ApixSwitchPredicate struct {
	IsDefault   bool   `json:"isDefault"`   // 是否 switch 的默认节点，即全部的条件都不命中，所触发的流程
	Key         string `json:"key"`         // 如果父节点有 Key，则此处的 key 无效
	Value       string `json:"value"`       // 要判断的值
	Operator    string `json:"operator"`    // 判断操作符，当节点型有 Key 时，操作符永远为 ==(等于)，否则这里的操作符逻辑将等同于父节点的 Operator 逻辑
	ThenGraphId string `json:"thenGraphId"` // case 条件命中时执行的节点
}

type ApiStepPredicate struct {
	Enabled  bool   `json:"enabled"`  // 是否启用条件判断(不填的情况，自动填为false)
	Type     string `json:"type"`     // 条件的类型，只能是 if/switch，在循环内，break或continue条件只能是if
	Key      string `json:"key"`      // 要判断的名
	Value    string `json:"value"`    // 要判断的值
	Operator string `json:"operator"` // 判断操作符，可以是以下的符号：
	// ==(等于),!=(不等于),>(大于),>=(大于等于),<(小于),<=(小于等于),%<num>(取模等于),!%<num>(取模不等于)
	// in(在集合内),!in(不在集合内),inc(包含),!inc(不包含),nil(空),!nil(非空),true(真),false(假)
	IsRegex bool                  `json:"isRegex"` // 当此选项为true时，value为正则表达式，将判断key的值是否与value所指的正则表达式匹配，此时Operator会失效
	Cases   []ApixSwitchPredicate `json:"cases"`   // 针对 type 是 switch 的情况才有效，指出switch所属的case分支，key有值的情况下，对key进行switch，key没值的情况，转换为when语句，这里的switch没有落入机制
}

// ApixDatabaseConfig 数据库配置
// 三期新增
type ApixDatabaseConfig struct {
	Type           string `json:"type"`           // 数据库类型，可选值为 mysql(含mariadb)/oracle/mssql/dameng (SQLite因编译问题已被去除)
	Name           string `json:"name"`           // 数据连接的名称，用以标记一个连接池内的连接
	Host           string `json:"host"`           // 数据库的主机IP或域名
	Port           int    `json:"port"`           // 数据库的访问端口
	DatabaseName   string `json:"databaseName"`   // 数据库的名称（可以是Schema等，具体参看JDBC URL内的连接参数），达梦不需填此项
	User           string `json:"user"`           // 用户名
	Password       string `json:"password"`       // 密码
	MaxOpenCount   int    `json:"maxOpenCount"`   // 最大开放连接数
	MaxIdleCount   int    `json:"maxIdleCount"`   // 最大空闲连接数
	MaxIdleTimeout int    `json:"maxIdleTimeout"` // 最大空闲超时
}

type ApixMQTTConfig struct {
	Name     string `json:"name"`     // MQTT 客户端的名称，将跟据名称来查找客户端
	Host     string `json:"host"`     // 服务域名或IP
	Port     int    `json:"port"`     // 服务的监听端口
	ClientID string `json:"clientID"` // 客户端ID(可选)
	User     string `json:"user"`     // 访问所需的用户名(可选)
	Password string `json:"password"` // 访问所需的密码(可选)
	Topic    string `json:"topic"`    // 订阅的 TOPIC
	Qos      int    `json:"qos"`      // 订阅策略，仅在 Step 节点的 isSubscription 为 true 时生效
}

// ApixRedisConfig Redis 配置
// 四期新增
type ApixRedisConfig struct {
	Name     string `json:"name"`     // redis 客户端的名称，将跟据名称来查找客户端
	Host     string `json:"host"`     // 服务域名或IP
	Port     int    `json:"port"`     // 服务的监听端口
	Password string `json:"password"` // Redis 密码
	DBIndex  int    `json:"dbindex"`  // 数据库ID
}

type ApixInfluxDBConfig struct {
	Name     string `json:"name"`     // influxdb 客户端的名称，将跟据名称来查找客户端
	Protocol string `json:"protocol"` // influxdb 访问协议，可选 http 和 https
	Host     string `json:"host"`     // 服务域名或IP
	Port     int    `json:"port"`     // 服务的监听端口
	Version  string `json:"version"`  // influxdb 的版本，默认 2.0，可选 1.8
	Token    string `json:"token"`    // 访问所需的Token，有 Token 时，以 Token 为优先使用
	User     string `json:"user"`     // 访问所需的用户名，仅当 InfluxDB 版本为 1.8 并且没有 Token 时适用
	Password string `json:"password"` // 访问所需的密码，仅当 InfluxDB 版本为 1.8 并且没有 Token 时适用
	Org      string `json:"org"`      // influxdb对应的组织
	Bucket   string `json:"bucket"`   // influxdb 的 bucket，仅写入时会用到这个字段
}

type ApixStep struct {
	PrevId        string           `json:"prevIds"`       // 上一个节点的 GraphId，可以有多个节点，没有上一个节点的情况，此项为空数组
	GraphId       string             `json:"graphId"`       // 节点的Id，在一个ApixData内，此Id唯一
	Code          string             `json:"code"`          // StepId （编译器不处理，但是保留）
	Domain        string             `json:"domain"`        // 请求 Api 时的域名和端口，如 isc-permission-service:32100
	Protocol      string             `json:"protocol"`      // 请求协议，只能是http或https
	Method        string             `json:"method"`        // 请求方法，GET/POST/PUT/DELETE/OPTION
	Path          string             `json:"path"`          // 请求路径
	ContentType   string             `json:"contentType"`   // 当前节点的ContentType，如果不填就沿用主 API 的
	Parameters    []ApixParameter    `json:"parameters"`    // 请求的参数
	Local         bool               `json:"local"`         // 是否本地代码，如果要使用Script来代替这个节点的请求，则置为true
	Language      string             `json:"language"`      // 脚本语言的类型，目前只能填 javascript/goscript
	Script        ApixScript         `json:"script"`        // 脚本代码
	Predicate     []ApiStepPredicate `json:"predicate"`     // 条件判断，如果是switch，则只能有一个节点
	PredicateType int                `json:"predicateType"` // 条件判断模式，0:所有条件都为真，1:任意条件为真，只有一个条件时不生效
	ThenGraphId   string             `json:"thenGraphId"`   // predicate 条件命中时执行的节点
	ElseGraphId   string             `json:"elseGraphId"`   // predicate 条件不命中时执行的节点

	// 三期新增
	IsDatabase     bool               `json:"isDatabase"`     // 是否数据节点
	TransBegin     bool               `json:"transBegin"`     // 是否事务开始节点，仅当 isDatabase 为 true 时生效，生效时当前节点内仅 databaseConfig 同时生效
	TransEnd       bool               `json:"transEnd"`       // 是否事务结束节点，仅当 isDatabase 为 true 时生效，生效时当前节点内仅 databaseConfig 同时生效
	IsGlobalSource bool               `json:"isGlobalSource"` // 是否全局数据连接(受连接池管理)，若不是全局的连接，则请求时单独开启连接，并在请求结束时关闭（承压情况请尽量开启全局）
	DatabaseConfig ApixDatabaseConfig `json:"databaseConfig"` // 数据库连接配置，仅当 isDatabase 为 true 时生效
	SQL            string             `json:"SQL"`            // 要执行的 SQL 语句，一个节点只能执行一句
	MaxQueryCount  int                `json:"maxQueryCount"`  // 执行查询时每次最多返回的数据量，填0(或不填)表示无限

	// 三期新增，循环节点
	IsLoop                 bool             `json:"isLoop"`                 // 是否循环标识节点，这种循环节点仅用于固定次数循环(对于加液加物料场景，请使用条件判断)
	LoopBegin              bool             `json:"loopBegin"`              // 是否循环开始，仅当 isLoop 为 true 时生效，循环开始节点不会识别 predicate 的内容
	LoopEnd                bool             `json:"loopEnd"`                // 是否循环结束，仅当 isLoop 为 true 时生效，需要注意，循环结束节点的 prevId，必须是 loopBegin 节点的 graphId，原则上循环结束时，没有需要做的事情，可以根据 predicate 的内容进行条件跳转
	LoopVariable           string           `json:"loopVariable"`           // 用于循环的变量，必须是数组，在循环时，将按照数组内容，对每一个元素进行执行
	IsSubLoop              bool             `json:"isSubLoop"`              // 是否循环内的循环
	LoopBreakCondBefore    ApiStepPredicate `json:"loopBreakCondBefore"`    // 在循环体最前方的 break 条件控制，在 isLoop 和 loopBegin 都为 true 时生效
	LoopBreakCondAfter     ApiStepPredicate `json:"loopBreakCondAfter"`     // 在循环体最后方的 break 条件控制，在 isLoop 和 loopBegin 都为 true 时生效
	LoopContinueCondBefore ApiStepPredicate `json:"loopContinueCondBefore"` // 在循环体最前方的 continue 条件控制，在 isLoop 和 loopBegin 都为 true 时生效
	LoopContinueCondAfter  ApiStepPredicate `json:"loopContinueCondAfter"`  // 在循环体最后方的 continue 条件控制，在 isLoop 和 loopBegin 都为 true 时生效

	// 三期新增，打印节点
	IsPrint       bool     `json:"isPrint"`       // 是否打印节点
	PrintVariable []string `json:"printVariable"` // 要打印的内容
	PrintFormat   string   `json:"printFormat"`   // 输出格式字符串，如 "loop1: {0}, loop2: {1}"，以 {数字} 作为占位符
	LogFormat     bool     `json:"logFormat"`     // 是否按日志格式输出

	// 三期新增，MQTT 节点
	IsMQTT         bool           `json:"isMQTT"`         // 是否 MQTT 节点，需要注意，MQTT节点没有返回值，若要跟踪中间状态请使用打印节点
	MQTTConfig     ApixMQTTConfig `json:"MQTTConfig"`     // MQTT的配置
	IsSubscription bool           `json:"isSubscription"` // 是否订阅者节点，如果是的话，这个节点只能是独立的起点
	IsPublish      bool           `json:"isPublish"`      // 是否推送消息节点，如果是的话，这个节点可以被编排在其他节点逻辑中
	QosPublish     int            `json:"qosPublish"`     // 推送策略，仅在 isPush 为 true 时生效
	PublishMessage string         `json:"publishMessage"` // 要推送的信息，可以是表达式（表达式是对象的情况，转换为json发送）

	// 四期新增，Redis 节点
	IsRedis       bool            `json:"isRedis"`       // 是否 redis 节点
	RedisConfig   ApixRedisConfig `json:"redisConfig"`   // redis 的配置
	IsGlobalRedis bool            `json:"isGlobalRedis"` // 是否全局的 redis 连接
	IsRedisRead   bool            `json:"IsRedisRead"`   // 是否用于读取数据
	IsRedisWrite  bool            `json:"isRedisWrite"`  // 是否用于写入数据
	RedisDataType string          `json:"redisDataType"` // redis 数据类型，目前仅支持 string 和 hash
	RedisKey      string          `json:"redisKey"`      // 要操作的 key
	RedisField    string          `json:"redisField"`    // 要操作的 field，仅在 redisDataType 为 hash 时适用
	RedisValue    string          `json:"redisValue"`    // 需要写入的值，仅当 isRedisWrite 为 true 时适用

	// 四期新增，InfluxDB 节点
	IsInfluxDB       bool               `json:"isInfluxDB"`       // 是否 influxdb 节点
	InfluxDBConfig   ApixInfluxDBConfig `json:"influxDBConfig"`   // influxdb 的配置
	IsGlobalInfluxDB bool               `json:"isGlobalInfluxDB"` // 是否全局的 influxdb 连接
	IsInfluxdbRead   bool               `json:"isInfluxdbRead"`   // 是否用于读取
	IsInfluxdbWrite  bool               `json:"isInfluxdbWrite"`  // 是否用于写入
	InfluxQueryLine  string             `json:"influxQueryLine"`  // influxdb 的查询语句
	InfluxWriteLine  string             `json:"influxWriteLine"`  // influxdb 的数据写入语句
}

type ApixRule struct {
	Api      ApixApi                 `json:"api"`       // 最终可调用的 restful api 的定义
	Response map[string]ApixResponse `json:"responses"` // 最终可调用的 restful api 的返回数据
	Steps    []ApixStep              `json:"steps"`     // api 编排后的的执行步骤
}

// ApixData API的完整定义
type ApixData struct {
	Rule ApixRule `json:"rule"`
}
