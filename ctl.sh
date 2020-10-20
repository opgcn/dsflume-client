#!/usr/bin/env bash
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Author:   li.lei03@opg.cn
# Created:  2020-09-07
# Purpose:  control flume agent

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# global configs

SYSTEMD_UNIT_NAME="dsflume-client"
source $(dirname $(realpath ${BASH_SOURCE[0]}))/conf/flume-env.sh || exit $?

FILE_THIS=$(basename ${BASH_SOURCE[0]})
IS_LOGGING=1
LIFECYCLE_SINK_DISCARDS=15d
LIFECYCLE_LOGS=30d

TPL_UNIT="
# https://github.com/opgcn/dsflume-client
# 此unit文件由 $(realpath ${BASH_SOURCE[0]}) 在 $(date +"%F %T %z") 生成

[Unit]
Description=数据中台定制Flume客户端${SYSTEMD_UNIT_NAME}
Documentation=https://github.com/opgcn/dsflume-client
After=local-fs.target remote-fs.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=${FLUME_HOME}
ExecStart=${FLUME_DIR_BIN}/flume-ng agent -n a -c conf -f ${FLUME_DIR_CONF}/default.conf
TimeoutSec=10

[Install]
WantedBy=multi-user.target
"

HELP="
$FILE_THIS - Control tool for $SYSTEMD_UNIT_NAME agent.

