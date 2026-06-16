# emby2Alist 快速配置指南 - 115网盘专用版

> 本指南适用于已经配置好 Emby、Alist 和 rclone(115) 的环境

---

## 📋 前置条件检查

在开始之前，请确认以下服务已经正常运行：

- [x] **Emby Server** 已安装并可访问（默认端口 8096）
- [x] **Alist** 已安装并配置了 115 网盘（默认端口 5244）
- [x] **rclone** 已配置并挂载了 115 网盘到本地目录
- [x] **Docker** 和 **docker-compose** 已安装
- [x] Emby 媒体库已通过 rclone 挂载路径入库

---

## 🔍 需要收集的信息

在配置前，请准备好以下信息：

### 1. Emby 相关信息

#### 获取 Emby API Key
1. 登录 Emby 后台管理界面
2. 进入 `设置` → `高级` → `API 密钥`
3. 点击 `新建 API 密钥`，名称填写 `emby2Alist`
4. 复制生成的 API Key

**示例:** `f839390f50a648fd92108bc11ca6730a`

#### 确认 Emby 访问地址
- 如果 Emby 和 emby2Alist 在同一台机器：
  - Docker bridge 网络: `http://172.17.0.1:8096`
  - Docker host 网络: `http://127.0.0.1:8096`
  - 宿主机 IP: `http://192.168.1.100:8096` (替换为实际 IP)

### 2. Alist 相关信息

#### 获取 Alist Token
1. 登录 Alist 管理后台
2. 进入 `设置` → `其他` → `Token`
3. 复制显示的 Token

**示例:** `alist-1a2b3c4d5e6f7g8h9i0j`

#### 确认 Alist 访问地址
- 内网地址（emby2Alist 访问用）: `http://172.17.0.1:5244`
- 公网地址（可选，用于某些客户端）: `http://yourdomain.com:5244`

#### 检查 Alist 中的 115 配置
1. 登录 Alist 后台
2. 进入 `存储` → 查看 115 网盘的挂载路径
3. 记录挂载路径名称（例如：`/115` 或 `/mnt/115`）

### 3. rclone 挂载信息

#### 确认挂载路径
运行命令查看挂载点：
```bash
df -h | grep rclone
# 或
mount | grep rclone
```

**示例输出:**
```
115remote: on /mnt/115 type fuse.rclone
```

记录挂载路径：`/mnt/115`

#### 确认 Emby 媒体库路径
1. 打开 Emby 控制台
2. 进入任意视频详情页
3. 滚动到最底部，查看 `路径` 字段
4. 记录完整路径

**示例:** `/mnt/115/Movies/电影名称 (2024)/movie.mkv`

### 4. 计算 mediaMountPath

对比 Alist 根路径和 Emby 媒体路径：

- **Emby 路径**: `/mnt/115/Movies/电影.mkv`
- **Alist 根路径**: `/` (在 Alist 中显示为 `115/Movies/电影.mkv`)
- **mediaMountPath**: `/mnt/115` (rclone 多出来的挂载目录)

或者：

- **Emby 路径**: `/media/115/Movies/电影.mkv`
- **Alist 根路径**: `/` (在 Alist 中显示为 `Movies/电影.mkv`)
- **mediaMountPath**: `/media/115`

**规则:** mediaMountPath = Emby 路径前缀 - Alist 显示路径

---

## 🚀 快速部署（推荐使用自动化脚本）

### 方式一：自动化脚本部署

```bash
# 1. 下载配置包
cd ~
wget https://github.com/bpking1/embyExternalUrl/releases/download/v0.0.1/emby2Alist.tar.gz
tar -xzvf emby2Alist.tar.gz
cd emby2Alist

# 2. 运行自动化配置脚本
curl -fsSL https://raw.githubusercontent.com/bpking1/embyExternalUrl/main/setup-emby2alist.sh | bash
# 或者如果你克隆了仓库
bash setup-emby2alist.sh

# 3. 按照提示输入配置信息
# 脚本会自动生成配置文件并启动服务
```

### 方式二：手动配置部署

#### 步骤 1: 下载配置文件

```bash
cd ~
wget https://github.com/bpking1/embyExternalUrl/releases/download/v0.0.1/emby2Alist.tar.gz
mkdir -p ~/emby2Alist
tar -xzvf emby2Alist.tar.gz -C ~/emby2Alist
cd ~/emby2Alist
```

#### 步骤 2: 创建必要目录

