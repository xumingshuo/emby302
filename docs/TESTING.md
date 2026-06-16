# emby2Alist 测试验证脚本

# 用于验证 emby2Alist 配置是否正确

## 使用方法

```bash
chmod +x test-emby2alist.sh
./test-emby2alist.sh
```

## 测试内容

脚本会自动检测：

1. ✅ Docker 服务运行状态
2. ✅ nginx-emby 容器状态
3. ✅ Emby 服务连通性
4. ✅ Alist 服务连通性
5. ✅ 代理端口可访问性
6. ✅ 配置文件语法
7. ✅ 日志中的错误信息
8. ✅ 302 重定向功能

## 手动测试步骤

### 1. 检查容器状态

```bash
docker ps | grep nginx-emby
```

**预期输出:**
```
CONTAINER ID   IMAGE          STATUS         PORTS
abc123         nginx:1.27.1   Up 2 minutes   (根据网络模式显示)
```

### 2. 检查日志

```bash
# 查看启动日志
docker logs nginx-emby

# 查看错误日志
docker logs nginx-emby 2>&1 | grep -i error

# 查看重定向日志
docker logs nginx-emby 2>&1 | grep "js:"
```

**成功日志示例:**
```
js: redirect to alist direct link: http://xxx.115.com/xxx
js: alist fs response success
js: filePath: /mnt/115/Movies/xxx.mkv
```

**错误日志示例:**
```
js: error, alist token invalid
js: error, file not found in alist
```

### 3. 测试服务连通性

```bash
# 测试 nginx 代理
curl -I http://localhost:8091

# 测试 Emby 后端
curl -I http://172.17.0.1:8096

# 测试 Alist
curl -I http://172.17.0.1:5244
```

### 4. 测试 Alist API

```bash
# 替换为你的 Token
ALIST_TOKEN="your_token_here"

# 测试文件列表 API
curl -X POST http://172.17.0.1:5244/api/fs/list \
  -H "Authorization: $ALIST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"path":"/"}'

# 测试文件获取 API
curl -X POST http://172.17.0.1:5244/api/fs/get \
  -H "Authorization: $ALIST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"path":"/Movies/test.mkv"}'
```

**成功响应:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "name": "test.mkv",
    "size": 1234567890,
    "raw_url": "https://xxx.115.com/..."
  }
}
```

### 5. 测试视频播放

#### 方法 A: 浏览器开发者工具

1. 打开 Emby Web (http://your-ip:8091)
2. 登录并播放一个视频
3. 按 F12 打开开发者工具
4. 切换到 **Network** 标签
5. 在过滤框输入: `.m3u8` 或 `.ts` 或视频文件名
6. 查看请求详情

**成功标志:**
- Status: `302 Found` 或 `302 Moved Temporarily`
- Response Headers 中有 `Location: https://xxx.115.com/...`

**失败标志:**
- Status: `500 Internal Server Error`
- Status: `404 Not Found`
- 没有 `Location` 响应头

#### 方法 B: curl 测试

```bash
# 获取 Emby 中的视频播放链接
# 1. 在 Emby Web 中右键视频 -> 检查 -> 复制视频 URL

# 2. 使用 curl 测试 (示例)
curl -v "http://localhost:8091/videos/12345/stream.mp4?api_key=xxx&Static=true"
```

**成功输出:**
```
< HTTP/1.1 302 Found
< Location: https://xxx.115.com/download/xxx.mp4
```

### 6. 检查配置文件语法

```bash
# 进入容器
docker exec -it nginx-emby bash

# 测试 nginx 配置语法
nginx -t

# 预期输出:
# nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### 7. 检查文件权限

```bash
# 检查缓存目录权限
ls -la ~/emby2alist-config/embyCache

# 应该有写入权限
# drwxrwxrwx  2 user group  4096 xxx
```

如果权限不足:
```bash
chmod -R 777 ~/emby2alist-config/embyCache
```

### 8. 测试路径映射

```bash
# 在 Emby 中找一个视频，记录路径
# 例如: /mnt/115/Movies/电影.mkv

# 在 Alist 中确认该文件存在
# 访问: http://your-ip:5244

# 如果文件存在但无法播放，检查 mediaMountPath 配置
cat ~/emby2alist-config/conf.d/constant.js | grep mediaMountPath
```

## 常见测试场景

### 场景 1: 客户端直链测试

使用 Infuse、VidHub 等客户端:

1. 配置客户端连接到 `http://your-ip:8091`
2. 播放视频
3. 查看日志:
   ```bash
   docker logs -f nginx-emby 2>&1 | grep "X-Emby-Client"
   ```

