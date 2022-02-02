#!/bin/bash
## 本脚本只支持锐捷系列产品
## 定义变量
The_Script_Name="$(basename `readlink -f $0`)"
The_Script_Dir="$(dirname `readlink -f $0`)"
The_Script_Version="1.0"

# 定义自动备份存储的路径
BAK_PATH="/home/zz_k113/backup"
# 备份后是否需要自动压缩
AUTO_COM="true"
# 模板文件
REMOTE_TEMPORARY_FILE="$(dirname `readlink -f $0`)/expect/ruijie.exp"
# 临时文件目录
TEMP_PATH="/tmp/auto_bak"
# 今天日期
TODAY_DATE="$(date +%Y-%m-%d)"
# 第一次执行的准备工作
function first_run(){
    # 必须使用root用户执行
    [ `whoami` != "root" ] && echo "请使用root用户执行" && exit 1
    # 检测操作系统
    if [[ -f /etc/redhat-release ]]; then
        OS_TYPE="centos"
    elif [[ -f /etc/debian ]]; then
        OS_TYPE="ubuntu"
    else
        echo "未知操作系统, 可能不被支持" && exit 1
    fi
    # 创建临时目录
    if [[ ! -d $TEMP_PATH ]]; then
        mkdir -p $TEMP_PATH
    fi
    # 创建备份目录
    if [[ ! -d $BAK_PATH ]]; then
        mkdir -p $BAK_PATH
    fi
    # 检测expect是否安装
    if type expect >/dev/null 2>&1; then
        echo "expect已安装"
    else
        echo "expect未安装, 开始安装"
        if [[ $OS_TYPE == "centos" ]]; then
            yum install -y expect
        elif [[ $OS_TYPE == "ubuntu" ]]; then
            apt-get install -y expect
        fi
    fi
    # 检测crontab是否安装
    if type crontab >/dev/null 2>&1; then
        echo "crontab已安装"
    else
        echo "crontab未安装, 开始安装"
        if [[ $OS_TYPE == "centos" ]]; then
            yum install -y crontabs
        elif [[ $OS_TYPE == "ubuntu" ]]; then
            apt-get install -y cron
        fi
    fi
}
# 转化目标文件为csv格式
function transform_xlsx_to_csv(){
    local xlsx_file_name=${1}
    local csv_file_name=${2}
    if [[ ! -x ${The_Script_Dir}/xlsx2csv ]]; then
        sudo chmod +x ${The_Script_Dir}/xlsx2csv
    fi
    if [[ ! -z ${sheet_name} ]]; then
        eval "${The_Script_Dir}/xlsx2csv -n ${sheet_name} ${xlsx_file_name} ${csv_file_name}"
        if [[ $? != 0 ]]; then
            echo "xlsx文件可能损坏，请检查"
            exit 1
        fi
        if [[ ! -s ${csv_file_name} ]]; then
            rm -f ${csv_file_name}
            echo "可能不存在该sheet，请检查是否拼写错误或者sheet名称是否正确"
            exit 1
        fi
    elif [[ ! -z ${sheet_index} ]]; then
        eval "${The_Script_Dir}/xlsx2csv -s ${sheet_index} ${xlsx_file_name} ${csv_file_name}"
        if [[ $? != 0 ]]; then
            echo "xlsx文件可能损坏，请检查"
            exit 1
        fi
        if [[ ! -s ${csv_file_name} ]]; then
            rm -f ${csv_file_name}
            echo "可能不存在该sheet，请检查是否拼写错误或者sheet名称是否正确"
            exit 1
        fi
    else
        eval "${The_Script_Dir}/xlsx2csv ${xlsx_file_name} ${csv_file_name}"
        if [[ $? != 0 ]]; then
            echo "xlsx文件可能损坏，请检查"
            exit 1
        fi
    fi
}
# 读取文件的每一行，并存入数组
# 参数1：文件名
# 参数2：数组名
function read_line_to_array() {
    local file_name=${1}
    local array_name=${2}
    local line
    local i=0
    local IFS=","
    for line in ${file_name} 
    do
        eval "$array_name[$i]='${line}'"
        i=$(($i+1))
    done
}
# 处理exp文件
function deal_exp(){
    cp -f ${REMOTE_TEMPORARY_FILE} ${TEMP_PATH}/ruijie.exp
    echo "expect \"*#\" { send \"show run\\r\" }" >> ${TEMP_PATH}/ruijie.exp
    echo "expect \"*#\" { send \"exit\\r\" }" >> ${TEMP_PATH}/ruijie.exp
    echo "expect eof" >> ${TEMP_PATH}/ruijie.exp
    echo "exit" >> ${TEMP_PATH}/ruijie.exp
    chmod +x ${TEMP_PATH}/ruijie.exp
}
# 处理每一行的数据
# 参数1：传入文件名
function deal_file_line() {
    local file_name=${1}
    local line
    local i=0
    local j=0
    local IFS=","
    while read line 
    do
        i=$(($i+1))
        if [[ $i == 1 ]]; then
            read_line_to_array "${line}" "title"
        else
            read_line_to_array "${line}" "data"
            for ((j=0;j<${#title[@]};j++))
            do
                if [[ ${title[$j]} == "IP" ]]; then
                    remote_ip = ${data[$j]}
                elif [[ ${title[$j]} == "用户名" ]]; then
                    remote_user = ${data[$j]}
                elif [[ ${title[$j]} == "密码" ]]; then
                    remote_passwd = ${data[$j]}
                elif [[ ${title[$j]} == "远程连接方式" ]]; then
                    remote_type=${data[$j]}
                elif [[ ${title[$j]} == "端口" ]]; then
                    remote_port = ${data[$j]}
                elif [[ ${title[$j]} == "enable密码" ]]; then
                    remote_enable = ${data[$j]}
                fi
            done
            if [[ -z ${remote_ip} ]]; then
                echo "第${i}行IP为空"
                exit 1
            fi
            if [[ -z ${remote_user} ]]; then
                remote_user="admin"
            fi
            if [[ -z ${remote_passwd} && ! -z ${remote_enable} ]]; then
                remote_passwd="${remote_enable}"
            fi
            if [[ ! -z ${remote_passwd} && -z ${remote_enable} ]]; then
                remote_enable="${remote_passwd}"
            fi
            if [[ -z ${remote_passwd} && -z ${remote_enable} ]]; then
                remote_passwd="admin"
                remote_enable="admin"
            fi
            if [[ -z ${remote_type} ]]; then
                remote_type="telnet"
            fi
            if [[ -z ${remote_port} && ${remote_type,,} == "telnet" ]]; then
                remote_port="23"
            fi
            if [[ -z ${remote_port} && ${remote_type,,} == "ssh" ]]; then
                remote_port="22"
            fi
        fi
        ${TEMP_PATH}/ruijie.exp ${remote_type} ${remote_ip} ${remote_user} ${remote_port} ${remote_passwd} ${remote_enable} tmp 1>/dev/null 2>&1
        if [[ $? != 0 ]]; then
            echo "第${i}行连接失败"
            exit 1
        fi
        mv tmp.log ${TEMP_PATH}/ruijie.log
        hostname=$(cat ${TEMP_PATH}/ruijie.log | grep "hostname " | grep -v "hostname ")
        if [[ -z ${hostname} ]]; then
            hostname="ruijie"
        fi
        if [[ ! -d ${TEMP_PATH}/${TODAY_DATE} ]]; then
            mkdir -p ${TEMP_PATH}/${TODAY_DATE}
        fi
        cat ${TEMP_PATH}/ruijie.log | sed -n '/^version/,/end$/p' >> ${TEMP_PATH}/${TODAY_DATE}/${hostname}(${remote_ip}).text
    done < ${file_name}
    if [[ "${AUTO_COM}" == "true" ]]; then
        if [[ -d ${TEMP_PATH}/${TODAY_DATE} ]]; then
            cd ${TEMP_PATH}/${TODAY_DATE}
            zip -r ${TODAY_DATE}.zip *
            mv ./${TODAY_DATE}.zip ${BAK_PATH}/${TODAY_DATE}.zip
            cd -
        fi
    else
        mv -r ${TEMP_PATH}/${TODAY_DATE} ${BAK_PATH}/
    fi
}

if [[ -f ~/.config_autobak.conf ]]; then
    source ~/.config_autobak.conf
else
    echo "" > ~/.config_autobak.conf
    first_run
fi
if [[ -f ${1} ]]; then
    # 获取文件后缀名
    file_suffix=${1##*.}
    # 获取文件名
    filename=${1%.*}
    # 若文件后缀名为xlsx，则转换为csv
    if [[ ${file_suffix,,} == xlsx ]]; then
        transform_xlsx_to_csv ${1} ${filename}.csv
        opt_file_name="${filename}.csv"
    elif [[ ${file_suffix,,} == csv ]]; then
        unset isxlsx
        opt_file_name="${1}"
    else
        echo "不被支持的文件，请检查文件"
        exit 1
    fi
fi
if [[ -f ${opt_file_name} ]]; then
    deal_file_line ${opt_file_name}
else
    echo "文件不存在"
    exit 1
fi