```bash
# 根据你的实际路径修改 /path/to
mkdir -p /path/to/nginx-emby/log
mkdir -p /path/to/nginx-emby/embyCache
mkdir -p /path/to/nginx-emby/config

# 复制配置文件
cp -r ~/emby2Alist/nginx/* /path/to/nginx-emby/config/
```

#### 步骤 3: 修改核心配置文件

编辑 `/path/to/nginx-emby/config/conf.d/constant.js`:

```javascript
// 必填项,根据实际情况修改下面的设置

// Emby 服务器地址
// Docker bridge 网络使用 172.17.0.1，host 网络使用 127.0.0.1
const embyHost = "http://172.17.0.1:8096";

// Emby API Key (在 Emby 后台 -> 高级 -> API 密钥中获取)
const embyApiKey = "your_emby_api_key_here";

// rclone 挂载目录
// 例如 rclone 挂载到 /mnt/115，这里就填 ["/mnt/115"]
// 如果有多个挂载点: ["/mnt/115", "/mnt/aliyun"]
const mediaMountPath = ["/mnt/115"];
```

#### 步骤 4: 修改 Alist 配置

编辑 `/path/to/nginx-emby/config/conf.d/config/constant-mount.js`:

```javascript
// Alist 服务器地址 (内网访问)
const alistAddr = "http://172.17.0.1:5244";

// Alist Token (在 Alist 后台 -> 设置 -> 其他 -> Token)
const alistToken = "your_alist_token_here";

// Alist 是否启用了签名(sign)
// 一般保持 false，除非你在 Alist 中启用了签名功能
const alistSignEnable = false;

// 直链过期时间(小时)，需与 Alist 设置一致
const alistSignExpireTime = 12;

// Alist 公网地址 (可选，某些客户端可能需要)
// 如果没有公网域名，保持与 alistAddr 相同
const alistPublicAddr = "http://172.17.0.1:5244";
```

#### 步骤 5: 115 特定配置 (解决 Web 播放跨域问题)

对于 115 网盘，需要配置路由规则以处理跨域问题。

编辑 `/path/to/nginx-emby/config/conf.d/config/constant-pro.js`:

```javascript
// 路由规则 - 115 Web 端跨域问题解决方案
// 如果只用客户端播放，可以不配置
const routeRule = [
  // 禁用 Emby Web 端的 115 直链，改用 nginx 代理
  // 这样可以避免浏览器跨域限制
  ["proxy", "115-web", "r.args.X-Emby-Client", 0, "Emby Web"],
  ["proxy", "115-web", "filePath", 0, "/mnt/115"],
];

// 路由缓存配置
const routeCacheConfig = {
  enable: true,
  enableL2: false,
  keyExpression: "r.uri:r.args.MediaSourceId:r.args.X-Emby-Device-Id",
};
```

**说明:**
- 这个配置会让 Emby Web 端的 115 视频通过 nginx 代理而不是直链
- 客户端(Android/iOS/TV)不受影响，仍然使用直链
- 如果你不使用 Web 端播放，可以跳过此步骤

#### 步骤 6: 修改 Docker Compose 配置

编辑 `~/emby2Alist/docker/docker-compose.yml`:

```yaml
version: '3.5'
services:
    service.nginx-emby:
      image: nginx:1.27.1
      container_name: nginx-emby
      # 使用 host 网络模式(推荐)
      network_mode: host
      
      # 如果需要使用 bridge 网络，注释掉上面的 network_mode，取消下面的注释
      # ports:
      #   - 8091:8091  # emby2Alist 代理端口
      
      volumes:
        # 修改为你的实际路径
        - /path/to/nginx-emby/config/nginx.conf:/etc/nginx/nginx.conf
        - /path/to/nginx-emby/config/conf.d:/etc/nginx/conf.d
        - /path/to/nginx-emby/embyCache:/var/cache/nginx/emby
        - /path/to/nginx-emby/log:/var/log/nginx
      restart: always
```

**重要提示:**
- 将 `/path/to/nginx-emby` 替换为你的实际路径
- 如果遇到权限问题，运行: `chmod -R 777 /path/to/nginx-emby/embyCache`

#### 步骤 7: 启动服务

```bash
cd ~/emby2Alist/docker
docker-compose up -d
```

查看日志确认启动成功:
```bash
docker logs -f nginx-emby
```

---

## ✅ 验证配置

### 1. 检查服务状态

```bash
# 检查容器运行状态
docker ps | grep nginx-emby

# 检查日志是否有错误
docker logs nginx-emby 2>&1 | grep -i error
```

### 2. 测试直链访问

使用浏览器访问:
```
http://你的服务器IP:8091
```

应该能看到 Emby 的登录页面。

### 3. 测试视频播放