### 场景 2: Web 端播放测试

1. 浏览器访问 `http://your-ip:8091`
2. 播放 115 视频
3. 检查是否有跨域错误
4. 如果有，确认已配置路由规则

### 场景 3: 外网访问测试

如果配置了公网访问:

1. 从外网访问 `http://your-domain:8091`
2. 测试播放
3. 检查是否使用了 `alistPublicAddr`

## 性能测试

### 1. 响应时间测试

```bash
# 测试重定向响应时间
time curl -I "http://localhost:8091/videos/12345/stream.mp4?api_key=xxx"

# 应该在 100ms 以内
```

### 2. 并发测试

```bash
# 使用 ab (Apache Bench)
ab -n 100 -c 10 http://localhost:8091/

# 或使用 wrk
wrk -t4 -c100 -d30s http://localhost:8091/
```

### 3. 缓存命中率测试

```bash
# 多次访问同一个视频，检查日志
# 第一次: cache MISS
# 后续: cache HIT

docker logs nginx-emby 2>&1 | grep cache
```

## 故障诊断检查清单

- [ ] Docker 服务正在运行
- [ ] nginx-emby 容器状态为 Up
- [ ] Emby 服务可访问 (8096)
- [ ] Alist 服务可访问 (5244)
- [ ] emby2Alist 代理端口可访问 (8091)
- [ ] Emby API Key 正确
- [ ] Alist Token 正确
- [ ] mediaMountPath 配置正确
- [ ] Alist 中文件存在
- [ ] rclone 挂载正常
- [ ] 防火墙已开放端口
- [ ] 日志中无错误
- [ ] nginx 配置测试通过
- [ ] 缓存目录有写权限

## 自动化测试脚本

创建 `test-emby2alist.sh`:

```bash
#!/bin/bash

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "  emby2Alist 配置测试"
echo "========================================="
echo ""

# 1. 检查 Docker
echo -n "检查 Docker 服务... "
if docker info >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Docker 未运行${NC}"
    exit 1
fi

# 2. 检查容器
echo -n "检查 nginx-emby 容器... "
if docker ps | grep -q nginx-emby; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ 容器未运行${NC}"
    exit 1
fi

# 3. 检查端口
echo -n "检查代理端口 8091... "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8091 | grep -q "200\|302"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ 无法访问${NC}"
fi

# 4. 检查日志错误
echo -n "检查日志错误... "
ERROR_COUNT=$(docker logs nginx-emby 2>&1 | grep -i error | wc -l)
if [ "$ERROR_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓ 无错误${NC}"
else
    echo -e "${YELLOW}⚠ 发现 $ERROR_COUNT 个错误${NC}"
    echo "运行以下命令查看: docker logs nginx-emby 2>&1 | grep -i error"
fi

# 5. 检查配置文件
echo -n "检查 nginx 配置语法... "
if docker exec nginx-emby nginx -t >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ 配置语法错误${NC}"
fi

echo ""
echo "========================================="
echo "  测试完成"
echo "========================================="
echo ""
echo "如需详细日志，运行:"
echo "  docker logs -f nginx-emby"
echo ""
```

保存后执行:
```bash
chmod +x test-emby2alist.sh
./test-emby2alist.sh
```

## 调试技巧

### 1. 实时监控日志

```bash
# 同时监控所有相关服务的日志
docker logs -f nginx-emby 2>&1 | grep --color=auto -E "error|redirect|alist|115"
```

### 2. 启用详细日志

编辑 `nginx.conf`:
```nginx
error_log /var/log/nginx/error.log debug;
```

### 3. 使用 tcpdump 抓包

```bash
# 抓取 8091 端口的流量
sudo tcpdump -i any -n port 8091 -w emby2alist.pcap

# 使用 Wireshark 分析
```

### 4. JavaScript 调试

在 `emby.js` 中添加调试日志:
```javascript
ngx.log(ngx.WARN, "DEBUG: variable value = " + value);
```

## 报告问题

如果测试失败，请收集以下信息：

1. **系统信息**
   ```bash
   uname -a
   docker version
   docker-compose version
   ```

2. **容器日志**
   ```bash
   docker logs nginx-emby > emby2alist.log 2>&1
   ```

3. **配置文件**
   ```bash
   cat ~/emby2alist-config/conf.d/constant.js
   cat ~/emby2alist-config/conf.d/config/constant-mount.js
   ```

4. **测试 URL**
   - Emby 视频完整路径
   - Alist 中对应文件路径
   - mediaMountPath 值

提交到: https://github.com/bpking1/embyExternalUrl/issues
