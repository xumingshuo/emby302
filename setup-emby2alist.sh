#!/bin/bash

###########################################
# emby2Alist 自动化配置脚本
# 适用于已配置 Emby、Alist、rclone 的环境
###########################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

log_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 打印标题
print_header() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  emby2Alist 自动化配置脚本 - 115网盘专用版${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════${NC}"
    echo ""
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 未安装，请先安装后再运行此脚本"
        exit 1
    fi
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        log_warning "端口 $port 已被占用"
        return 1
    fi
    return 0
}

# 验证 URL 格式
validate_url() {
    local url=$1
    if [[ $url =~ ^https?://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]] || \
       [[ $url =~ ^https?://[a-zA-Z0-9.-]+:[0-9]+$ ]] || \
       [[ $url =~ ^https?://localhost:[0-9]+$ ]]; then
        return 0
    fi
    return 1
}

# 测试服务连通性
test_service() {
    local service_name=$1
    local url=$2
    log_info "测试 $service_name 连通性: $url"

    if curl -s --connect-timeout 5 "$url" > /dev/null; then
        log_success "$service_name 连接成功"
        return 0
    else
        log_error "$service_name 连接失败，请检查地址和服务状态"
        return 1
    fi
}

# 获取 Docker 网络 IP
get_docker_host_ip() {
    # 尝试获取 docker0 网桥的网关 IP
    local docker_ip=$(ip addr show docker0 2>/dev/null | grep -Po 'inet \K[\d.]+' | head -1)
    if [ -z "$docker_ip" ]; then
        docker_ip="172.17.0.1"
    fi
    echo "$docker_ip"
}

# 交互式收集配置信息
collect_config() {
    echo ""
    log_info "开始收集配置信息..."
    echo ""

    # 1. 安装路径
    echo -e "${YELLOW}1. 配置文件安装路径${NC}"
    read -p "请输入安装路径 [默认: ~/emby2alist-config]: " INSTALL_PATH
    INSTALL_PATH=${INSTALL_PATH:-"$HOME/emby2alist-config"}
    INSTALL_PATH=$(eval echo "$INSTALL_PATH")  # 展开波浪号
    log_info "安装路径: $INSTALL_PATH"
    echo ""

    # 2. Emby 配置
    echo -e "${YELLOW}2. Emby 服务器配置${NC}"

    # 检测是否使用 Docker
    read -p "Emby 是否运行在 Docker 中? [Y/n]: " emby_docker
    emby_docker=${emby_docker:-Y}

    if [[ $emby_docker =~ ^[Yy]$ ]]; then
        local docker_ip=$(get_docker_host_ip)
        EMBY_HOST="http://${docker_ip}:8096"
        log_info "检测到 Docker 网桥 IP: $docker_ip"
    else
        EMBY_HOST="http://127.0.0.1:8096"
    fi

    read -p "Emby 服务器地址 [默认: $EMBY_HOST]: " input_emby
    EMBY_HOST=${input_emby:-$EMBY_HOST}

    # 验证 Emby 连通性
    if ! test_service "Emby" "$EMBY_HOST"; then
        read -p "无法连接到 Emby，是否继续? [y/N]: " continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    read -p "Emby API Key (在 Emby 后台 -> 高级 -> API 密钥获取): " EMBY_API_KEY
    while [ -z "$EMBY_API_KEY" ]; do
        log_error "API Key 不能为空"
        read -p "Emby API Key: " EMBY_API_KEY
    done
    echo ""

    # 3. Alist 配置
    echo -e "${YELLOW}3. Alist 服务器配置${NC}"

    if [[ $emby_docker =~ ^[Yy]$ ]]; then
        local docker_ip=$(get_docker_host_ip)
        ALIST_ADDR="http://${docker_ip}:5244"
    else
        ALIST_ADDR="http://127.0.0.1:5244"
    fi

    read -p "Alist 内网地址 [默认: $ALIST_ADDR]: " input_alist
    ALIST_ADDR=${input_alist:-$ALIST_ADDR}

    # 验证 Alist 连通性
    if ! test_service "Alist" "$ALIST_ADDR"; then
        read -p "无法连接到 Alist，是否继续? [y/N]: " continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    read -p "Alist Token (在 Alist 后台 -> 设置 -> 其他中查看): " ALIST_TOKEN
    while [ -z "$ALIST_TOKEN" ]; do
        log_error "Alist Token 不能为空"
        read -p "Alist Token: " ALIST_TOKEN
    done

    read -p "Alist 公网地址 (如无公网访问需求, 直接回车使用内网地址): " ALIST_PUBLIC_ADDR
    ALIST_PUBLIC_ADDR=${ALIST_PUBLIC_ADDR:-$ALIST_ADDR}

    read -p "Alist 是否启用了签名(sign)功能? [y/N]: " alist_sign
    ALIST_SIGN_ENABLE="false"
    ALIST_SIGN_EXPIRE="12"
    if [[ $alist_sign =~ ^[Yy]$ ]]; then
        ALIST_SIGN_ENABLE="true"
        read -p "直链有效期(小时) [默认: 12]: " expire_time
        ALIST_SIGN_EXPIRE=${expire_time:-12}
    fi
    echo ""

    # 4. rclone 挂载路径
    echo -e "${YELLOW}4. rclone 挂载路径配置${NC}"
    log_info "这是最重要的配置项，请仔细核对"
    echo ""
    log_info "提示: 打开 Emby 任意视频详情页，滚动到底部查看完整路径"
    log_info "示例: /mnt/115/Movies/电影.mkv"
    echo ""

    read -p "Emby 媒体库路径示例: " EMBY_MEDIA_PATH
    while [ -z "$EMBY_MEDIA_PATH" ]; do
        log_error "路径不能为空"
        read -p "Emby 媒体库路径示例: " EMBY_MEDIA_PATH
    done

    echo ""
    log_info "现在检查 Alist 中相同文件的路径"
    log_info "登录 Alist 后台，找到该文件，记录其在 Alist 中显示的路径"
    echo ""
    read -p "Alist 中该文件的路径: " ALIST_FILE_PATH

    # 自动计算 mediaMountPath
    log_info "正在计算 mediaMountPath..."

    # 简化计算逻辑：找出 Emby 路径中多出来的前缀
    MEDIA_MOUNT_PATH=$(echo "$EMBY_MEDIA_PATH" | sed "s|$ALIST_FILE_PATH||")

    if [ -z "$MEDIA_MOUNT_PATH" ]; then
        # 如果完全匹配，尝试提取目录前缀
        MEDIA_MOUNT_PATH=$(dirname "$EMBY_MEDIA_PATH")
    fi

    echo ""
    log_info "计算结果: mediaMountPath = $MEDIA_MOUNT_PATH"
    read -p "是否正确? 如需修改请输入新值，否则直接回车: " custom_mount
    if [ -n "$custom_mount" ]; then
        MEDIA_MOUNT_PATH="$custom_mount"
    fi
    echo ""

    # 5. 网络模式
    echo -e "${YELLOW}5. Docker 网络模式${NC}"
    echo "host: 使用宿主机网络(推荐，简单直接)"
    echo "bridge: 使用桥接网络(需要端口映射)"
    read -p "选择网络模式 [host/bridge，默认: host]: " NETWORK_MODE
    NETWORK_MODE=${NETWORK_MODE:-host}

    PROXY_PORT="8091"
    if [ "$NETWORK_MODE" = "bridge" ]; then
        read -p "emby2Alist 代理端口 [默认: 8091]: " input_port
        PROXY_PORT=${input_port:-8091}

        if ! check_port $PROXY_PORT; then
            read -p "端口被占用，是否继续? [y/N]: " continue_port
            if [[ ! $continue_port =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
    echo ""

    # 6. 115 Web 播放配置
    echo -e "${YELLOW}6. 115 Web 播放配置${NC}"
    echo "115 网盘存在跨域限制，Web 端播放需要特殊处理"
    read -p "是否需要 Web 端播放 115 视频? [y/N]: " web_play
    ENABLE_WEB_PROXY="false"
    if [[ $web_play =~ ^[Yy]$ ]]; then
        ENABLE_WEB_PROXY="true"
        log_info "将启用 Web 端代理模式"
    else
        log_info "Web 端将禁用 115 直链，推荐使用客户端播放"
    fi
    echo ""
}

# 生成配置文件
generate_configs() {
    log_info "生成配置文件..."

    # 创建目录结构
    mkdir -p "$INSTALL_PATH"/{conf.d/config,log,embyCache}

    # 1. 生成 constant.js
    cat > "$INSTALL_PATH/conf.d/constant.js" << EOF
// emby2Alist 配置文件
// 由自动化脚本生成于 $(date '+%Y-%m-%d %H:%M:%S')

import commonConfig from "./config/constant-common.js";
import mountConfig from "./config/constant-mount.js";
import proConfig from "./config/constant-pro.js";
import symlinkConfig from "./config/constant-symlink.js";
import strmConfig from "./config/constant-strm.js";
import transcodeConfig from "./config/constant-transcode.js";
import extConfig from "./config/constant-ext.js";
import nginxConfig from "./config/constant-nginx.js";

// ============ 核心配置 ============

// Emby/Jellyfin 服务器地址
const embyHost = "${EMBY_HOST}";

// Emby/Jellyfin API Key
const embyApiKey = "${EMBY_API_KEY}";

// rclone 挂载目录
// 这是 rclone 多出来的挂载路径，用于匹配 Emby 路径和 Alist 路径的差异
const mediaMountPath = ["${MEDIA_MOUNT_PATH}"];

// ============ 导出配置 ============

// for js_set
function getEmbyHost(r) {
  return embyHost;
}
function getTranscodeEnable(r) {
  return transcodeConfig.transcodeConfig.enable;
}
function getTranscodeType(r) {
  return transcodeConfig.transcodeConfig.type;
}
function getImageCachePolicy(r) {
  return extConfig.imageCachePolicy;
}

function getUsersItemsLatestFilterEnable(r) {
  return extConfig.itemHiddenRule.some(rule => !rule[2] || rule[2] == 0 || rule[2] == 4);
}

export default {
  embyHost,
  embyApiKey,
  mediaMountPath,
  strHead: commonConfig.strHead,

  alistAddr: mountConfig.alistAddr,
  alistToken: mountConfig.alistToken,
  alistSignEnable: mountConfig.alistSignEnable,
  alistSignExpireTime: mountConfig.alistSignExpireTime,
  alistPublicAddr: mountConfig.alistPublicAddr,
  clientSelfAlistRule: mountConfig.clientSelfAlistRule,
  redirectCheckEnable: mountConfig.redirectCheckEnable,
  fallbackUseOriginal: mountConfig.fallbackUseOriginal,

  redirectConfig: proConfig.redirectConfig,
  routeCacheConfig: proConfig.routeCacheConfig,
  routeRule: proConfig.routeRule,
  mediaPathMapping: proConfig.mediaPathMapping,
  alistRawUrlMapping: proConfig.alistRawUrlMapping,

  symlinkRule: symlinkConfig.symlinkRule,
  redirectStrmLastLinkRule: strmConfig.redirectStrmLastLinkRule,
  transcodeConfig: transcodeConfig.transcodeConfig,

  embyNotificationsAdmin: extConfig.embyNotificationsAdmin,
  embyRedirectSendMessage: extConfig.embyRedirectSendMessage,
  itemHiddenRule: extConfig.itemHiddenRule,
  streamConfig: extConfig.streamConfig,
  searchConfig: extConfig.searchConfig,
  webCookie115: extConfig.webCookie115,
  directHlsConfig: extConfig.directHlsConfig,
  playbackInfoConfig: extConfig.playbackInfoConfig,

  getEmbyHost,
  getTranscodeEnable,
  getTranscodeType,
  getImageCachePolicy,
  getUsersItemsLatestFilterEnable,

  nginxConfig: nginxConfig.nginxConfig,
  getDisableDocs: nginxConfig.getDisableDocs,
}
EOF

    # 2. 生成 constant-mount.js
    mkdir -p "$INSTALL_PATH/conf.d/config"
    cat > "$INSTALL_PATH/conf.d/config/constant-mount.js" << EOF
// Alist 挂载配置
// 由自动化脚本生成于 $(date '+%Y-%m-%d %H:%M:%S')

import commonConfig from "./constant-common.js";

const strHead = commonConfig.strHead;

// ============ Alist 配置 ============

// Alist 服务器地址(内网)
const alistAddr = "${ALIST_ADDR}";

// Alist Token
const alistToken = "${ALIST_TOKEN}";

// Alist 签名功能
const alistSignEnable = ${ALIST_SIGN_ENABLE};

// 直链有效期(小时)
const alistSignExpireTime = ${ALIST_SIGN_EXPIRE};

// Alist 公网地址
const alistPublicAddr = "${ALIST_PUBLIC_ADDR}";

// 客户端自行请求 Alist 直链的规则
// 115 网盘特殊配置: Infuse 等客户端使用公网地址
const clientSelfAlistRule = [
  [2, strHead["115"], alistPublicAddr],
];

// 重定向前检测链接有效性
const redirectCheckEnable = false;

// 查询失败后回源处理
const fallbackUseOriginal = true;

export default {
  alistAddr,
  alistToken,
  alistSignEnable,
  alistSignExpireTime,
  alistPublicAddr,
  clientSelfAlistRule,
  redirectCheckEnable,
  fallbackUseOriginal,
}
EOF

    # 3. 生成 constant-pro.js (115 Web 播放支持)
    local web_route_rule=""
    if [ "$ENABLE_WEB_PROXY" = "false" ]; then
        web_route_rule='  // 禁用 Emby Web 端的 115 直链，避免跨域问题
  ["proxy", "115-web", "r.args.X-Emby-Client", 0, "Emby Web"],
  ["proxy", "115-web", "filePath", 0, "'${MEDIA_MOUNT_PATH}'"],'
    fi

    cat > "$INSTALL_PATH/conf.d/config/constant-pro.js" << EOF
// 高级路由配置
// 由自动化脚本生成于 $(date '+%Y-%m-%d %H:%M:%S')

import commonConfig from "./constant-common.js";

const strHead = commonConfig.strHead;
const ruleRef = commonConfig.ruleRef;

// ============ 路由配置 ============

// 重定向配置
const redirectConfig = {
  enable: true,
  enableRule: [],
  disableRule: [],
};

// 路由缓存配置
const routeCacheConfig = {
  enable: true,
  enableL2: false,
  keyExpression: "r.uri:r.args.MediaSourceId:r.args.X-Emby-Device-Id",
};

// 路由规则
const routeRule = [
${web_route_rule}
];

// 路径映射
// 如果 Emby 路径和 Alist 路径不匹配，在这里配置映射规则
const mediaPathMapping = [
  // 示例: [0, 0, "/media/115", "/115"],
];

// Alist 原始链接映射
const alistRawUrlMapping = [
  // 示例: [0, 0, "http:", "https:"],
];

export default {
  redirectConfig,
  routeCacheConfig,
  routeRule,
  mediaPathMapping,
  alistRawUrlMapping,
}
EOF

    log_success "配置文件生成完成"
}

# 下载必要的文件
download_files() {
    log_info "下载必要的配置文件..."

    local base_url="https://raw.githubusercontent.com/bpking1/embyExternalUrl/main/emby2Alist/nginx"
    local files=(
        "nginx.conf"
        "conf.d/emby.conf"
        "conf.d/emby.js"
        "conf.d/config/constant-common.js"
        "conf.d/config/constant-symlink.js"
        "conf.d/config/constant-strm.js"
        "conf.d/config/constant-transcode.js"
        "conf.d/config/constant-ext.js"
        "conf.d/config/constant-nginx.js"
    )

    for file in "${files[@]}"; do
        local dir=$(dirname "$file")
        mkdir -p "$INSTALL_PATH/$dir"

        log_info "下载 $file..."
        if curl -fsSL "$base_url/$file" -o "$INSTALL_PATH/$file" 2>/dev/null; then
            log_success "✓ $file"
        else
            log_warning "✗ $file (使用本地版本或稍后手动下载)"
        fi
    done

    # 下载其他必要目录
    log_info "下载辅助文件..."
    mkdir -p "$INSTALL_PATH/conf.d"/{common,api,modules,includes}

    # 这些文件较多，建议使用完整的 tar.gz 包
    log_info "建议下载完整配置包以确保所有文件完整"
    echo ""
}

# 生成 docker compose.yml
generate_docker_compose() {
    log_info "生成 docker compose.yml..."

    local network_config
    local ports_config=""

    if [ "$NETWORK_MODE" = "host" ]; then
        network_config="network_mode: host"
    else
        network_config="#network_mode: bridge"
        ports_config="    ports:
      - ${PROXY_PORT}:8091"
    fi

    cat > "$INSTALL_PATH/docker compose.yml" << EOF
version: '3.5'
services:
  nginx-emby:
    image: nginx:1.27.1
    container_name: nginx-emby
    ${network_config}
${ports_config}
    volumes:
      - ${INSTALL_PATH}/nginx.conf:/etc/nginx/nginx.conf:ro
      - ${INSTALL_PATH}/conf.d:/etc/nginx/conf.d:ro
      - ${INSTALL_PATH}/embyCache:/var/cache/nginx/emby
      - ${INSTALL_PATH}/log:/var/log/nginx
    restart: always
    environment:
      - TZ=Asia/Shanghai

# 如果需要同时部署 Alist，取消下面的注释
#  alist:
#    image: xhofe/alist:latest
#    container_name: alist
#    ports:
#      - 5244:5244
#    volumes:
#      - ${INSTALL_PATH}/alist:/opt/alist/data
#    restart: always
EOF

    log_success "docker compose.yml 生成完成"
}

# 生成环境变量配置模板
generate_env_template() {
    cat > "$INSTALL_PATH/.env.example" << EOF
# emby2Alist 环境变量配置模板
# 复制此文件为 .env 并填写实际值

# Emby 配置
EMBY_HOST=${EMBY_HOST}
EMBY_API_KEY=your_emby_api_key_here

# Alist 配置
ALIST_ADDR=${ALIST_ADDR}
ALIST_TOKEN=your_alist_token_here
ALIST_PUBLIC_ADDR=${ALIST_PUBLIC_ADDR}

# 挂载路径
MEDIA_MOUNT_PATH=${MEDIA_MOUNT_PATH}

# Docker 配置
NETWORK_MODE=${NETWORK_MODE}
PROXY_PORT=${PROXY_PORT}

# 生成时间
GENERATED_AT=$(date '+%Y-%m-%d %H:%M:%S')
EOF
}

# 显示配置摘要
show_summary() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}            配置完成！${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}配置摘要:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "安装路径: $INSTALL_PATH"
    echo "Emby 地址: $EMBY_HOST"
    echo "Alist 地址: $ALIST_ADDR"
    echo "挂载路径: $MEDIA_MOUNT_PATH"
    echo "网络模式: $NETWORK_MODE"
    if [ "$NETWORK_MODE" = "bridge" ]; then
        echo "代理端口: $PROXY_PORT"
    fi
    echo "Web 播放: $([ "$ENABLE_WEB_PROXY" = "true" ] && echo "已启用(代理模式)" || echo "已禁用")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 显示下一步操作
show_next_steps() {
    echo -e "${YELLOW}下一步操作:${NC}"
    echo ""
    echo "1. 检查配置文件 (可选):"
    echo "   cd $INSTALL_PATH"
    echo "   cat conf.d/constant.js"
    echo ""
    echo "2. 启动服务:"
    echo "   cd $INSTALL_PATH"
    echo "   docker compose up -d"
    echo ""
    echo "3. 查看日志:"
    echo "   docker logs -f nginx-emby"
    echo ""
    echo "4. 访问测试:"
    if [ "$NETWORK_MODE" = "host" ]; then
        echo "   http://你的服务器IP:8091"
    else
        echo "   http://你的服务器IP:$PROXY_PORT"
    fi
    echo ""
    echo "5. 查看详细日志:"
    echo "   docker logs nginx-emby 2>&1 | grep 'js:'"
    echo ""
    echo -e "${GREEN}完整文档: $INSTALL_PATH/../docs/SETUP_GUIDE_115.md${NC}"
    echo ""
}

# 主函数
main() {
    print_header

    # 检查依赖
    log_info "检查系统依赖..."
    check_command docker
    check_command docker compose
    check_command curl
    log_success "依赖检查通过"
    echo ""

    # 收集配置
    collect_config

    # 确认配置
    echo ""
    echo -e "${YELLOW}请确认以下配置信息:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "安装路径: $INSTALL_PATH"
    echo "Emby: $EMBY_HOST"
    echo "Alist: $ALIST_ADDR"
    echo "挂载路径: $MEDIA_MOUNT_PATH"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    read -p "确认无误? [Y/n]: " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        log_warning "已取消配置"
        exit 0
    fi

    # 生成配置
    generate_configs

    # 下载文件
    read -p "是否下载官方配置文件? [Y/n]: " download
    if [[ ! $download =~ ^[Nn]$ ]]; then
        download_files
    else
        log_warning "跳过下载，请手动复制必要文件到 $INSTALL_PATH"
    fi

    # 生成 docker compose
    generate_docker_compose

    # 生成环境变量模板
    generate_env_template

    # 设置权限
    chmod -R 755 "$INSTALL_PATH/conf.d"
    chmod 777 "$INSTALL_PATH/embyCache"

    # 显示摘要
    show_summary

    # 询问是否立即启动
    echo ""
    read -p "是否立即启动服务? [Y/n]: " start_now
    if [[ ! $start_now =~ ^[Nn]$ ]]; then
        log_info "启动服务..."
        cd "$INSTALL_PATH"
        if docker compose up -d; then
            log_success "服务启动成功!"
            echo ""
            sleep 2
            docker logs nginx-emby --tail 20
        else
            log_error "服务启动失败，请检查日志"
        fi
    fi

    echo ""
    show_next_steps

    log_success "脚本执行完成！"
}

# 运行主函数
main "$@"