1. 登录 Emby (通过 8091 端口)
2. 选择一个视频开始播放
3. 打开浏览器开发者工具 (F12)
4. 切换到 `Network` 标签
5. 查找视频请求，检查是否返回 `302 重定向`

**成功标志:**
- 视频请求返回 `302 Found`
- `Location` 响应头包含 Alist 或 115 的直链地址

### 4. 查看详细日志

```bash
# 实时查看日志
docker logs -f -n 50 nginx-emby 2>&1 | grep "js:"

# 查看重定向日志
docker logs nginx-emby 2>&1 | grep -E "redirect|alist|115"
```

**成功日志示例:**
```
js: redirect to alist direct link: http://xxx.115.com/xxx
js: alist fs response success
```

---

## ⚙️ 高级配置

### 1. 自定义端口

如果 8091 端口被占用，修改 `emby.conf` 中的监听端口:

编辑 `/path/to/nginx-emby/config/conf.d/emby.conf`:

```nginx
server {
    listen 8091;  # 修改为你想要的端口，如 8099
    # ...
}
```

然后重启容器:
```bash
docker-compose restart
```

### 2. 路径映射 (高级场景)

如果 Emby 路径和 Alist 路径不匹配，需要配置路径映射。

编辑 `/path/to/nginx-emby/config/conf.d/config/constant-pro.js`:

```javascript
// 场景: Emby 路径为 /media/115/Movies/xxx
//       Alist 路径为 /Movies/xxx
//       需要移除 /media/115 前缀

const mediaPathMapping = [
  [0, 0, "/media/115", ""],  // 移除前缀
];

// 场景: Emby 路径为 /mnt/115/TV/xxx
//       Alist 路径为 /电视剧/xxx
//       需要替换路径片段

const mediaPathMapping = [
  [0, 0, "/mnt/115/TV", "/电视剧"],
];
```

### 3. 客户端特定规则

让某些客户端直接获取 Alist 链接(不经过 nginx 代理):

编辑 `/path/to/nginx-emby/config/conf.d/config/constant-mount.js`:

```javascript
// Infuse 客户端对 115 使用 Alist 公网地址
const clientSelfAlistRule = [
  [2, strHead["115"], alistPublicAddr],
  // 或者指定文件路径规则
  // ["115-infuse", "filePath", 0, "/mnt/115", alistPublicAddr],
  // ["115-infuse", "r.args.X-Emby-Client", 2, "Infuse"],
];
```

### 4. 禁用转码

为了确保使用直链，建议在 Emby 中禁用转码:

1. 登录 Emby 管理后台
2. 进入 `设置` → `用户` → 选择用户
3. `播放` 标签:
   - 互联网质量: 选择 `最大`
   - 取消勾选 `允许视频转码`
   - 取消勾选 `允许音频转码`

---

## 🔧 常见问题

### 1. 视频无法播放，返回 500 错误

**可能原因:**
- Alist Token 错误
- 挂载路径配置错误
- Alist 服务未运行

**排查步骤:**
```bash
# 1. 检查 Alist 是否运行
curl http://172.17.0.1:5244

# 2. 检查 Token 是否正确
curl -H "Authorization: your_token" http://172.17.0.1:5244/api/fs/list \
  -d '{"path":"/"}'

# 3. 查看 nginx 日志
docker logs nginx-emby 2>&1 | tail -50
```

### 2. Web 端播放 115 视频提示跨域错误

**原因:** 115 不支持跨域请求，浏览器阻止。

**解决方案 A - 使用代理模式 (推荐):**

参见上文「步骤 5: 115 特定配置」，配置路由规则让 Web 端使用 nginx 代理。

**解决方案 B - 修改 Emby 前端:**

修改 Emby 的 `basehtmlplayer.js` 移除 `crossorigin` 属性:

```bash
# 进入 Emby 容器 (如果 Emby 使用 Docker)
docker exec -it emby bash

# 备份原文件
cp /app/emby/system/dashboard-ui/modules/htmlvideoplayer/basehtmlplayer.js \
   /app/emby/system/dashboard-ui/modules/htmlvideoplayer/basehtmlplayer.js.bak

# 修改文件
sed -i 's/mediaSource\.IsRemote&&"DirectPlay"===playMethod?null:"anonymous"/null/g' \
  /app/emby/system/dashboard-ui/modules/htmlvideoplayer/basehtmlplayer.js

# 清除浏览器缓存后重新访问
```

**解决方案 C - 使用客户端:**

推荐使用 Emby 官方客户端或第三方播放器(Infuse、VidHub 等)，不受跨域限制。

