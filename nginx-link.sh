#!/bin/bash
#使用前提
#1.在/volume*/web下创建部署web项目的文件夹。把打包的静态文件都在到这里面。例如 /volume1/web/www（创建的文件夹名最好和二级域名前缀相同）
#2.在/volume*/web_packages文件夹下创建nginx文件夹，并且在nginx文件夹下面再创建一个跟二级域名前缀一样的文件夹。例如/volume1/web_packages/nginx/www（这里是为了方便识别管理）
#2.5 这里不一定要放到/volume1/web_packages这个文件夹里，也可以自定义其他路径。可以在directory_user_conf这里修改路径
#3.因为引入的文件名字都是统一格式都是user.conf，所以创建user.conf文件并写入配置。然后把它放到你想修改配置的二级域名前缀文件夹内。例如/volume1/web_packages/nginx/www/user.conf

# 外部conf文件目录
directory_user_conf="/volume2/web_packages/nginx/"

# web station conf文件目录
directory_conf_d="/usr/local/etc/nginx/conf.d"

#web station文件夹
directory_web="/volume2/web/"

# 存储提取到的域名列表及其对应的 include 文件路径
declare -A domain_include_map

echo "开始扫描符合条件的文件..."

for file in $directory_conf_d/.service*; do
    # 提取域名
    domains=($(grep -Po "root\s+\"$directory_web\K[^\"]+" "$file"))
    # 提取文件夹路径，并将结果存储在 include_files 数组中
    include_files=($(grep -Po 'include\s+\K[^"]+/([^/]+)(?=\/user\.conf\*)' "$file"))

    # 如果没有找到域名，则跳过该文件
    if [ ${#domains[@]} -eq 0 ] || [ ${#domains[@]} -ne ${#include_files[@]} ]; then
        continue
    fi

    # 将域名及其对应的 include 文件路径添加到映射中
    for ((i=0; i<${#domains[@]}; i++)); do
        domain=${domains[$i]}
        include_file=${include_files[$i]}
        # 使用basename命令获取文件名并存储
        filename=$(basename "$include_file")
        domain_include_map["$domain"]="$filename"
    done
done

echo "扫描完成."

# 显示提取到的域名及其对应的 include 文件路径供用户选择
echo "找到以下域名及其对应的文件夹路径名："
index=0
for domain in "${!domain_include_map[@]}"; do
    echo "$index: $domain (${domain_include_map[$domain]})"
    ((index++))
done

# 提示用户选择域名
read -p "请选择需要添加nginx配置的对应域名 (输入对应的数字): " selected_index

# 检查用户选择的索引是否有效
if [ "$selected_index" -ge 0 ] && [ "$selected_index" -lt "${#domain_include_map[@]}" ]; then
    # 获取用户选择的域名
    selected_domain=""
    index=0
    for domain in "${!domain_include_map[@]}"; do
        if [ "$index" -eq "$selected_index" ]; then
            selected_domain="$domain"
            break
        fi
        ((index++))
    done

    echo "你选择的域名是: $selected_domain"

   # 列出目标目录所有文件夹供用户选择
    echo "列出所有文件夹："
    folder_list=("$directory_user_conf"*/)
    for ((i=0; i<${#folder_list[@]}; i++)); do
        echo "$i: ${folder_list[$i]}"
    done

    # 提示用户选择文件夹
    read -p "请选择要使用的文件夹 (输入对应的数字): " selected_folder_index

    # 检查用户选择的文件夹索引是否有效
    if [ "$selected_folder_index" -ge 0 ] && [ "$selected_folder_index" -lt "${#folder_list[@]}" ]; then
        # 获取用户选择的文件夹路径
        selected_folder="${folder_list[$selected_folder_index]}"
        echo "你选择的文件夹是: $selected_folder"

        # 获取目标文件路径
        target_file="${directory_conf_d}/${domain_include_map[$selected_domain]}"
        echo "目标文件路径是: $target_file"
        
        # 创建符号链接(与选的配置文件夹)
        ln -sf "$selected_folder" "$target_file"
        echo "已创建$target_file 链接到 $selected_folder"

        # 重启 WebStation
        #/usr/syno/bin/synopkg restart WebStation
        echo "请进入到WebStation 禁用对应域名并重新启用方可应用配置"
    else
        echo "无效的文件夹索引."
    fi
else
    echo "无效的域名索引."
fi