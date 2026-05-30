# Jotting

some useful tools!

---

## setup-zsh.sh — Zsh 环境一键配置脚本

自动在新机器上还原笔者的终端环境，兼容 **macOS** 和 **Linux**。

### 功能

| 步骤 | 内容 |
|------|------|
| 代理检测 | Linux 下自动检测本机代理 (127.0.0.1:7897) 并配置 git/curl |
| apt 镜像 | Ubuntu/Debian 自动切换清华镜像源，加速下载 |
| 安装 zsh | 系统未装则自动通过 apt/dnf/pacman 安装 |
| Oh My Zsh | 多镜像 clone（gitee → GitHub → ghproxy），下载失败自动 fallback |
| 主题 & 插件 | agnoster 主题，git / z / zsh-autosuggestions / zsh-syntax-highlighting |
| 命令行工具 | eza（彩色 ls 替代）、yazi（终端文件管理器）、trash-cli（回收站） |
| opencode | 终端 AI 编程助手，官方推荐方式安装 |
| 配置迁移 | 自动备份旧 .zshrc，迁移 bash/zsh 旧配置中的兼容内容 |

### 安装工具一览

| 命令 | 用途 |
|------|------|
| `ls` / `ll` / `lt` | eza 替代传统 ls，彩色图标 + Git 状态 + 树状图 |
| `rm` | trash-cli 接管，文件进回收站而非直接删除 |
| `y` | yazi 文件管理器，Vim 键位，q 退出自动 cd |
| `opencode` | 终端 AI 编程助手，`/connect` 连自有模型 |

### 使用方法

```bash
# 1. 确保用户有 sudo 权限（没有就加）
su - <管理员账户>
sudo usermod -aG sudo <用户名>

# 2. 退出重新登录，使 sudo 权限生效
exit

# 3. 下载脚本并执行
./setup-zsh.sh

# 4. 生效配置
#    本地终端：关闭窗口重开即可
#    远端 SSH：exec zsh
```

### 注意事项

- **sudo 权限**是必须的，脚本启动第一步就会检查，若无权限会直接报错退出
- **运行完成后必须重新登录或重启终端**，否则 zsh 配置不会生效
- Linux 下建议搭配代理 (Clash/机场) 使用，端口 7897 自动检测
- 旧 `.zshrc` 会被备份为 `.zshrc.pre-oh-my-zsh`，不用担心配置丢失

---

## cpu_benchmark.py — 单核 CPU 性能测试

纯 Python 标准库，9 项测试覆盖不同 CPU 能力维度。

```bash
python3 cpu_benchmark.py
```

| 测试项 | 规模 | 测什么 |
|--------|------|--------|
| 整数运算 | 2 亿次 | ALU 吞吐量 |
| 浮点运算 | 100 万次 | 三角函数/对数 |
| 质数筛 | 2000 万内 | 分支预测 + 内存 |
| 递归斐波那契 | n=38 | 函数调用开销 |
| 矩阵乘法 | 200x200 | 嵌套循环 + 缓存 |
| SHA-256 哈希 | 20 万次 | 加密计算 |
| JSON 序列化 | 5 万次 | 字符串处理 |
| 排序 | 200 万元素 | Timsort |
| 字符串操作 | 500 次大文本 | 内存操作 |
