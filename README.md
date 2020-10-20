# dsflume-client

赋能业务线快速实现[《数据中台数据流接入规范V2》](https://gitlab.opg.cn/snippets/21)的Flume客户端。包含以下引人功能：

- 支持一键部署[Apache Flume NG社区版](http://flume.apache.org/releases/content/1.9.0/FlumeUserGuide.html)；
- 将*Flume*包装成*Systemd*服务，方便生产级系统管理；
- 提供大量参考配置；
- 实现一些易用的拦截器插件，方便业务线自行解析原始日志成《数据中台数据流接入规范V2》要求的数据流；

## 安装和配置

*dsflume-client*建议部署在至少1GiB空闲内存的*CentOS 7.x*上，依赖*JDK*版本需`>=1.8.0`，需使用`root`用户部署：
```bash
# 确认CentOS版本
cat /etc/redhat-release

# 确认JDK版本
java -version
```

下载安装包：
```bash
# 下载安装包
sudo su - && cd ~
git clone https://github.com/opgcn/dsflume-client.git
```

查看*控制器*帮助：
```bash
cd ~/dsflume-client
chmod a+x ctl.sh
./ctl.sh help
```

安装社区版官方*Apache Flume NG*：
```bash
./ctl.sh reinstall
```

创建默认配置，结合[Apache Flume官方文档](http://flume.apache.org/releases/content/1.9.0/FlumeUserGuide.html)修改：
```bash
cp conf/biz-example.conf conf/default.conf
cat conf/default.conf
```

安装*systemd*服务化支持：
```bash
./ctl.sh unit
```

启动*dsflume-client*服务：
```bash
./ctl.sh restart && ./ctl.sh status
```

跟踪*Apache Flume*应用日志：
```bash
tail -f logs/flume.log
```

通过本机*HTTP*协议*source*发送测试数据：
```bash
json='[
{"header":{}, "body":"V2|'$(hostname -I | cut -d' ' -f1)'|EXAMPLE_TYPE_1|EXAMPLE|'$(date +"%F %T")'|line-1"},
{"header":{}, "body":"V2|'$(hostname -I | cut -d' ' -f1)'|EXAMPLE_TYPE_2|EXAMPLE|'$(date +"%F %T")'|line-2"}
]'
echo "$json"
curl -i localhost:20003 -H 'Content-Type: application/json;charset=utf-8' -d "$json"
```

## 拦截器(interceptors)

### .1 正则提取字段生成V2数据(regex2v2)

此拦截器类似Flume官方的[查找-替换拦截器](https://flume.liyifeng.org/#id59)，基于[Java正则表达式](https://docs.oracle.com/javase/8/docs/api/java/util/regex/Pattern.html)提供对Event消息体简单的基于字符串的搜索，然后使用*Back references*对指定的*Capturing group*中的字段按顺序生成*V2*标准所需的CSV序列化，**业务线的开发和维护成本是编写标准Flume配置文件**。。

属性 | 默认值 | 解释
---- | ---- | ----
Type | - | 组件类型，这个是：`cn.opg.ds.flume.interceptors.regex2v2$Builder`
searchPattern | - | 包括*named-capturing group*的正则表达式
outputNames | - | 空格分隔，需要生成CSV的第6及以后字段名
streamVer | `V2` | 同《数据中台数据流接入规范V2》中描述（`stream_ver`）
streamIp | 当前机器的第一个私有IP | 同《数据中台数据流接入规范V2》中描述（`stream_ip`）
streamType | - | 同《数据中台数据流接入规范V2》中描述（`stream_type`）
streamBiz | - | 同《数据中台数据流接入规范V2》中描述（`stream_biz`）
streamDtFmt | '%Y-%m-%d %H:%M:%S' | 同《数据中台数据流接入规范V2》中描述（`stream_dt`）的格式

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
10.210.6.1 - - [03/Oct/2020:21:52:06 +0800] "GET /呵呵 HTTP/1.1" 200 4833 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36" "-"
10.210.6.1 - - [03/Oct/2020:21:52:15 +0800] "GET /呵呵?a=_&b=|&c=-; HTTP/1.1" 200 12345 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36" "-"
10.210.6.1 - - [03/Oct/2020:21:53:04 +0800] "GET /favicon.ico HTTP/1.1" 404 3650 "http://10.210.6.2/" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36" "-"
```

我们的Flume配置为：
```ini
a1.sources.r1.interceptors = i1
a1.sources.r1.interceptors.i1.type = cn.opg.ds.flume.interceptors.regex2v2$Builder
a1.sources.r1.interceptors.i1.searchPattern = ^(?<remote_addr>.*?)\ \-\ (?<remote_user>.*?)\ \[(?<time_local>.*?)\]\ \"(?<request>.*?)\"\ (?<status>.*?)\ (?<body_bytes_sent>.*?)\ \"(?<http_referer>.*?)\"\ \"(?<http_user_agent>.*?)\"\ \"(?<http_x_forwarded_for>.*?)\"$
a1.sources.r1.interceptors.i1.outputNames = remote_addr time_local request status body_bytes_sent
a1.sources.r1.interceptors.i1.streamType = ABC_SOME_DATA_TYPE_NAME
a1.sources.r1.interceptors.i1.streamBiz = ABC
```

将会生成数据流：
```text
V2|10.1.2.3|ABC_SOME_DATA_TYPE_NAME|ABC|2020-10-16 13:59:57|10.210.6.1|03/Oct/2020:21:52:06 +0800|GET /呵呵 HTTP/1.1|200|4833
V2|10.1.2.3|ABC_SOME_DATA_TYPE_NAME|ABC|2020-10-16 13:59:57|10.210.6.1|03/Oct/2020:21:52:06 +0800|"GET /呵呵?a=_&b=|&c=-; HTTP/1.1"|200|12345
V2|10.1.2.3|ABC_SOME_DATA_TYPE_NAME|ABC|2020-10-16 13:59:57|10.210.6.1|03/Oct/2020:21:53:04 +0800|GET /favicon.ico HTTP/1.1|404|3650
```


### .2 JSON行对象字段生成V2数据(ndjson2v2)

