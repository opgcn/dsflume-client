# dsflume-plugins
方便业务线满足数据中台数据流接入规范V2的Flume插件集

## 拦截器(interceptors)

### .1 正则提取字段生成V2数据(regex2v2)

此拦截器类似Flume官方的[查找-替换拦截器](https://flume.liyifeng.org/#id59)，基于[Java正则表达式](https://docs.oracle.com/javase/8/docs/api/java/util/regex/Pattern.html)提供对Event消息体简单的基于字符串的搜索和替换功能。 还可以进行*Back references* / *Named capturing group*。

### .2 JSON行对象字段生成V2数据(ndjson2v2)

