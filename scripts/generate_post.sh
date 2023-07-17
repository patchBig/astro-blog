#!/bin/bash

# 获取当前时间
current_time=$(date -u +"%Y-%m-%dT%H:%M:%S")

# 提示用户输入信息
read -p "请输入作者名（默认为 Nical Yang）：" author
author=${author:-"Nical Yang"}

read -p "请输入标题：" title

read -p "请输入文件路径（不包含 ./src/content/blog 前缀）：" post_slug

read -p "请输入标签，以空格分隔：" tags
tags_array=($tags)

read -p "请输入描述：" description

# 构建完整的文件路径
file_path="./src/content/blog/$post_slug.md"

# 创建文件夹路径
directory=$(dirname "$file_path")
mkdir -p "$directory"

# 构建文件内容
content="---
author: $author
pubDatetime: $current_time
title: $title
postSlug: $post_slug
featured: true
tags:
"

for tag in "${tags_array[@]}"; do
  content+="  - $tag"$'\n'
done

content+="description: $description
---

"

# 写入文件
echo "$content" > "$file_path"

echo "已成功生成文件：$file_path"

