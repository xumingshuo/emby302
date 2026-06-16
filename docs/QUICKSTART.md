# emby2Alist 快速开始 - 115网盘

> 5分钟快速配置 emby2Alist，实现 Emby 视频 302 重定向到 Alist 直链

---

## 🎯 使用场景

你已经配置好了:
- ✅ Emby Server (可访问)
- ✅ Alist (已添加 115 网盘)
- ✅ rclone (已挂载 115 到本地)

现在想让 Emby 播放时直接使用 115 直链，减少服务器流量和转码压力。

---

## ⚡ 一键部署

### 方式一: 自动化脚本 (推荐)

```bash
# 1. 克隆或下载本仓库
git clone https://github.com/bpking1/embyExternalUrl.git
cd embyExternalUrl

# 2. 运行配置脚本
chmod +x setup-emby2alist.sh
./setup-emby2alist.sh

# 3. 根据提示输入配置信息
# - Emby 地址和 API Key
# - Alist 地址和 Token
# - rclone 挂载路径

# 4. 脚本自动完成配置并启动服务
```

**脚本会自动:**
- ✅ 检测系统环境
- ✅ 验证服务连通性
- ✅ 生成配置文件
- ✅ 创建 docker-compose.yml
- ✅ 启动服务

---

### 方式二: 手动配置

如果自动化脚本不适用，参考完整文档:

📖 [完整配置指南](./docs/SETUP_GUIDE_115.md)

---

## 📋 准备工作

在运行脚本前，准备以下信息:

### 1. Emby API Key

```bash
# 获取方式:
1. 登录 Emby 管理后台
2. 设置 -> 高级 -> API 密钥
3. 新建 API 密钥，名称: emby2Alist
4. 复制生成的 Key
```

### 2. Alist Token

```bash
# 获取方式:
1. 登录 Alist 管理后台
2. 设置 -> 其他 -> Token
3. 复制显示的 Token
```

### 3. rclone 挂载路径

```bash
# 查看挂载点:
df -h | grep rclone

# 或
mount | grep rclone

# 示例输出:
# 115remote: on /mnt/115 type fuse.rclone
```

### 4. Emby 媒体路径

```bash
# 在 Emby 中:
1. 打开任意视频详情页
2. 滚动到底部
3. 记录 "路径" 字段的完整路径

# 示例: /mnt/115/Movies/电影名称 (2024)/movie.mkv
```

---

## ✅ 验证安装

### 1. 检查服务状态

```bash
docker ps | grep nginx-emby
```

应该看到容器正在运行。

### 2. 访问代理地址

```bash
# 浏览器访问:
http://你的服务器IP:8091
```

应该能看到 Emby 登录页面。

### 3. 测试视频播放

1. 登录 Emby (通过 8091 端口)
2. 播放一个视频
3. 按 F12 打开开发者工具
4. 切换到 Network 标签
5. 找到视频请求

**成功标志:**
- 状态码: `302 Found`
- Location 响应头包含 115 或 Alist 地址

### 4. 查看日志

```bash
# 实时日志
docker logs -f nginx-emby

# 查看重定向日志
docker logs nginx-emby 2>&1 | grep -E "redirect|alist"
```

**成功日志示例:**
```
js: redirect to alist direct link: http://xxx.115.com/xxx
js: alist fs response success
```

---

## 🔍 故障排查

### 问题 1: 无法连接到 Emby/Alist

```bash
# 检查服务是否运行
curl http://172.17.0.1:8096  # Emby
curl http://172.17.0.1:5244  # Alist

# 如果无法连接，检查 Docker 网络
docker network inspect bridge
```

**解决方法:**
- 确认服务正在运行
- 如果是 Docker 容器，使用 `172.17.0.1` 而不是 `localhost`
- 或使用 `host` 网络模式

### 问题 2: 视频返回 500 错误

```bash
# 查看详细日志
docker logs nginx-emby 2>&1 | tail -50
```

**常见原因:**
- Alist Token 错误
- 挂载路径配置错误
- 文件在 Alist 中不存在

