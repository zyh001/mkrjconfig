#!/usr/bin/env bash
# 该脚本用于生成交换机配置文件
The_Script_Name="$(basename `readlink -f $0`)"
The_Script_Dir="$(dirname `readlink -f $0`)"
The_Script_Opts="$@"
Remote_Host_Key="remote_host"
Remote_User_Key="remote_user"
Remote_Password_Key="remote_password"
Remote_Enable_Password_Key="remote_enable_password"
Remote_Port_Key="remote_port"
Remote_Mode_Key="remote_mode"
Hardware_Type_Key="hardware_type"
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

# 在文件中，用一个数组置替换另一数组值
# 参数1：参数文件
# 参数2：模板文件
function replace_array_in_file() {
    local i=0
    local j
    local IFS=","
    local opt_file_name=${1}
    local template_file_name=${2}
    while read line
    do
        ((i++))
        if [[ $i == 1 ]]; then
            read_line_to_array "${line}" "title"
        else
            read_line_to_array "${line}" "optname"
            cp ${template_file_name} ${template_file_name}.tmp
            for ((j=0;j<${#title[@]};j++))
            do
                if [[ ! -z ${suffix} && ${title[${j}]} == "${suffix}" ]]; then
                    if [[ -z ${output_dir_name} ]]; then
                        output_file_name="${optname[${j}]}"
                    else
                        if [[ ! -d ${output_dir_name} ]]; then
                            mkdir -p ${output_dir_name}
                        fi
                        output_file_name=${output_dir_name}/${optname[${j}]}
                    fi
                    if [[ -z ${suffix_index} ]]; then
                        output_file_name="${output_file_name}.out"
                    else
                        output_file_name="${output_file_name}.${suffix_index}"
                    fi
                    sed "s/%${title[${j}]}%/${optname[${j}]}/g" -i ${template_file_name}.tmp
                else
                    sed "s/%${title[${j}]}%/${optname[${j}]}/g" -i ${template_file_name}.tmp
                fi
                if [[ ! -z ${auto_config} ]]; then
                    if [[ ${title[${j}]} == ${Remote_Host_Key} ]]; then
                        echo "${optname[${j}]}" >> /tmp/host.tmp
                    fi
                    if [[ ${title[${j}]} == ${Remote_User_Key} ]]; then
                        echo "${optname[${j}]}" >> /tmp/user.tmp
                    fi
                    if [[ ${title[${j}]} == ${Remote_Password_Key} ]]; then
                        echo "${optname[${j}]}" >> /tmp/password.tmp
                    fi
                    if [[ ${title[${j}]} == ${Remote_Enable_Password_Key} ]]; then
                        echo "${optname[${j}]}" >> /tmp/enable_password.tmp
                    fi
                    if [[ ${title[${j}]} == ${Remote_Port_Key} ]]; then
                        echo "${optname[${j}]}" >> /tmp/port.tmp
                    fi
                    if [[ ${title[${j}]} == ${Hardware_Type_Key} ]]; then
                        echo "${optname[${j}]}" >> /tmp/hardware_type.tmp
                    fi
                    if [[ ${title[${j}]} == ${Remote_Mode_Key} ]]; then
                        echo "${optname[${j}]}" >> /tmp/mode.tmp
                    fi
                fi
            done
            if [[ -z ${output_file_name} ]]; then
                cat ${template_file_name}.tmp
            elif [[ -f ${output_file_name} ]]; then
                if [[ $i == 2 ]]; then
                    if [[ -z ${disable_rewrite} ]]; then
                        rm -f ${output_file_name}
                    fi
                fi
                cat ${template_file_name}.tmp >> ${output_file_name}
            else
                cat ${template_file_name}.tmp >> ${output_file_name}
            fi
            if [[ "${auto_config}" == "1" ]]; then
                mv ${template_file_name}.tmp /tmp/config.tmp
                run_auto_config
            else
                rm -f ${template_file_name}.tmp
            fi
        fi
        if [[ ! -z ${nline} && $i == ${nline} ]]; then
            break
        fi
    done < ${opt_file_name}
}
run_ruijie_auto_config() {
    local line
    cp ${The_Script_Dir}/expect/ruijie.exp /tmp/ruijie.exp
    while read line
    do
        echo "expect \"*#\" { send \"${line}\\r\" }" >> /tmp/ruijie.exp
    done < /tmp/config.tmp
    echo "expect \"*#\" { send \"end\\r\" }" >> /tmp/ruijie.exp
    echo "expect \"*#\" { send \"write\\r\" }" >> /tmp/ruijie.exp
    echo "expect \"*#\" { send \"exit\\r\" }" >> /tmp/ruijie.exp
    echo "expect eof" >> /tmp/ruijie.exp
    echo "exit" >> /tmp/ruijie.exp
    chmod +x /tmp/ruijie.exp
    /tmp/ruijie.exp ${remote_mode} ${remote_host} ${remote_user} ${remote_port} ${remote_enable_password} ${remote_host}> /dev/null 2>&1
    rm -f /tmp/ruijie.exp
}
run_huawei_auto_config(){
    local line
    cp ${The_Script_Dir}/expect/huawei.exp /tmp/huawei.exp
    while read line
    do
        echo "expect \"[*]\" { send \"${line}\\r\" }" >> /tmp/huawei.exp
    done < /tmp/config.tmp
    echo "expect \"[*]\" { send \"quit\\r\" }" >> /tmp/huawei.exp
    echo "expect \"<*>\" { send \"save\\r\" }" >> /tmp/huawei.exp
    echo "expect \"*[Y/N]*\" { send \"y\\r\" }" >> /tmp/huawei.exp
    echo "expect \"<*>\" { send \"\\r\" }" >> /tmp/huawei.exp
    echo "expect \"*[Y/N]*\" { send \"y\\r\" }" >> /tmp/huawei.exp
    echo "expect eof" >> /tmp/huawei.exp
    echo "exit" >> /tmp/huawei.exp
    chmod +x /tmp/huawei.exp
    /tmp/huawei.exp ${remote_mode} ${remote_host} ${remote_user} ${remote_port} ${remote_host}> /dev/null 2>&1
    rm -f /tmp/huawei.exp
}
function run_auto_config() {
    local line
    local IFS=","
    paste -d "," /tmp/host.tmp /tmp/user.tmp /tmp/password.tmp /tmp/enable_password.tmp /tmp/port.tmp /tmp/hardware_type.tmp /tmp/mode.tmp > /tmp/tag.tmp
    rm -f /tmp/host.tmp /tmp/user.tmp /tmp/password.tmp /tmp/enable_password.tmp /tmp/port.tmp /tmp/hardware_type.tmp /tmp/mode.tmp
    while read line
    do
        remote_host=`echo ${line} | cut -d "," -f 1`
        remote_user=`echo ${line} | cut -d "," -f 2`
        remote_password=`echo ${line} | cut -d "," -f 3`
        remote_enable_password=`echo ${line} | cut -d "," -f 4`
        remote_port=`echo ${line} | cut -d "," -f 5`
        hardware_type=`echo ${line} | cut -d "," -f 6`
        remote_mode=`echo ${line} | cut -d "," -f 7`
        if [[ ${remote_mode,,} == "ssh" && -z ${remote_port} ]]; then
            remote_port=22
        elif [[ ${remote_mode,,} == "telnet" && ${remote_port} ]]; then
            remote_port=23
        fi
        if [[ -z ${remote_enable_password} ]]; then
            remote_enable_password=${remote_password}
        fi
        if [[ ${hardware_type,,} == "ruijie" ]]; then
            run_ruijie_auto_config
        elif [[ ${hardware_type,,} == "huawei" ]]; then
            run_huawei_auto_config
        fi
    done < /tmp/tag.tmp
    rm -f /tmp/tag.tmp
}
function check_opt_file() {
    opt_file_name=${1}
    local i=0
    local j
    local IFS=","
    # 检查文件是否存在
    if [[ -z ${opt_file_name} ]]; then
        echo "缺少参数文件"
        echo "请使用-o参数指定参数文件"
        exit 1
    elif [[ ! -f ${opt_file_name} ]]; then
        echo "文件不存在：${opt_file_name}"
        exit 1
    fi
    # 获取文件后缀名
    local file_suffix=${opt_file_name##*.}
    # 获取文件名
    local file_name=${opt_file_name%.*}
    # 若文件后缀名为xlsx，则转换为csv
    if [[ ${file_suffix,,} == xlsx ]]; then
            transform_xlsx_to_csv ${opt_file_name} ${file_name}.csv
            opt_file_name="${file_name}.csv"
            isxlsx=1
    elif [[ ${file_suffix,,} == csv ]]; then
        unset isxlsx
    else
        echo "不被支持的文件，请检查文件"
        exit 1
    fi
    while read line
    do
        i=$(($i+1))
        if [[ $i -eq 1 ]]; then
            read_line_to_array "${line}" "title"
        else
            read_line_to_array "${line}" "optname"
            for ((j=0;j<${#title[@]};j++))
            do
                if [[ -z ${optname[${j}]} ]]; then
                    echo "文件${opt_file_name}第${i}行，第${j}列为空，请检查"
                    exit 1
                fi
            done
        fi
    done < ${opt_file_name}
    replace_array_in_file ${opt_file_name} ${template_file_name}
    if [[ $isxlsx == 1 ]]; then
        rm -f ${opt_file_name}
    fi
}
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
function check_temp_file() {
    local temp_file_name=${1}
    # 检查文件是否存在
    if [[ -z ${temp_file_name} ]]; then
        echo "缺少模板文件"
        echo "请使用-t参数指定模板文件"
        exit 1
    elif [[ ! -f ${temp_file_name} ]]; then
        echo "文件不存在：${temp_file_name}"
        echo "缺少模板文件"
        echo "请使用-t参数指定模板文件"
        exit 1
    fi
}
function check_expect() {
    if ! type -p expect &>/dev/null; then
        echo "第一次执行缺少expect，开始安装，可能需要输入密码"
        #检测操作系统
        if [[ -f /etc/redhat-release ]]; then
            sudo yum install -y expect
        elif [[ -f /etc/debian_version ]]; then
            sudo apt-get install -y expect
        else
            echo "不支持的操作系统"
            exit 1
        fi
}
function display_help() {
    echo "用法: $0 [参数]"
    echo "  -h, --help                 输出帮助信息"
    echo "  -o, --opt-file             指定参数文件（可支持xlsx，csv格式的文件）"
    echo "  -t, --template-file        指定模板文件"
    echo "  -O, --output-file          指定输出文件（不指定路径默认在当前目录下输出./config.out）"
    echo "  -d, --output-dir           指定输出文件所在目录（不指定路径默认在当前目录下输出，仅在使用-s参数时有效）"
    echo "  -D, --disable-rewrite      如果输出文件已存在，则直接追加不覆盖"
    echo "  -s, --suffix               指定输出文件名称从参数文件中某列获取，默认为file_name列"
    echo "  -l, --line                 指定仅处理参数文件中的前几行（从1开始）"
    echo "  --sheet-name               指定xlsx文件中的sheet名称，默认为第一个sheet"
    echo "  --sheet-index              指定xlsx文件中的sheet索引（从0开始），默认为第一个sheet"
    echo "  --suffix-index             指定输出文件名称后缀，必须与-s参数配合使用，默认为out"
    echo "  --auto-config              自动进行远程批量配置"
    echo "  --debug                    调试模式"
    exit 0
}
function parse_opt_equal_sign() {
    if [[ "$1" == *=* ]]; then
        echo ${1#*=}
        return 1 
     else
        echo "$2"
        return 0
    fi
}
# 处理传参
function parse_cmd_line() {
    if [[ $# -eq 0 ]]; then
        display_help
    fi
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help|-\?|--\? |"")
                display_help
                ;;
            -o|--opt-file|-o=*|--opt-file=*)
                opt_file_name="$(parse_opt_equal_sign "$1" "$2")"
                [[ $? -eq 0 ]] && shift
                ;;
            -t|--template-file|-t=*|--template-file=*)
                template_file_name="$(parse_opt_equal_sign "$1" "$2")"
                [[ $? -eq 0 ]] && shift
                ;;
            -O|--output-file|-O=*|--output-file=*)
                if [[ -z ${2} || ${2} == -* ]]; then
                    output_file_name="./config.out"
                else
                    output_file_name="$(parse_opt_equal_sign "$1" "$2")"
                    [[ $? -eq 0 ]] && shift
                fi
                ;;
            -d|--output-dir|-d=*|--output-dir=*)
                if [[ -z ${2} || ${2} == -* ]]; then
                    output_dir_name="./"
                else
                    output_dir_name="$(parse_opt_equal_sign "$1" "$2")"
                    [[ $? -eq 0 ]] && shift
                fi
                ;;  
            -s|--suffix|-s=*|--suffix=*)
                if [[ -z ${2} || ${2} == -* ]]; then
                    suffix="file_name"
                else
                    suffix="$(parse_opt_equal_sign "$1" "$2")"
                    [[ $? -eq 0 ]] && shift
                fi
                ;;
            --suffix-index|--suffix-index=*)
                if [[ -z ${2} || ${2} == -* ]]; then
                    suffix_index="out"
                else
                    suffix_index="$(parse_opt_equal_sign "$1" "$2")"
                    [[ $? -eq 0 ]] && shift
                fi
                ;;
            -l|--line|-l=*|--line=*)
                if [[ -z ${2} || ${2} == -* ]]; then
                    unset nline
                else
                    nline="$(parse_opt_equal_sign "$1" "$2")"
                    [[ $? -eq 0 ]] && shift
                fi
                ;;
            --sheet-name|--sheet-name=*)
                if [[ -z ${2} || ${2} == -* ]]; then
                    sheet_name="Sheet1"
                else
                    sheet_name="$(parse_opt_equal_sign "$1" "$2")"
                    [[ $? -eq 0 ]] && shift
                fi
                ;;
            --sheet-index|--sheet-index=*)
                if [[ -z ${2} || ${2} == -* ]]; then
                    sheet_index=0
                else
                    sheet_index="$(parse_opt_equal_sign "$1" "$2")"
                    if [[ ! $sheet_index =~ ^[0-9]+$ ]]; then
                        echo "sheet_index必须为数字"
                        exit 1
                    fi
                    [[ $? -eq 0 ]] && shift
                fi
                ;;
            --debug)
                # 过滤掉debug参数
                opt=("${The_Script_Opts[@]/--debug}")
                bash -x ${The_Script_Dir}/${The_Script_Name} "${The_Script_Opts[@]/--debug}"
                exit 0
                ;;
            -D|--disable-rewrite)
                disable_rewrite=1
                ;;
            -f|--format|-f=*|--format=*)
                format="$(parse_opt_equal_sign "$1" "$2")"
                [[ $? -eq 0 ]] && shift
                ;;
            --auto-config)
                auto_config=1
                ;;
            *)
                echo "错误，未定义的命令 $1"
                display_help
                exit 1
                ;;
        esac
        shift
    done
}

parse_cmd_line $@
check_temp_file ${template_file_name}
check_opt_file ${opt_file_name}
exit 0