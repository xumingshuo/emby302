# emby2Alist 115网盘快速配置包

这是一个针对 **115网盘** 用户的 emby2Alist 快速配置解决方案，包含自动化脚本、完整文档和配置模板。

## 🎯 适用场景

你已经配置好了：
- ✅ **Emby Server** - 媒体服务器正在运行
- ✅ **Alist** - 已添加并配置了115网盘存储
- ✅ **rclone** - 已挂载115网盘到本地目录

现在想要：
- 🚀 让 Emby 播放时使用 115 直链（302重定向）
- 💰 节省服务器带宽和流量成本
- ⚡ 减少服务器转码压力
- 📱 客户端直连云端，播放更流畅

---

## 📦 文件说明

```
.
├── setup-emby2alist.sh          # 🔧 自动化配置脚本（推荐）
├── config-example-115.env       # 📝 环境变量配置模板
└── docs/
    ├── QUICKSTART.md            # ⚡ 5分钟快速开始
    ├── SETUP_GUIDE_115.md       # 📖 完整配置指南
    ├── TESTING.md               # ✅ 测试验证文档
    └── README_UPDATE.md         # 📋 主README更新建议
```

---

## 🚀 快速开始

### 方式一：自动化脚本（推荐新手）

```bash
# 1. 给脚本执行权限
chmod +x setup-emby2alist.sh

# 2. 运行脚本
./setup-emby2alist.sh

# 3. 按照提示输入配置信息
#    - Emby 地址和 API Key
#    - Alist 地址和 Token  
#    - rclone 挂载路径

# 4. 脚本会自动完成配置并启动服务
```

**脚本功能：**
- ✅ 自动检测系统环境
- ✅ 验证 Emby/Alist 连通性
- ✅ 智能计算 mediaMountPath
- ✅ 生成所有配置文件
- ✅ 创建 Docker Compose 配置
- ✅ 启动服务并显示状态

### 方式二：查看文档手动配置

如果你想了解每个配置项的含义，或者需要高级定制：

📖 [完整配置指南](./docs/SETUP_GUIDE_115.md)

---

## 📋 准备工作

运行脚本前，请准备以下信息：

### 1️⃣ Emby API Key

```
获取路径：Emby 后台 → 设置 → 高级 → API 密钥 → 新建
```

### 2️⃣ Alist Token

```
获取路径：Alist 后台 → 设置 → 其他 → Token
```

### 3️⃣ rclone 挂载路径

```bash
# 查看挂载点
df -h | grep rclone
# 或
mount | grep rclone

# 示例输出：
# 115remote: on /mnt/115 type fuse.rclone
```

### 4️⃣ Emby 媒体路径示例

```
打开 Emby 任意视频详情页，滚动到底部，记录"路径"字段

示例：/mnt/115/Movies/电影名称 (2024)/movie.mkv
```

---

## ✅ 验证配置

配置完成后，按以下步骤验证：

### 1. 检查服务状态

```bash
docker ps | grep nginx-emby
```

### 2. 访问测试

浏览器访问：`http://你的IP:8091`

应该能看到 Emby 登录界面。

### 3. 播放测试

1. 登录 Emby（通过8091端口）
2. 播放一个视频
3. 按 F12 → Network 标签
4. 查找视频请求

**成功标志：**
- 状态码：`302 Found`
- `Location` 响应头包含 115 地址

### 4. 查看日志

```bash
docker logs -f nginx-emby 2>&1 | grep "js:"
```

**成功日志示例：**
```
js: redirect to alist direct link: https://xxx.115.com/xxx
js: alist fs response success
```

详细测试步骤：📋 [测试验证文档](./docs/TESTING.md)

---

## 🔧 常见问题

### 问题1：无法连接到 Emby/Alist

**原因：** Docker 网络配置问题

**解决：**
```bash
# 检查服务是否运行
curl http://172.17.0.1:8096  # Emby
curl http://172.17.0.1:5244  # Alist

# 如果 Docker 使用 host 网络，改用
curl http://127.0.0.1:8096
curl http://127.0.0.1:5244
```

### 问题2：视频返回 500 错误

**原因：** Alist Token 错误或路径配置错误

**解决：**
```bash
# 验证 Token
curl -H "Authorization: your_token" \
  http://172.17.0.1:5244/api/fs/list \
  -d '{"path":"/"}'

# 检查配置
cat ~/emby2alist-config/conf.d/constant.js

# 修改后重启
docker-compose restart
```

### 问题3：Web端播放115视频跨域错误

**原因：** 115不支持跨域，浏览器限制

**解决方案A（推荐）：** 使用客户端
- Emby Android/iOS App
- Infuse
- VidHub
- Fileball