Usage:
    reinstall   Install Apache Flume to $FLUME_HOME
    unit        Install systemd unit file and reload it:
                from $FLUME_DIR_CONF/$SYSTEMD_UNIT_NAME.service
                to /usr/lib/systemd/system/
    journal     Display startup logs
    status      Show runtime status
    restart     Start or restart $SYSTEMD_UNIT_NAME
    stop        Stop $SYSTEMD_UNIT_NAME
    enable      Enable auto-restart $SYSTEMD_UNIT_NAME when power on
    disable     Disable auto-restart $SYSTEMD_UNIT_NAME when power on
    du          Query disk usages of {sinks,channels,logs}/*
    verify      Verify all channels' datadirs
    housekeep   Clean caches left over from history, typically set in crontab:
                @daily bash -l $(realpath ${BASH_SOURCE[0]}) housekeep
    test        Display test commands
    help        Show this help message
"

TEST_CMDS='
# Test with Netcat protocol, you can use:
nc -v localhost 20002 <<EOF
V2|$(hostname -I | cut -d" " -f1)|TEST_EXAMPLE_TYPE_1|TEST|$(date +"%F %T")|字段5|字段6|字段7
V2|$(hostname -I | cut -d" " -f1)|TEST_EXAMPLE_TYPE_2|TEST|$(date +"%F %T")|字段V|字段VI
EOF
'


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# common functions

function echoDebug
# echo debug message
#   $1: debug level
#   $2: message string
{
    if [ 1 -eq ${IS_LOGGING} ]; then
        echo -e "\e[7;93m[$FILE_THIS $(date +'%F %T') $1]\e[0m \e[93m$2\e[0m" >&2
    fi
}

function runCmd
{
    echoDebug DEBUG "Running command: $*"
    $@
    nRet=$?; [ 0 -eq $nRet ] || echoDebug WARN "Fetch non-zero return code '$nRet' from cmd: $*"
    return $nRet
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# process functions

function main
{
    declare sOpt="$1"
    if [ "$sOpt" == "help" ] || [ "$sOpt" == '' ]; then
        echo "$HELP"
    elif [ "$sOpt" == "reinstall" ]; then
        choDebug INFO "Installing Apache Flume to $FLUME_HOME"
        sDirTmp=$FLUME_HOME/tmp.d
        sUrlDownload='https://mirrors.tuna.tsinghua.edu.cn/apache/flume/1.9.0/apache-flume-1.9.0-bin.tar.gz'
        sPathTargz=$sDirTmp/$(basename $sUrlDownload)
        sDirExtracted=$sDirTmp/$(basename $sPathTargz .tar.gz)
        runCmd rm -rf $sDirTmp \
        && runCmd mkdir -p $sDirTmp \
        && runCmd wget $sUrlDownload -O $sPathTargz \
        && runCmd tar -C $sDirTmp -xzf $sPathTargz \
        && runCmd mkdir -p $FLUME_DIR_PLUGINS $FLUME_DIR_CHANNELS $FLUME_DIR_SINKS $FLUME_DIR_LOGS \
        && runCmd rm -rf $FLUME_DIR_BIN $FLUME_DIR_LIB $FLUME_DIR_TOOLS \
        && runCmd mv $sDirExtracted/bin $sDirExtracted/lib $sDirExtracted/tools $FLUME_HOME \
        && runCmd mv -f $sDirExtracted/conf/log4j.properties $FLUME_DIR_CONF \
        && runCmd rm -rf $sDirTmp \
        && runCmd ls -alFh --time-style=long-iso --color=auto $FLUME_HOME
    elif [ "$sOpt" == "unit" ]; then
        echoDebug INFO "Installing systemd unit file of '$SYSTEMD_UNIT_NAME'" \
        && echo "$TPL_UNIT" > /usr/lib/systemd/system/$SYSTEMD_UNIT_NAME.service \
        && runCmd cat /usr/lib/systemd/system/$SYSTEMD_UNIT_NAME.service \
        && runCmd exec systemctl daemon-reload
    elif [ "$sOpt" == "journal" ]; then
        echoDebug INFO "Displaying startup logs of systemd unit '$SYSTEMD_UNIT_NAME'"
        runCmd exec journalctl -u $SYSTEMD_UNIT_NAME
    elif [ "$sOpt" == "status" ]; then
        echoDebug INFO "Querying status of systemd unit '$SYSTEMD_UNIT_NAME'"
        runCmd exec systemctl status -l $SYSTEMD_UNIT_NAME
    elif [ "$sOpt" == "restart" ]; then
        echoDebug INFO "Starting or restarting systemd unit '$SYSTEMD_UNIT_NAME'"
        runCmd exec systemctl restart $SYSTEMD_UNIT_NAME
    elif [ "$sOpt" == "stop" ]; then
        echoDebug INFO "Stopping systemd unit '$SYSTEMD_UNIT_NAME'"
        runCmd exec systemctl stop $SYSTEMD_UNIT_NAME
    elif [ "$sOpt" == "enable" ]; then
        echoDebug INFO "Enabling systemd unit '$SYSTEMD_UNIT_NAME'"
        runCmd exec systemctl enable $SYSTEMD_UNIT_NAME
    elif [ "$sOpt" == "disable" ]; then
        echoDebug INFO "Disabling systemd unit '$SYSTEMD_UNIT_NAME'"
        runCmd exec systemctl disable $SYSTEMD_UNIT_NAME
    elif [ "$sOpt" == "du" ]; then
        echoDebug INFO "Querying disk usages of {sinks,channels,logs}/*"
        runCmd du -hd2 $FLUME_DIR_CHANNELS \
        && runCmd du -ha $FLUME_DIR_SINKS \
        && runCmd du -ha $FLUME_DIR_LOGS
    elif [ "$sOpt" == "verify" ]; then
        sCsvDataDirs=$(echo $FLUME_DIR_CHANNELS/*/data | tr " " ",")
        echoDebug INFO "Verifying all channels' datadirs"
        runCmd exec $FLUME_DIR_BIN/flume-ng tool -c $FLUME_DIR_CONF FCINTEGRITYTOOL -l $sCsvDataDirs
    elif [ "$sOpt" == "housekeep" ]; then
        echoDebug INFO "Start housekeeping"
        if [ -z "$(which tmpwatch 2> /dev/null)" ]; then
            echoDebug ERROR "Tool 'tmpwatch' not found! Please 'yum install -y tmpwatch'"
            return 128
        fi
        runCmd tmpwatch -dumcvv $LIFECYCLE_LOGS $FLUME_DIR_LOGS
        runCmd tmpwatch -dumcvv $LIFECYCLE_SINK_DISCARDS $FLUME_DIR_SINKS
    elif [ "$sOpt" == "test" ]; then
        echoDebug INFO "Showing test command"
        echo "$TEST_CMDS"
    else
        echoDebug ERROR "invalid option '$sOpt'"
        echo "$HELP"
        return 1
    fi
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

main $@
