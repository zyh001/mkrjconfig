#!/bin/bash
## 本脚本只支持锐捷系列产品
## 定义变量
The_Script_Name="$(basename `readlink -f $0`)"
The_Script_Dir="$(dirname `readlink -f $0`)"
The_Script_Version="1.0"
HOMEDIR=${HOME}
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
    elif [[ -f /etc/debian_version ]]; then
        OS_TYPE="ubuntu"
    else
        echo "未知操作系统, 可能不被支持" && exit 1
    fi
    # 创建临时目录
    if [[ ! -d $TEMP_PATH ]]; then
        mkdir -p $TEMP_PATH
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
    local line
    local IFS=","
    local i=0
    local j
    local input_file=${1}
    # 判断是否是第一次执行
    if [[ ! -f ${HOMEDIR}/.config_autobak.conf ]]; then
        echo "检测到第一次执行, 开始准备"
        first_run
        echo "现在需您确认您的配置信息, 请输入以下信息，若不清楚可直接回车"
        while :;do
            read -rp "请确认您传入文件信息正确：" -e -i "${input_file}" INPUT_FILE
            if [[ ! -f $INPUT_FILE ]]; then
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
            if [[ ${file_suffix,,} == xlsx ]]; then
                break
            else
                echo "不被支持的文件，请检查文件"
                exit 1
            fi
            if [[ ! -x ${The_Script_Dir}/xlsx2csv ]]; then
                sudo chmod +x ${The_Script_Dir}/xlsx2csv
            fi
            ${The_Script_Dir}/xlsx2csv ${INPUT_FILE} >/dev/null 2>&1
            if [[ $? != 0 ]]; then
                echo "文件校验失败，可能损坏，请检查文件"
                exit 1
            fi
        done
        if [[ ${file_suffix,,} != "csv" ]]; then
            ${The_Script_Dir}/xlsx2csv list ${INPUT_FILE} > /tmp/sheet.txt
            if [[ -f /tmp/sheet.tmp ]]; then
                rm -f /tmp/sheet.tmp
            fi
            while :;do
                i=0
                while read line 
                do
                    echo "${i}、${line}" >> /tmp/sheet.tmp
                    ((i++))
                done < /tmp/sheet.txt
                cat /tmp/sheet.tmp
                read -rp "请选择表格sheet(输入对应sheet前的数字)[0~$((i-1))]：" -e -i "0" INPUT_SHEET
                if [[ $INPUT_SHEET == 0 ]]; then
                    rm -f /tmp/sheet.txt
                    break
                elif [[ $INPUT_SHEET -ge 0 && $INPUT_SHEET -lt $((i-1)) ]]; then
                    rm -f /tmp/sheet.txt
                    break
                else
                    echo -e "输入错误, 请输入0~${i}范围内的数字！\n"
                fi
            done
        fi
        while :;do
            read -rp "请输入备份文件路径: " -e -i "${HOMEDIR}/switch_bak" BAK_PATH
            if [[ -f ${BAK_PATH} ]]; then
                echo -e "路径不能为文件, 请重新输入\n"
            else
                if [[ ! -d $BAK_PATH ]]; then
                    mkdir -p $(readlink -f $BAK_PATH)
                fi
                break
            fi
        done
        while :;do
            read -rp "请输入是否需要在备份后自动压缩(true/false): " -e -i "true" AUTO_COM
            if [[ $AUTO_COM == "true" ]] || [[ $AUTO_COM == "false" ]]; then
                break
            else
                echo -e "输入错误, 请输入true或false\n"
            fi
        done
        while :;do
            echo "请输入备份时间段，格式为crontab表达式，(可访问 https://www.gjk.cn/crontab 生成crontab表达式)"
            read -rp "请输入[默认为每周一的1点进行执行]：" -e -i "0 1 * * 1" CRON_TIME
            crontab -l 2>/dev/null >/tmp/crontab.tmp
            echo "${CRON_TIME} echo" | crontab - 2>/dev/null
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
        for line in $(head -n 1 /tmp/tmp.csv); do
                echo "${i}、${line}" >> /tmp/tmp.txt
                ((i++))
        done
        if [[ -z ${Remote_Host_Key} ]]; then
            while :;do
                cat /tmp/tmp.txt
                echo "IP列不存在, 该列为必填项"
                read -rp "请选择IP列(输入对应列前的序号[1~$((i-1))])：" -e INPUT
                if [[ $INPUT -ge 1 && $INPUT -lt $((i-1)) ]]; then
                    Remote_Host_Key=$(sed -n "${INPUT}p" /tmp/tmp.txt|awk -F'、' '{print $2}')
                    break
                else
                    echo -e "输入错误, 请输入1~$((i-1))范围内的数字！请重新输入！\n"
                fi
            done
        fi
        if [[ -z ${Remote_User_Key} ]]; then
            while :;do
                cat /tmp/tmp.txt
                echo "用户名列不存在, 该列选填"
                read -rp "请选择用户名列(输入对应列前的序号[1~$((i-1))])：" -e INPUT
                if [[ $INPUT -ge 1 && $INPUT -lt $((i-1)) ]]; then
                    Remote_User_Key=$(sed -n "${INPUT}p" /tmp/tmp.txt|awk -F'、' '{print $2}')
                    break
                elif [[ -z ${INPUT} ]]; then
                    break
                else
                    echo -e "输入错误, 请输入1~$((i-1))范围内的数字！请重新输入！\n"
                fi
            done
        fi
        if [[ -z ${Remote_Pass_Key} ]]; then
            while :;do
                cat /tmp/tmp.txt
                echo "密码列不存在, 该列必填"
                read -rp "请选择密码列(输入对应列前的序号[1~$((i-1))])：" -e INPUT
                if [[ $INPUT -ge 1 && $INPUT -lt $((i-1)) ]]; then
                    Remote_Pass_Key=$(sed -n "${INPUT}p" /tmp/tmp.txt|awk -F'、' '{print $2}')
                    break
                else
                    echo -e "输入错误, 请输入1~$((i-1))范围内的数字！请重新输入！\n"
                fi
            done
        fi
        if [[ -z ${Remote_Enable_Password_Key} ]]; then
            while :;do
                cat /tmp/tmp.txt
                echo "enable密码列不存在, 该列选填, 默认同密码列"
                read -rp "请选择enable密码列(输入对应列前的序号[1~$((i-1))])：" -e INPUT
                if [[ $INPUT -ge 1 && $INPUT -lt $((i-1)) ]]; then
                    Remote_Enable_Password_Key=$(sed -n "${INPUT}p" /tmp/tmp.txt|awk -F'、' '{print $2}')
                    break
                elif [[ -z ${INPUT} ]]; then
                    break
                else
                    echo -e "输入错误, 请输入1~$((i-1))范围内的数字！请重新输入！\n"
                fi
            done
        fi
        if [[ -z ${Remote_Mode_Key} ]]; then
            while :;do
                cat /tmp/tmp.txt
                echo "远程连接方式列不存在, 该列选填, 默认为telnet"
                read -rp "请选择远程连接方式列(输入对应列前的序号[1~$((i-1))])：" -e INPUT
                if [[ $INPUT -ge 1 && $INPUT -lt $((i-1)) ]]; then
                    Remote_Mode_Key=$(sed -n "${INPUT}p" /tmp/tmp.txt|awk -F'、' '{print $2}')
                    break
                elif [[ -z ${INPUT} ]]; then
                    break
                else
                    echo -e "输入错误, 请输入1~$((i-1))范围内的数字！请重新输入！\n"
                fi
            done
        fi
        if [[ -z ${Remote_Port_Key} ]]; then
            while :;do
                cat /tmp/tmp.txt
                echo "端口列不存在, 该列选填, 默认为23"
                read -rp "请选择端口列(输入对应列前的序号[1~$((i-1))])：" -e INPUT
                if [[ $INPUT -ge 1 && $INPUT -lt $((i-1)) ]]; then
                    Remote_Port_Key=$(sed -n "${INPUT}p" /tmp/tmp.txt|awk -F'、' '{print $2}')
                    break
                elif [[ -z ${INPUT} ]]; then
                    break
                else
                    echo -e "输入错误, 请输入1~$((i-1))范围内的数字！请重新输入！\n"
                fi
            done
        fi
        echo "信息收集完毕，请确认！"
        echo "模板文件位置：${INPUT_FILE}"
        if [[ ${file_suffix,,} == "xlsx" ]]; then
            echo "xlsx sheet：$(sed -n "$((INPUT_SHEET+1))p" /tmp/sheet.tmp |awk -F'、' '{print $2}')"
        fi
        echo "备份文件路径：${BAK_PATH}"
        echo "是否需要备份后自动压缩：${AUTO_COM}"
        echo "备份时间段：${CRON_TIME}"
        echo "远程主机名称列：${Remote_Host_Key}"
        echo "远程用户名列：$(if [ -z ${Remote_User_Key} ]; then echo "null"; else echo "${Remote_User_Key}"; fi )"
        echo "远程密码列：$(if [ -z ${Remote_Pass_Key} ]; then echo "null"; else echo "${Remote_Pass_Key}"; fi )"
        echo "远程enable密码列：$(if [ -z ${Remote_Enable_Password_Key} ]; then echo "${Remote_Pass_Key}"; else echo "${Remote_Enable_Password_Key}"; fi )"
        echo
        read -rp "是否确认？[Y/n]：" -e -n 1 yn
        if [[ ${yn} == [Yy] || -z ${yn} ]]; then
            echo "INPUT_FILE=$(readlink -f ${INPUT_FILE})" >> ${HOMEDIR}/.config_autobak.conf
            echo "INPUT_SHEET=${INPUT_SHEET}" >> ${HOMEDIR}/.config_autobak.conf
            echo "BAK_PATH=$(readlink -f $BAK_PATH)" >> ${HOMEDIR}/.config_autobak.conf
            echo "AUTO_COM=${AUTO_COM}" >> ${HOMEDIR}/.config_autobak.conf
            echo "CRON_TIME=\"${CRON_TIME}\"" >> ${HOMEDIR}/.config_autobak.conf
            echo "Remote_Host_Key=${Remote_Host_Key}" >> ${HOMEDIR}/.config_autobak.conf
            echo "Remote_User_Key=${Remote_User_Key}" >> ${HOMEDIR}/.config_autobak.conf
            echo "Remote_Pass_Key=${Remote_Pass_Key}" >> ${HOMEDIR}/.config_autobak.conf
            echo "Remote_Enable_Password_Key=${Remote_Enable_Password_Key}" >> ${HOMEDIR}/.config_autobak.conf
            echo "Remote_Mode_Key=${Remote_Mode_Key}" >> ${HOMEDIR}/.config_autobak.conf
            echo "Remote_Port_Key=${Remote_Port_Key}" >> ${HOMEDIR}/.config_autobak.conf
            echo "设置完毕！"
            chmod a+r ${HOMEDIR}/.config_autobak.conf
            deal_crond >/dev/null 2>&1
            rm -f /tmp/tmp.txt /tmp/tmp.csv /tmp/sheet.tmp /tmp/sheet.csv
            echo "按回车键，将自动进行第一次备份工作，您也可以通过Ctrl-C结束运行，系统将在指定的时间自动进行备份！"
            read -s 
            echo "开始备份！"
            main
            exit 0
        else
            rm -f /tmp/tmp.txt /tmp/tmp.csv /tmp/sheet.tmp /tmp/sheet.csv
            exit 0
        fi
    else
        source ${HOMEDIR}/.config_autobak.conf
        file_suffix=${INPUT_FILE##*.}
        if [[ ${file_suffix,,} != "csv" ]]; then
            transform_xlsx_to_csv ${INPUT_FILE} ${TEMP_PATH}/data.csv
        elif [[ ${file_suffix,,} == "csv" ]]; then
            cp ${INPUT_FILE} ${TEMP_PATH}/data.csv
        fi
        deal_exp
        deal_file_line ${TEMP_PATH}/data.csv
    fi
}
# 转化目标文件为csv格式
function transform_xlsx_to_csv(){
    local xlsx_file_name=${1}
    local csv_file_name=${2}
    if [[ ! -x ${The_Script_Dir}/xlsx2csv ]]; then
        chmod +x ${The_Script_Dir}/xlsx2csv
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
    echo "expect \"*#\" { send \"exit\\r\" }" >> ${TEMP_PATH}/ruijie.exp
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
                    remote_ip="${data[$j]}"
                elif [[ ${title[$j]} == "${Remote_User_Key}" ]]; then
                    remote_user="${data[$j]}"
                elif [[ ${title[$j]} == "${Remote_Pass_Key}" ]]; then
                    remote_passwd="${data[$j]}"
                elif [[ ${title[$j]} == "${Remote_Mode_Key}" ]]; then
                    remote_type="${data[$j]}"
                elif [[ ${title[$j]} == "${Remote_Port_Key}" ]]; then
                    remote_port="${data[$j]}"
                elif [[ ${title[$j]} == "${emote_Enable_Password_Key}" ]]; then
                    remote_enable="${data[$j]}"
                fi
            done
            if [[ -z ${remote_ip} ]]; then
                echo "第${i}行IP为空"
                continue
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
            ping -c 1 -w 1 ${remote_ip} &>/dev/null
            if [[ $? != 0 ]]; then
                echo "第$((i-1))行IP-${remote_ip}不可达"
                continue
            fi
            if [[ -f tmp.log ]]; then
                rm -f tmp.log
            fi
            ${TEMP_PATH}/ruijie.exp ${remote_type} ${remote_ip} ${remote_user} ${remote_port} ${remote_passwd} ${remote_enable} tmp 1>/dev/null 2>&1
            if [[ $? != 0 ]]; then
                echo "第$((i-1))行IP-${remote_ip}连接失败"
                continue
            fi
            mv tmp.log ${TEMP_PATH}/ruijie.log
            hostname=$(cat ${TEMP_PATH}/ruijie.log | grep "hostname " | awk -F' ' '{print $2}')
            if [[ -z ${hostname} ]]; then
                hostname="Ruijie"
            fi
            if [[ ! -d ${TEMP_PATH}/${TODAY_DATE} ]]; then
                mkdir -p ${TEMP_PATH}/${TODAY_DATE}
            fi
            hostname=$(echo ${hostname} | sed 's/\r//g')
            cat ${TEMP_PATH}/ruijie.log | sed -n '/^version/,/^end/p' >> "${TEMP_PATH}/${TODAY_DATE}/[${remote_ip}]${hostname}.text"
            sed -i 's/\r//g' "${TEMP_PATH}/${TODAY_DATE}/[${remote_ip}]${hostname}.text"
            echo "第$((i-1))行IP-${remote_ip}[${hostname}]备份成功"
        fi
    done < ${file_name}
    if [[ "${AUTO_COM}" == "true" ]]; then
        if [[ -d ${TEMP_PATH}/${TODAY_DATE} ]]; then
            cd ${TEMP_PATH}/${TODAY_DATE}
            if type zip >/dev/null 2>&1; then
                zip -q -r ${TODAY_DATE}.zip *
                mv ./${TODAY_DATE}.zip "$(readlink -f ${BAK_PATH})/${TODAY_DATE}.zip"
            elif type tar >/dev/null 2>&1; then
                tar -zcf ${TODAY_DATE}.tar.gz *
                mv ./${TODAY_DATE}.tar.gz "$(readlink -f ${BAK_PATH})/${TODAY_DATE}.tar.gz"
            fi
            rm -rf ${TEMP_PATH}/${TODAY_DATE}
            cd - >/dev/null 2>&1
        fi
    else
        mv -r ${TEMP_PATH}/${TODAY_DATE} ${BAK_PATH}/
    fi
}
deal_crond(){
    if [[ ! -z ${CRON_TIME} ]]; then
        crontab -l 2>/dev/null > ${TEMP_PATH}/crontab.txt
        grep "bash ${The_Script_Dir}/${The_Script_Name}" ${TEMP_PATH}/crontab.txt > ${TEMP_PATH}/crontab.tmp
        if [[ -z $(cat ${TEMP_PATH}/crontab.tmp) ]]; then
            echo "${CRON_TIME} bash ${The_Script_Dir}/${The_Script_Name}" 
            (crontab -l 2>/dev/null; echo "${CRON_TIME} bash ${The_Script_Dir}/${The_Script_Name}") | crontab -
        else
            grep -v "${CRON_TIME/\*/\\\*} bash ${The_Script_Dir}/${The_Script_Name}" ${TEMP_PATH}/crontab.txt > ${TEMP_PATH}/crontab.tmp
            echo "${CRON_TIME} bash ${The_Script_Dir}/${The_Script_Name}" >> ${TEMP_PATH}/crontab.tmp
            uniq -u ${TEMP_PATH}/crontab.tmp > ${TEMP_PATH}/crontab.tmp2
            crontab -r
            crontab ${TEMP_PATH}/crontab.tmp2 >/dev/null 2>&1
        fi
        rm -f ${TEMP_PATH}/crontab.txt ${TEMP_PATH}/crontab.tmp ${TEMP_PATH}/crontab.tmp2
    fi
}
if [[ -f ${HOMEDIR}/.config_autobak.conf ]]; then
    source ${HOMEDIR}/.config_autobak.conf
fi
if [[ -d ${TEMP_PATH} ]]; then
    rm -rf ${TEMP_PATH}/*
    mkdir -p "${TEMP_PATH}/${TODAY_DATE}"
else
    mkdir -p "${TEMP_PATH}/${TODAY_DATE}"
fi
main ${1} | tee "${TEMP_PATH}/${TODAY_DATE}/autobak.log"
exit 0