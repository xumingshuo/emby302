# README 更新建议

以下内容建议添加到主 README.md 文件中:

---

## 🚀 快速开始 - 115网盘用户

如果你已经配置好 Emby、Alist 和 rclone(115)，可以使用我们的自动化脚本快速部署：

### 一键配置脚本

```bash
# 运行自动化配置脚本
chmod +x setup-emby2alist.sh
./setup-emby2alist.sh
```

脚本会自动：
- ✅ 收集必要的配置信息
- ✅ 生成配置文件
- ✅ 验证服务连通性
- ✅ 创建 Docker 容器
- ✅ 启动 emby2Alist 服务

### 完整文档

- 📖 [115网盘完整配置指南](./docs/SETUP_GUIDE_115.md)
- ⚡ [5分钟快速开始](./docs/QUICKSTART.md)
- 🔧 [配置模板](./config-example-115.env)

### 文件说明

```
emby2Alist/
├── setup-emby2alist.sh          # 自动化配置脚本
├── config-example-115.env       # 环境变量配置模板
└── docs/
    ├── SETUP_GUIDE_115.md       # 完整配置指南
    └── QUICKSTART.md            # 快速开始文档
```

---

## 建议添加的位置

在主 README.md 的 "Deployment Methods" 章节之前添加上述内容，使 115 用户能快速找到自动化配置方案。

## 其他建议

1. 在 emby2Alist/README.md 中添加指向这些新文档的链接
2. 在 FAQ.md 中添加指向 SETUP_GUIDE_115.md 的常见问题链接
3. 考虑为其他云盘（阿里云盘、OneDrive）创建类似的快速配置脚本
