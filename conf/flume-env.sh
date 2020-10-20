#!/usr/bin/env bash

export FLUME_HOME=$(dirname $(dirname $(realpath ${BASH_SOURCE[0]})))
export FLUME_DIR_BIN=$FLUME_HOME/bin
export FLUME_DIR_LIB=$FLUME_HOME/lib
export FLUME_DIR_TOOLS=$FLUME_HOME/tools
export FLUME_DIR_PLUGINS=$FLUME_HOME/pluguins.d
export FLUME_DIR_CONF=$FLUME_HOME/conf
export FLUME_DIR_CHANNELS=$FLUME_HOME/channels
export FLUME_DIR_SINKS=$FLUME_HOME/sinks
export FLUME_DIR_LOGS=$FLUME_HOME/logs
export FLUME_IP=$(hostname -I | cut -d' ' -f1)

export JAVA_HOME=/usr/lib/jvm/java
export JAVA_OPTS="-Xmx1g"
export JAVA_OPTS="$JAVA_OPTS -DpropertiesImplementation=org.apache.flume.node.EnvVarResolverProperties"
export JAVA_OPTS="$JAVA_OPTS -Dflume.monitoring.type=http -Dflume.monitoring.port=34545"
export JAVA_OPTS="$JAVA_OPTS -Dflume.root.logger=INFO,DAILY"
export JAVA_OPTS="$JAVA_OPTS -Dflume.log.dir=$FLUME_DIR_LOGS"
#export JAVA_OPTS="$JAVA_OPTS -Dflume.root.logger=DEBUG,console"
#export JAVA_OPTS="$JAVA_OPTS -Dorg.apache.flume.log.rawdata=true"
#export JAVA_OPTS="$JAVA_OPTS -Dorg.apache.flume.log.printconfig=true"
