# dsflume-client

赋能业务线快速实现[《数据中台数据流接入规范V2》](https://gitlab.opg.cn/snippets/21)的Flume客户端。包含以下引人功能：

- 支持一键部署[Apache Flume NG社区版](http://flume.apache.org/releases/content/1.9.0/FlumeUserGuide.html)；
- 将*Flume*包装成*Systemd*服务，方便生产级系统管理；
- 提供通用的业务侧拦截器插件，方便业务线自行解析原始日志成为《数据中台数据流接入规范V2》要求格式的数据流；

建议业务侧技术工程师先完整阅读[Flume官方文档](https://flume.liyifeng.org/)后，再进行使用。

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

**控制器**是*dsflume-client*的操作中心（类似`kubectl`、`systemctl`等），查看*控制器*帮助：
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

## 拦截器插件(interceptors)

*Apache Flume NG社区版*的架构设计中，对流式数据的修改需要通过[拦截器](https://flume.liyifeng.org/#id54)进行。官方*拦截器*功能有限时，可以使用*Java*自行开发*拦截器*，数据中台提供以下通用拦截器，方便业务线使用。

### .1 正则提取字段生成V2格式数据插件(regex2v2)

对于业务线的原始日志流中每行记录，**如果可以通过简单的正则匹配逐个字段提取出来**，建议使用此拦截器插件生成*V2*标准要求的投递数据，**业务线的开发和维护成本是编写标准Flume配置文件**。数据流如下：

```text
           Conf ---\
                    |
    Source ---> Interceptor ---> Channel
```

此拦截器是Flume官方的[查找-替换拦截器](https://flume.liyifeng.org/#id59)的优化版，基于[Java正则表达式](https://docs.oracle.com/javase/8/docs/api/java/util/regex/Pattern.html)提供对Event消息体简单的基于字符串的搜索，然后使用*Back references*对指定的*Capturing group*中的字段按顺序生成*V2*标准所需的CSV序列化。其配置属性如下：

属性 | 默认值 | 解释
---- | ---- | ----
type | - | 组件类型，这个是：`cn.opg.ds.flume.interceptors.regex2v2$Builder`
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

### .2 流处理器生成V2格式数据插件(proc)

如果业务线的原始日志流中每行记录十分复杂，需要自行开发一个**流处理器**，以`sdtin`输入逐行原始数据，并以`stdout`输出*V2*格式数据流。数据流如下：

```text
           Conf ---\
                    |
    Source ---> Interceptor ---> Channel
               /           \
              /             \
          stdin -> proc -> stdout
```

此拦截器是Flume官方的[Exec Source](https://flume.liyifeng.org/#exec-source)的拦截器版本。其配置属性如下：

属性 | 默认值 | 解释
---- | ---- | ----
Type | - | 组件类型，这个是：`cn.opg.ds.flume.interceptors.proc$Builder`
channels | - | 与Source绑定的channel，多个用空格分开
command | - | 所使用的系统命令，例如`python3 procs/my-proc.py --arg1 --arg2`
restart | true | 如果执行命令线程挂掉，是否重启
restartThrottle | 1000 | 尝试重新启动之前等待的时间（毫秒）