**解决方案B：** 配置代理模式
编辑 `conf.d/config/constant-pro.js`:
```javascript
const routeRule = [
  ["proxy", "115-web", "r.args.X-Emby-Client", 0, "Emby Web"],
  ["proxy", "115-web", "filePath", 0, "/mnt/115"],
];
```

更多问题：📖 [完整配置指南 - 常见问题章节](./docs/SETUP_GUIDE_115.md#常见问题)

---

## 📚 文档导航

| 文档 | 说明 | 适合人群 |
|------|------|----------|
| [QUICKSTART.md](./docs/QUICKSTART.md) | 5分钟快速开始 | 想快速上手的用户 |
| [SETUP_GUIDE_115.md](./docs/SETUP_GUIDE_115.md) | 完整配置指南 | 需要详细了解的用户 |
| [TESTING.md](./docs/TESTING.md) | 测试验证步骤 | 遇到问题需要排查 |
| [config-example-115.env](./config-example-115.env) | 配置参数说明 | 需要自定义配置 |

---

## 🎓 工作原理

```
┌─────────┐      ①请求视频        ┌──────────────┐
│ Emby客户端│ ──────────────────▶ │ nginx-emby   │
│         │                      │ (emby2Alist) │
└─────────┘                      └──────────────┘
                                        │
                    ②查询Alist获取直链    │
                    ┌─────────────────────┘
                    ▼
              ┌──────────┐
              │  Alist   │
              │  (5244)  │
              └──────────┘
                    │
        ③返回115直链URL  │
        ┌───────────────┘
        ▼
┌──────────────┐
│ nginx-emby   │ ──────────────────▶ ┌─────────┐
│ (302重定向)  │   ④302重定向到115    │ Emby客户端│
└──────────────┘                     └─────────┘
                                          │
                    ┌─────────────────────┘
                    ▼
              ┌──────────┐
              │ 115 CDN  │ ⑤客户端直连115播放
              │  直链服务 │
              └──────────┘
```

**关键点：**
1. 客户端请求仍然发往 Emby 地址（端口8091）
2. nginx 拦截视频请求，查询 Alist 获取 115 直链
3. 返回 302 重定向，客户端直接从 115 CDN 下载
4. 服务器不中转流量，节省带宽

---

## 🔄 更新配置

修改配置文件后：

```bash
# 方法1：热重载（推荐，不中断服务）
docker exec nginx-emby nginx -s reload

# 方法2：重启容器
cd ~/emby2alist-config
docker-compose restart

# 方法3：完全重建
docker-compose down && docker-compose up -d
```

---

## 🛡️ 安全建议

1. **不要暴露 Alist 端口到公网**
   ```bash
   # 防火墙只开放 8091
   ufw allow 8091/tcp
   ```

2. **定期更新 Token**
   - 在 Emby 和 Alist 后台定期更换
   - 更新配置文件后重启服务

3. **使用 HTTPS**
   - 配置反向代理（Nginx/Caddy）
   - 申请 SSL 证书

---

## 📊 性能优化

### 禁用 Emby 转码

```
Emby 后台 → 用户 → 播放设置：
- 互联网质量：最大
- 取消勾选"允许视频转码"
- 取消勾选"允许音频转码"
```

### 清理缓存

```bash
# 如果缓存占用过大
rm -rf ~/emby2alist-config/embyCache/*
```

---

## 🆘 获取帮助

- 📖 [官方项目](https://github.com/bpking1/embyExternalUrl)
- 🐛 [提交问题](https://github.com/bpking1/embyExternalUrl/issues)
- 💬 [常见问题FAQ](https://github.com/bpking1/embyExternalUrl/blob/main/FAQ.md)

---

## 📝 快速命令参考

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 查看日志
docker logs -f nginx-emby

# 查看重定向日志
docker logs nginx-emby 2>&1 | grep "redirect"

# 重载配置
docker exec nginx-emby nginx -s reload

# 重启服务
docker-compose restart

# 测试配置
docker exec nginx-emby nginx -t

# 清理缓存
rm -rf ~/emby2alist-config/embyCache/*
```

---

## ✨ 特性

- 🚀 **一键配置** - 自动化脚本，无需手动编辑
- 🔍 **智能检测** - 自动验证服务连通性
- 📝 **详细文档** - 完整的配置指南和故障排查
- 🐳 **Docker 部署** - 容器化，易于管理
- 🔧 **灵活配置** - 支持多种部署场景
- 🌐 **115 优化** - 专门针对 115 网盘优化

---

## 📄 许可

本项目基于原 [embyExternalUrl](https://github.com/bpking1/embyExternalUrl) 项目创建。

---

**祝你配置顺利！🎉**

有问题请查看文档或提交 Issue。
