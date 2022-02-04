#!/bin/bash
## 本脚本只支持锐捷系列产品
## 定义变量
The_Script_Name="$(basename `readlink -f $0`)"
The_Script_Dir="$(dirname `readlink -f $0`)"
The_Script_Version="1.0"

# 模板文件
REMOTE_TEMPORARY_FILE="$(dirname `readlink -f $0`)/expect/ruijie.exp"
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
    echo "第一次执行的准备工作完成"
}
# 交互函数
function main(){
    local HOMEDIR="${HOME}"
    local line
    local IFS=","
    local i=0
    local j
    local input_file=${1}
    # 判断是否是第一次执行
    if [[ ! -f ~/.config_autobak.conf ]]; then
        echo "检测到第一次执行, 开始准备"
        first_run
        echo "现在需您确认您的配置信息, 请输入以下信息，若不清楚可直接回车"
        while :;do
            read -rp "请确认您传入文件信息正确：" -e -i "${input_file}" INPUT_FILE
            if [[ -f $INPUT_FILE ]]; then
                break
            else
                echo -e "文件不存在, 请重新输入\n"
            fi
            # 获取文件后缀名
            file_suffix=${INPUT_FILE##*.}
            # 获取文件名
            filename=${INPUT_FILE%.*}
            if [[ ${file_suffix,,} == "csv" ]]; then
                cp ${INPUT_FILE} /tmp/tmp.csv
                break
            fi
            # 若文件后缀名为xlsx，则转换为csv
            if [[ ${file_suffix,,} != xlsx ]]; then
                echo "不被支持的文件，请检查文件"
                exit 1
            fi
            if [[ ! -x ${The_Script_Dir}/xlsx2csv ]]; then
                sudo chmod +x ${The_Script_Dir}/xlsx2csv
            fi
            ${The_Script_Dir}/xlsx2csv ${INPUT_FILE} 2&>1 >/dev/null
            if [[ $? != 0 ]]; then
                echo "文件校验失败，可能损坏，请检查文件"
                exit 1
            fi
        done
        if [[ ${file_suffix,,} != "csv" ]]; then
            while :;do
                while read line 
                do
                    echo "${i}、${line}" >> /tmp/sheet.tmp
                    ((i++))
                done < $(${The_Script_Dir}/xlsx2csv list ${INPUT_FILE})
                cat /tmp/sheet.tmp
                read -rp "请选择表格sheet(输入对应sheet前的数字)[0~${i}]：" -e -i "0" INPUT_SHEET
                if [[ $INPUT_SHEET -ge 0 && $INPUT_SHEET -lt $i ]]; then
                    echo "INPUT_SHEET=$INPUT_SHEET"
                    break
                else
                    echo -e "输入错误, 请输入0~${i}范围内的数字！\n"
                fi
            done
        fi
        while :;do
            read -rp "请输入备份文件路径: " -e -i "${HOMEDIR}/backup" BAK_PATH
            if [[ -f ${BAK_PATH} ]]; then
                echo -e "路径不能为文件, 请重新输入\n"
            else
                if [[ ! -d $BAK_PATH ]]; then
                    mkdir -p $(readlink -f $BAK_PATH)
                fi
                echo "BAK_PATH=$(readlink -f $BAK_PATH)" >> ~/.config_autobak.conf
                break
            fi
        done
        while :;do
            read -rp "请输入是否需要在备份后自动压缩(true/false): " -e -i "true" AUTO_COM
            if [[ $AUTO_COM == "true" ]] || [[ $AUTO_COM == "false" ]]; then
                echo "AUTO_COM=${AUTO_COM}" >> ~/.config_autobak.conf
                break
            else
                echo -e "输入错误, 请输入true或false\n"
            fi
        done
        while :;do
            echo "请输入备份时间段，格式为crontab表达式，(可访问 https://www.gjk.cn/crontab 生成crontab表达式)"
            read -rp "请输入[默认为每周一的0点进行执行]：" -e -i "0 0 * * 1" CRON_TIME
            crontab -l 2>/dev/null >/tmp/crontab.tmp
            echo "${CRON_TIME} -" | crontab -
            if [[ $? != 0 ]]; then
                echo -e "输入错误, 请输入正确的crontab表达式\n"
                crontab -r 
                crontab /tmp/crontab.tmp
                rm -f /tmp/crontab.tmp
            else
                crontab -r 
                crontab /tmp/crontab.tmp
                rm -f /tmp/crontab.tmp
                break
            fi
        done
        if [[ ${file_suffix,,} != "csv" ]]; then
            ${The_Script_Dir}/xlsx2csv --sheet=${INPUT_SHEET} ${INPUT_FILE} 2>/dev/null >/tmp/tmp.csv
        fi
        for j in $(head -n 1 /tmp/tmp.csv); do
            if [[ ${j} == "IP" ]]; then
                Remote_Host_Key="${j}"
            elif [[ ${j} == "用户名" ]]; then
                Remote_User_Key="${j}"
            elif [[ ${j} == "密码" ]]; then
                Remote_Pass_Key="${j}"
            elif [[ ${j} == "远程连接方式" ]]; then
                Remote_Mode_Key="${j}"
            elif [[ ${j} == "端口" ]]; then
                Remote_Port_Key="${j}"
            elif [[ ${j} == "enable密码" ]]; then
                Remote_Enable_Password_Key="${j}"
            fi
        done
        i=1
        for line in $(cat /tmp/tmp.csv); do
                echo "${i}、${line}" >> /tmp/tmp.txt
                ((i++))
        done
        if [[ -z ${Remote_Host_Key} ]]; then
            while :;do
                cat /tmp/tmp.txt
                echo "IP列不存在, 该列为必填项"
                read -rp "请选择IP列(输入对应列前的序号[1~${i}])：" -e INPUT
                if [[ $INPUT -ge 1 && $INPUT_SHEET -lt $i ]]; then
                    Remote_Host_Key=$(sed -n "${INPUT}p" /tmp/tmp.txt|awk -F'、' '{print $2}')
                    break
                else
                    echo -e "输入错误, 请输入0~${i}范围内的数字！请重新输入！\n"
                fi
            done
        fi
        if [[ -z ${Remote_User_Key} ]]; then
            while :;do
                cat /tmp/tmp.txt
                echo "用户名列不存在, 该列选填"
                read -rp "请选择用户名列(输入对应列前的序号[1~${i}])：" -e INPUT
                if [[ $INPUT -ge 1 && $INPUT_SHEET -lt $i ]]; then
                    Remote_User_Key=$(sed -n "${INPUT}p" /tmp/tmp.txt|awk -F'、' '{print $2}')
                    break
                elif [[ -z ${INPUT} ]]; then
                    break
                else
                    echo -e "输入错误, 请输入0~${i}范围内的数字！请重新输入！\n"
                fi
            done
        fi
        if [[ -z ${Remote_Pass_Key} ]]; then
            while :;do
                cat /tmp/tmp.txt
                echo "密码列不存在, 该列必填"
                read -rp "请选择密码列(输入对应列前的序号[1~${i}])：" -e INPUT
                if [[ $INPUT -ge 1 && $INPUT_SHEET -lt $i ]]; then
                    Remote_Pass_Key=$(sed -n "${INPUT}p" /tmp/tmp.txt|awk -F'、' '{print $2}')
                    break
                else
                    echo -e "输入错误, 请输入0~${i}范围内的数字！请重新输入！\n"
                fi
            done
        fi
        if [[ -z ${Remote_Enable_Password_Key} ]]; then
            while :;do
                cat /tmp/tmp.txt
                echo "enable密码列不存在, 该列选填, 默认同密码列"
                read -rp "请选择enable密码列(输入对应列前的序号[1~${i}])：" -e INPUT
                if [[ $INPUT -ge 1 && $INPUT_SHEET -lt $i ]]; then
                    Remote_Enable_Password_Key=$(sed -n "${INPUT}p" /tmp/tmp.txt|awk -F'、' '{print $2}')
                    break
                elif [[ -z ${INPUT} ]]; then
                    break
                else
                    echo -e "输入错误, 请输入0~${i}范围内的数字！请重新输入！\n"
                fi
            done
        fi
        if [[ -z ${Remote_Mode_Key} ]]; then
            while :;do
                cat /tmp/tmp.txt
                echo "远程连接方式列不存在, 该列选填, 默认为telnet"
                read -rp "请选择远程连接方式列(输入对应列前的序号[1~${i}])：" -e INPUT
                if [[ $INPUT -ge 1 && $INPUT_SHEET -lt $i ]]; then
                    Remote_Mode_Key=$(sed -n "${INPUT}p" /tmp/tmp.txt|awk -F'、' '{print $2}')
                    break
                elif [[ -z ${INPUT} ]]; then
                    break
                else
                    echo -e "输入错误, 请输入0~${i}范围内的数字！请重新输入！\n"
                fi
            done
        fi
        if [[ -z ${Remote_Port_Key} ]]; then
            while :;do
                cat /tmp/tmp.txt
                echo "端口列不存在, 该列选填, 默认为23"
                read -rp "请选择端口列(输入对应列前的序号[1~${i}])：" -e INPUT
                if [[ $INPUT -ge 1 && $INPUT_SHEET -lt $i ]]; then
                    Remote_Port_Key=$(sed -n "${INPUT}p" /tmp/tmp.txt|awk -F'、' '{print $2}')
                    break
                elif [[ -z ${INPUT} ]]; then
                    break
                else
                    echo -e "输入错误, 请输入0~${i}范围内的数字！请重新输入！\n"
                fi
            done
        fi
        rm -f /tmp/tmp.txt /tmp/tmp.csv 
        echo "信息收集完毕，请确认！"
        echo "xlsx文件位置：${INPUT_FILE}"
        echo "xlsx sheet：$(sed -n "${INPUT_SHEET}p" /tmp/sheet.tmp |awk -F'、' '{print $2}')"
        echo "备份文件路径：${BAK_PATH}"
        echo "是否需要备份后自动压缩：${AUTO_COM}"
        echo "备份时间段：${CRON_TIME}"
        echo "远程主机名称列：${Remote_Host_Key}"
        echo "远程用户名列：$(if [ -z ${Remote_User_Key} ]; then echo "null"; else echo "${Remote_User_Key}"; fi )"
        echo "远程密码列：$(if [ -z ${Remote_Pass_Key} ]; then echo "null"; else echo "${Remote_Pass_Key}"; fi )"
        echo "远程enable密码列：$(if [ -z ${Remote_Enable_Password_Key} ]; then echo "${Remote_Pass_Key}"; else echo "${Remote_Enable_Password_Key}"; fi )"
        echo
        read -rp "是否确认？[Y/n]：" -e -n 1 yn
        if [[ ${INPUT} == [Yy] || -z ${yn} ]]; then
            echo "INPUT_FILE=${INPUT_FILE}" >> ~/.config_autobak.conf
            echo "INPUT_SHEET=${INPUT_SHEET}" >> ~/.config_autobak.conf
            echo "BAK_PATH=${BAK_PATH}" >> ~/.config_autobak.conf
            echo "AUTO_COM=${AUTO_COM}" >> ~/.config_autobak.conf
            echo "CRON_TIME=\"${CRON_TIME}\"" >> ~/.config_autobak.conf
            echo "Remote_Host_Key=${Remote_Host_Key}" >> ~/.config_autobak.conf
            echo "Remote_User_Key=${Remote_User_Key}" >> ~/.config_autobak.conf
            echo "Remote_Pass_Key=${Remote_Pass_Key}" >> ~/.config_autobak.conf
            echo "Remote_Enable_Password_Key=${Remote_Enable_Password_Key}" >> ~/.config_autobak.conf
            echo "Remote_Mode_Key=${Remote_Mode_Key}" >> ~/.config_autobak.conf
            echo "Remote_Port_Key=${Remote_Port_Key}" >> ~/.config_autobak.conf
            echo "设置完毕！"
            rm -f /tmp/tmp.txt /tmp/tmp.csv /tmp/sheet.tmp
        else
            exit 0
        fi
    else
        source ~/.config_autobak.conf
        transform_xlsx_to_csv ${INPUT_FILE} ${TEMP_PATH}/data.csv
        deal_exp
        deal_file_line ${TEMP_PATH}/data.csv
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
    elif [[ ! -z ${INPUT_SHEET} ]]; then
        eval "${The_Script_Dir}/xlsx2csv -t -s ${INPUT_SHEET} ${xlsx_file_name} ${csv_file_name}"
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
function deal_file_line(){
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
                if [[ ${title[$j]} == "${Remote_Host_Key}" ]]; then
                    remote_ip = ${data[$j]}
                elif [[ ${title[$j]} == "${Remote_User_Key}" ]]; then
                    remote_user = ${data[$j]}
                elif [[ ${title[$j]} == "${Remote_Pass_Key}" ]]; then
                    remote_passwd = ${data[$j]}
                elif [[ ${title[$j]} == "${Remote_Mode_Key}" ]]; then
                    remote_type = ${data[$j]}
                elif [[ ${title[$j]} == "${Remote_Port_Key}" ]]; then
                    remote_port = ${data[$j]}
                elif [[ ${title[$j]} == "${emote_Enable_Password_Key}" ]]; then
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
            rm -rf ${TEMP_PATH}/${TODAY_DATE}
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
if [[ ! -d ${TEMP_PATH} ]]; then
    mkdir -p ${TEMP_PATH}
fi
if [[ -f ${opt_file_name} ]]; then
    deal_exp
    deal_file_line ${opt_file_name}
else
    echo "文件不存在"
    exit 1
fi