**解决方法:**
```bash
# 1. 验证 Token
curl -H "Authorization: your_token" \
  http://172.17.0.1:5244/api/fs/list \
  -d '{"path":"/"}'

# 2. 检查配置文件
cat ~/emby2alist-config/conf.d/constant.js

# 3. 修改后重启
docker-compose restart
```

### 问题 3: Web 端播放 115 视频跨域错误

**现象:** 控制台显示 CORS 错误

**解决方法 A - 使用代理模式:**

编辑 `conf.d/config/constant-pro.js`:

```javascript
const routeRule = [
  ["proxy", "115-web", "r.args.X-Emby-Client", 0, "Emby Web"],
  ["proxy", "115-web", "filePath", 0, "/mnt/115"],
];
```

**解决方法 B - 使用客户端 (推荐):**

使用 Emby 官方客户端或第三方播放器:
- Android/iOS: Emby App
- Windows/macOS: Emby Theater
- 第三方: Infuse, VidHub, Fileball

---

## 📊 性能优化

### 1. 禁用 Emby 转码

```
Emby 后台 -> 用户 -> 播放设置:
- 互联网质量: 最大
- 取消勾选 "允许视频转码"
- 取消勾选 "允许音频转码"
```

### 2. 启用缓存

缓存已在配置中启用，可调整缓存大小:

```bash
# 检查缓存目录大小
du -sh ~/emby2alist-config/embyCache

# 如果需要清理缓存
rm -rf ~/emby2alist-config/embyCache/*
```

### 3. 优化网络

```bash
# 如果是高带宽环境，可以禁用重定向检测
# 编辑 conf.d/config/constant-mount.js:
const redirectCheckEnable = false;
```

---

## 🔄 更新配置

修改配置文件后:

```bash
# 方法 1: 热重载 (不中断服务)
docker exec nginx-emby nginx -s reload

# 方法 2: 重启容器
cd ~/emby2alist-config
docker-compose restart

# 方法 3: 完全重建
docker-compose down
docker-compose up -d
```

---

## 📱 客户端配置

配置完成后，在各个客户端中使用新地址:

```
旧地址: http://192.168.1.100:8096
新地址: http://192.168.1.100:8091
```

**推荐配置:**
- 播放质量: 原始/最高
- 允许直播流: 是
- 允许直接播放: 是

---

## 🔐 安全建议

1. **不要暴露 Alist 端口到公网**
   ```bash
   # 防火墙只开放 8091
   ufw allow 8091/tcp
   # 不要开放 5244
   ```

2. **使用反向代理 + HTTPS**
   ```bash
   # 推荐使用 Nginx Proxy Manager 或 Caddy
   # 配置 SSL 证书和域名
   ```

3. **定期更新 Token**
   ```bash
   # 在 Emby 和 Alist 后台定期更换 Token
   # 更新配置文件后重启服务
   ```

---

## 📚 进阶功能

### 1. 路径映射

如果 Emby 路径和 Alist 路径结构不同:

参考: [完整配置指南 - 路径映射章节](./docs/SETUP_GUIDE_115.md#高级配置)

### 2. 多网盘支持

同时支持 115、阿里云盘、OneDrive 等:

```javascript
const mediaMountPath = [
  "/mnt/115",
  "/mnt/aliyun",
  "/mnt/onedrive"
];
```

### 3. 转码支持

保留转码能力同时支持直链:

参考官方文档的转码配置章节

---

## 🆘 获取帮助

- 📖 完整文档: [SETUP_GUIDE_115.md](./docs/SETUP_GUIDE_115.md)
- 🐛 问题反馈: [GitHub Issues](https://github.com/bpking1/embyExternalUrl/issues)
- 💬 常见问题: [FAQ.md](./FAQ.md)
- 📝 配置示例: [config-example-115.env](./config-example-115.env)

---

## ✨ 快速命令参考

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 查看日志
docker logs -f nginx-emby

# 重载配置
docker exec nginx-emby nginx -s reload

# 进入容器
docker exec -it nginx-emby bash

# 清理缓存
rm -rf ~/emby2alist-config/embyCache/*

# 重启服务
docker-compose restart

# 查看配置
cat ~/emby2alist-config/conf.d/constant.js
```

---

**祝你使用愉快！🎉**
