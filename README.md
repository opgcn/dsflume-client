# dsflume-plugins

方便业务线满足[《数据中台数据流接入规范V2》](https://gitlab.opg.cn/snippets/21)的**通用Flume插件集**。

业务线可以直接使用这些插件将自身流式日志转换成数据中台V2标准要求的CSV格式，**业务线的开发和维护成本是编写标准Flume配置文件**。

## 拦截器(interceptors)

### .1 正则提取字段生成V2数据(regex2v2)

此拦截器类似Flume官方的[查找-替换拦截器](https://flume.liyifeng.org/#id59)，基于[Java正则表达式](https://docs.oracle.com/javase/8/docs/api/java/util/regex/Pattern.html)提供对Event消息体简单的基于字符串的搜索，然后使用*Back references*对指定的*Capturing group*中的字段按顺序生成*V2*标准所需的CSV序列化。

属性 | 默认值 | 解释
---- | ---- | ----
Type | - | 组件类型，这个是：`cn.opg.ds.flume.interceptors.regex2v2$Builder`
searchPattern | - | 包括*named-capturing group*的正则表达式
outputNames | - | 空格分隔，需要生成CSV的第6及以后字段名
logip | - | 同《数据中台数据流接入规范V2》中描述
logtype | - | 同《数据中台数据流接入规范V2》中描述
logbiz | - | 同《数据中台数据流接入规范V2》中描述

假设`nginx.conf`中配置的日志格式`log_format`是:
```text
'$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" "$http_x_forwarded_for"'
```

那么对应的匹配正则应该是：
```text
^(?<remote_addr>.*?)\ \-\ (?<remote_user>.*?)\ \[(?<time_local>.*?)\]\ \"(?<request>.*?)\"\ (?<status>.*?)\ (?<body_bytes_sent>.*?)\ \"(?<http_referer>.*?)\"\ \"(?<http_user_agent>.*?)\"\ \"(?<http_x_forwarded_for>.*?)\"$
```

假设原始日志如下：
```text
10.210.6.1 - - [03/Oct/2020:21:52:06 +0800] "GET / HTTP/1.1" 200 4833 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36" "-"
10.210.6.1 - - [03/Oct/2020:21:53:04 +0800] "GET /favicon.ico HTTP/1.1" 404 3650 "http://10.210.6.2/" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36" "-"
```

我们的Flume配置为：
```ini
a1.sources.r1.interceptors = i1
a1.sources.r1.interceptors.i1.type = cn.opg.ds.flume.interceptors.regex2v2$Builder
a1.sources.r1.interceptors.i1.searchPattern = ^(?<remote_addr>.*?)\ \-\ (?<remote_user>.*?)\ \[(?<time_local>.*?)\]\ \"(?<request>.*?)\"\ (?<status>.*?)\ (?<body_bytes_sent>.*?)\ \"(?<http_referer>.*?)\"\ \"(?<http_user_agent>.*?)\"\ \"(?<http_x_forwarded_for>.*?)\"$
a1.sources.r1.interceptors.i1.outputNames = remote_addr time_local request status body_bytes_sent
a1.sources.r1.interceptors.i1.logip = ${FLUME_IP}
a1.sources.r1.interceptors.i1.logtype = ABC_SOME_DATA_TYPE_NAME
a1.sources.r1.interceptors.i1.logbiz = ABC
```

将会生成数据：
```text
V2|10.1.2.3|ABC_SOME_DATA_TYPE_NAME|ABC|2020-10-16 13:59:57|10.210.6.1|03/Oct/2020:21:52:06 +0800|GET / HTTP/1.1|200|4833
V2|10.1.2.3|ABC_SOME_DATA_TYPE_NAME|ABC|2020-10-16 13:59:57|10.210.6.1|03/Oct/2020:21:53:04 +0800|GET /favicon.ico HTTP/1.1|404|3650
```


### .2 JSON行对象字段生成V2数据(ndjson2v2)