### 3. 客户端播放卡顿或加载慢

**可能原因:**
- 直链检测超时
- Alist 响应慢
- 网络带宽不足

**优化配置:**

编辑 `/path/to/nginx-emby/config/conf.d/config/constant-mount.js`:

```javascript
// 禁用重定向检测(加快响应速度)
const redirectCheckEnable = false;

// 查询失败时使用原始链接
const fallbackUseOriginal = true;
```

### 4. 部分视频没有走直链

**排查步骤:**

1. 确认视频路径是否在 `mediaMountPath` 范围内
2. 查看日志中是否有错误

```bash
docker logs nginx-emby 2>&1 | grep "文件名关键字"
```

3. 检查 Alist 中该文件是否存在:

```bash
curl -H "Authorization: your_token" \
  http://172.17.0.1:5244/api/fs/get \
  -d '{"path":"/Movies/xxx.mkv"}'
```

### 5. 容器启动失败，提示端口冲突

**解决方法:**

修改监听端口或关闭占用的服务:

```bash
# 查看端口占用
netstat -tlnp | grep 8091

# 方法 1: 修改 emby2Alist 端口(见「自定义端口」)
# 方法 2: 关闭占用端口的服务
```

### 6. 日志中出现 permission denied

**解决方法:**

```bash
# 给缓存目录完整权限
chmod -R 777 /path/to/nginx-emby/embyCache

# 或者使用特权模式运行容器
# 在 docker-compose.yml 中添加:
# privileged: true
```

### 7. Emby 无法识别媒体信息(无时长、无编码信息)

**原因:** Emby Server 无法访问媒体文件路径。

**解决方法:**

确保 Emby 容器能访问 rclone 挂载目录:

```bash
# 如果 Emby 是 Docker 容器
docker exec emby ls /mnt/115  # 应该能列出文件

# 如果看不到文件，需要在 Emby 容器中也挂载该目录
# 修改 Emby 的 docker-compose.yml:
volumes:
  - /mnt/115:/mnt/115:ro  # 只读挂载
```

---

## 📊 防火墙配置

如果使用防火墙，需要开放以下端口:

```bash
# CentOS/RHEL
firewall-cmd --permanent --add-port=8091/tcp
firewall-cmd --reload

# Ubuntu/Debian (ufw)
ufw allow 8091/tcp

# 或直接使用 iptables
iptables -A INPUT -p tcp --dport 8091 -j ACCEPT
```

**端口说明:**
- `8091`: emby2Alist 代理端口 (访问 Emby 的新入口)
- `8096`: Emby 原始端口 (可选，可以只开放 8091)
- `5244`: Alist 端口 (已配置)

---

## 🎯 最佳实践

### 1. 安全建议

- 不要在公网暴露 Alist 端口 (5244)
- 使用反向代理 (nginx/Caddy) 并配置 HTTPS
- 定期更新 Emby 和 Alist Token
- 限制 API Key 权限

### 2. 性能优化

- 启用 nginx 缓存 (已在配置中启用)
- 使用 SSD 存储缓存目录
- 对于多用户场景，考虑增加 `worker_connections`

### 3. 监控建议

定期检查日志:
```bash
# 每日检查错误日志
docker logs nginx-emby --since 24h 2>&1 | grep -i error

# 监控重定向成功率
docker logs nginx-emby --since 24h 2>&1 | grep "redirect" | wc -l
```

---

## 🔄 配置变更后的操作

修改配置文件后，重启服务使配置生效:

```bash
# 方法 1: 重载 nginx 配置(无停机)
docker exec nginx-emby nginx -s reload

# 方法 2: 重启容器
docker-compose restart

# 方法 3: 完全重建
docker-compose down
docker-compose up -d
```

---

## 📚 参考资源

- [emby2Alist 官方文档](https://github.com/bpking1/embyExternalUrl/blob/main/emby2Alist/README.md)
- [Alist 官方文档](https://alist.nn.ci/)
- [rclone 官方文档](https://rclone.org/)
- [常见问题 FAQ](https://github.com/bpking1/embyExternalUrl/blob/main/FAQ.md)

---

## 💡 下一步

配置完成后，建议:

1. ✅ 测试各类客户端播放 (Web/Android/iOS/TV)
2. ✅ 检查播放进度是否正常记录
3. ✅ 验证外网访问 (如果需要)
4. ✅ 配置定时备份配置文件
5. ✅ 考虑配置 HTTPS (使用 Caddy 或 acme.sh)

---

**如有问题，请查看日志并参考 FAQ 或提交 Issue。**
