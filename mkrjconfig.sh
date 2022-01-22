#!/usr/bin/env bash
# 该脚本用于生成交换机配置文件
The_Script_Name="$(basename `readlink -f $0`)"
The_Script_Dir="$(dirname `readlink -f $0`)"
The_Script_Opts="$@"
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
                    if [[ -z ${output_file_dir} ]]; then
                        output_file_name="${optname[${j}]}"
                    else
                        if [[ ! -d ${output_file_dir} ]]; then
                            mkdir -p ${output_file_dir}
                        fi
                        output_file_name=${output_file_dir}/${optname[${j}]}
                    fi
                    if [[ -z ${suffix_index} ]]; then
                        output_file_name="${output_file_name}.out"
                    else
                        output_file_name="${output_file_name}.${suffix_index}"
                    fi
                else
                    sed "s/%${title[${j}]}%/${optname[${j}]}/g" -i ${template_file_name}.tmp
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
            rm -f ${template_file_name}.tmp
        fi
    done < ${opt_file_name}
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
            # 检测是否有执行权限
            if [[ ! -x ${The_Script_Dir}/xlsx2csv ]]; then
                sudo chmod +x ${The_Script_Dir}/xlsx2csv
            fi
            eval "${The_Script_Dir}/xlsx2csv ${opt_file_name} -o ${file_name}.csv"
            opt_file_name="${file_name}.csv"
    elif [[ ${file_suffix,,} == csv ]]; then
        return 0
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
function display_help() {
    echo "用法: $0 [参数]"
    echo "  -h, --help                 输出帮助信息"
    echo "  -o, --opt-file             指定参数文件（可支持xlsx，csv格式的文件）"
    echo "  -t, --template-file        指定模板文件"
    echo "  -O, --output-file          指定输出文件（不指定路径默认在当前目录下输出./config.out）"
    echo "  -d, --output-dir           指定输出文件所在目录（不指定路径默认在当前目录下输出，仅在使用-s参数时有效）"
    echo "  -D, --disable-rewrite      如果输出文件已存在，则直接追加不覆盖"
    echo "  -s, --suffix               指定输出文件名称从参数文件中某列获取（默认为file_name列）"
    echo "  --suffix-index             指定输出文件名称后缀，必须与-s参数配合使用（默认为.out）"
    #echo "  -f, --format               以给定格式输出配置文件名称"
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