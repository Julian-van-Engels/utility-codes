#!/usr/bin/env bash
set -e

OS="$(uname -s)"

# 开局请求 sudo 权限并缓存，后续不再询问
SUDO=""
if sudo -v 2>/dev/null; then
    SUDO="sudo"
    # 后台持续刷新 sudo 缓存，防止超时
    (while true; do sudo -n true; sleep 60; kill -0 $$ || exit; done) 2>/dev/null &
fi

# ============================================================
# 0. Linux: 配置代理（git + curl 国内加速）
# ============================================================
setup_proxy() {
    local proxy_url="http://127.0.0.1:7897"
    if [ "$OS" != "Linux" ]; then
        return
    fi
    # 先检测代理是否可达
    if curl -s --connect-timeout 3 --proxy "$proxy_url" https://www.google.com > /dev/null 2>&1; then
        echo "==> 检测到代理 $proxy_url，配置 git 代理..."
        git config --global http.proxy "$proxy_url"
        git config --global https.proxy "$proxy_url"
        export http_proxy="$proxy_url"
        export https_proxy="$proxy_url"
    else
        echo "==> 代理 $proxy_url 不可达，跳过"
    fi
}
setup_apt_mirror() {
    if [ "$OS" != "Linux" ] || ! command -v apt &>/dev/null; then
        return
    fi
    local codename
    codename=$(lsb_release -cs 2>/dev/null) || return

    local version_id
    version_id=$(awk -F= '/VERSION_ID/ {gsub(/"/,""); print $2}' /etc/os-release 2>/dev/null)
    local major_ver=${version_id%%.*}

    local tsinghua="https://mirrors.tuna.tsinghua.edu.cn/ubuntu"
    local security="http://security.ubuntu.com/ubuntu"

    if [ "$major_ver" -ge 24 ] 2>/dev/null; then
        echo "==> 切换 apt 为清华镜像源 (DEB822 格式)..."
        ${SUDO:-} mkdir -p /etc/apt/sources.list.d
        # 先备份可能存在的旧格式文件
        ${SUDO:-} cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true
        ${SUDO:-} cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak 2>/dev/null || true
        ${SUDO:-} tee /etc/apt/sources.list.d/ubuntu.sources > /dev/null << EOF
Types: deb
URIs: ${tsinghua}
Suites: ${codename} ${codename}-updates ${codename}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: ${security}
Suites: ${codename}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
    else
        echo "==> 切换 apt 为清华镜像源..."
        ${SUDO:-} cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true
        ${SUDO:-} tee /etc/apt/sources.list > /dev/null << EOF
deb ${tsinghua}/ ${codename} main restricted universe multiverse
deb ${tsinghua}/ ${codename}-updates main restricted universe multiverse
deb ${tsinghua}/ ${codename}-backports main restricted universe multiverse
deb ${security}/ ${codename}-security main restricted universe multiverse
EOF
    fi
    echo "==> apt 清华源配置完成"
}

# ============================================================
# 1. 确保基础依赖: curl, git
# ============================================================
install_base_deps() {
    local missing=""
    command -v curl &>/dev/null || missing="$missing curl"
    command -v git   &>/dev/null || missing="$missing git"
    command -v unzip &>/dev/null || missing="$missing unzip"

    if [ -z "$missing" ]; then
        return
    fi
    echo "==> 安装基础依赖:$missing"

    case "$OS" in
        Darwin)
            echo "macOS 应自带 curl 和 git，请检查系统"
            exit 1
            ;;
        Linux)
            if command -v apt &>/dev/null; then
                ${SUDO:-} apt update -qq
                ${SUDO:-} apt install -y $missing
            elif command -v dnf &>/dev/null; then
                ${SUDO:-} dnf install -y $missing
            elif command -v pacman &>/dev/null; then
                ${SUDO:-} pacman -S --noconfirm $missing
            else
                echo "请先手动安装:$missing"
                exit 1
            fi
            ;;
    esac
    echo "==> 基础依赖安装完成"
}

# ============================================================
# 1. 确保 zsh 已安装
# ============================================================
install_zsh() {
    if command -v zsh &>/dev/null; then
        echo "==> zsh 已安装: $(zsh --version)"
        return
    fi
    echo "==> 安装 zsh..."
    case "$OS" in
        Darwin)
            echo "macOS 应自带 zsh，请升级系统"
            exit 1
            ;;
        Linux)
            if command -v apt &>/dev/null; then
                ${SUDO:-} apt update -qq && ${SUDO:-} apt install -y zsh
            elif command -v dnf &>/dev/null; then
                ${SUDO:-} dnf install -y zsh
            elif command -v pacman &>/dev/null; then
                ${SUDO:-} pacman -S --noconfirm zsh
            elif command -v apk &>/dev/null; then
                ${SUDO:-} apk add zsh
            else
                echo "未检测到支持的包管理器，请手动安装 zsh"
                exit 1
            fi
            ;;
    esac
    echo "==> zsh 安装完成"
}

# ============================================================
# 2. 安装 Oh My Zsh
# ============================================================
install_ohmyzsh() {
    if [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
        echo "==> Oh My Zsh 已安装"
        return
    fi
    echo "==> 安装 Oh My Zsh..."

    # 先删掉可能残留的空目录
    rm -rf "$HOME/.oh-my-zsh"

    local installed=false
    for repo in \
        "https://gitee.com/mirrors/oh-my-zsh.git" \
        "https://github.com/ohmyzsh/ohmyzsh.git" \
        "https://mirror.ghproxy.com/https://github.com/ohmyzsh/ohmyzsh.git"; do
        echo "  尝试: $repo"
        if timeout 20 git clone --depth=1 "$repo" "$HOME/.oh-my-zsh" 2>&1; then
            installed=true
            break
        fi
        rm -rf "$HOME/.oh-my-zsh"
        echo "  失败，尝试下一个镜像..."
    done

    if [ "$installed" = false ]; then
        echo "Oh My Zsh 安装失败，请手动安装: https://ohmyz.sh"
        exit 1
    fi
    echo "==> Oh My Zsh 安装完成"
}

# ============================================================
# 3. 设置 zsh 为默认 Shell
# ============================================================
set_default_shell() {
    local zsh_path
    zsh_path="$(command -v zsh)"
    if [ "$SHELL" != "$zsh_path" ]; then
        echo "==> 设置 zsh 为默认 shell..."
        if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
            echo "$zsh_path" | ${SUDO:-} tee -a /etc/shells > /dev/null
        fi
        chsh -s "$zsh_path"
    fi
}

# ============================================================
# 4. 安装自定义插件
# ============================================================
install_plugins() {
    local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    mkdir -p "$custom_dir"

    if [ ! -d "$custom_dir/zsh-autosuggestions" ]; then
        echo "==> 安装 zsh-autosuggestions..."
        timeout 20 git clone --depth=1 https://gitee.com/mirrors/zsh-autosuggestions "$custom_dir/zsh-autosuggestions" 2>/dev/null || \
        timeout 20 git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$custom_dir/zsh-autosuggestions" 2>/dev/null || \
        timeout 20 git clone --depth=1 https://mirror.ghproxy.com/https://github.com/zsh-users/zsh-autosuggestions "$custom_dir/zsh-autosuggestions" 2>/dev/null || \
        echo "  zsh-autosuggestions 安装失败，跳过"
    fi

    if [ ! -d "$custom_dir/zsh-syntax-highlighting" ]; then
        echo "==> 安装 zsh-syntax-highlighting..."
        timeout 20 git clone --depth=1 https://gitee.com/mirrors/zsh-syntax-highlighting "$custom_dir/zsh-syntax-highlighting" 2>/dev/null || \
        timeout 20 git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$custom_dir/zsh-syntax-highlighting" 2>/dev/null || \
        timeout 20 git clone --depth=1 https://mirror.ghproxy.com/https://github.com/zsh-users/zsh-syntax-highlighting "$custom_dir/zsh-syntax-highlighting" 2>/dev/null || \
        echo "  zsh-syntax-highlighting 安装失败，跳过"
    fi
}

# ============================================================
# 5. 安装命令行工具
# ============================================================
install_tools() {
    echo "==> 安装命令行工具..."
    case "$OS" in
        Darwin)
            if command -v brew &>/dev/null; then
                brew install eza trash make yazi 2>/dev/null || true
            else
                echo "请先安装 Homebrew: https://brew.sh"
            fi
            ;;
        Linux)
            if [ -z "$SUDO" ]; then
                echo "没有 sudo 权限，跳过工具安装"
                return
            fi

            local arch
            arch=$(uname -m)
            # GitHub release 用的 arch 名字
            local gh_arch
            case "$arch" in
                x86_64)  gh_arch="x86_64-unknown-linux-gnu" ;;
                aarch64) gh_arch="aarch64-unknown-linux-gnu" ;;
                *)       echo "  未知架构: $arch，跳过工具安装"; return ;;
            esac

            # --- eza (从 GitHub Releases 下载二进制) ---
            if ! command -v eza &>/dev/null; then
                echo "  -> 安装 eza..."
                local eza_url="https://github.com/eza-community/eza/releases/latest/download/eza_${gh_arch}.tar.gz"
                if curl -fsSL --connect-timeout 15 -o /tmp/eza.tar.gz "$eza_url"; then
                    sudo tar xzf /tmp/eza.tar.gz -C /usr/local/bin && rm -f /tmp/eza.tar.gz
                    echo "    eza 安装完成"
                else
                    echo "    eza 下载失败，跳过"
                fi
            fi

            # --- yazi (musl 静态编译 + 依赖) ---
            if ! command -v yazi &>/dev/null; then
                echo "  -> 安装 yazi..."
                # 先装依赖
                if command -v apt &>/dev/null; then
                    sudo apt update -qq
                    sudo apt install -y ffmpeg 7zip jq poppler-utils fd-find ripgrep fzf zoxide imagemagick chafa 2>/dev/null || true
                    # Ubuntu 上 fd-find 二进制名为 fdfind，创建 fd 软链接
                    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
                        sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
                    fi
                fi
                # 下载并安装 yazi 本体
                local yazi_arch
                case "$arch" in
                    x86_64)  yazi_arch="x86_64-unknown-linux-musl" ;;
                    aarch64) yazi_arch="aarch64-unknown-linux-musl" ;;
                    *)       yazi_arch="$gh_arch" ;;
                esac
                local yazi_url="https://github.com/sxyazi/yazi/releases/latest/download/yazi-${yazi_arch}.zip"
                if curl -fsSL --connect-timeout 30 -o "/tmp/yazi.zip" "$yazi_url"; then
                    cd /tmp
                    unzip -o yazi.zip
                    sudo mv yazi-"${yazi_arch}"/yazi /usr/local/bin/
                    sudo mv yazi-"${yazi_arch}"/ya   /usr/local/bin/
                    rm -rf yazi.zip yazi-"${yazi_arch}"
                    cd "$OLDPWD"
                    echo "    yazi 安装完成"
                else
                    echo "    yazi 下载失败，跳过"
                fi
            fi

            # --- trash-cli ---
            if ! command -v trash-put &>/dev/null; then
                echo "  -> 安装 trash-cli..."
                if command -v apt &>/dev/null; then
                    sudo apt install -y trash-cli 2>/dev/null || true
                elif command -v dnf &>/dev/null; then
                    sudo dnf install -y trash-cli 2>/dev/null || true
                elif command -v pacman &>/dev/null; then
                    sudo pacman -S --noconfirm trash-cli 2>/dev/null || true
                fi
            fi
            ;;
    esac
}

# ============================================================
# 6. 安装 opencode（终端 AI 编程助手）
#   严格遵循官方推荐方式: https://opencode.ai/docs/install
# ============================================================
install_opencode() {
    if command -v opencode &>/dev/null; then
        echo "==> opencode 已安装"
        return
    fi
    echo "==> 安装 opencode..."
    case "$OS" in
        Darwin)
            # 官方推荐: brew install anomalyco/tap/opencode
            if command -v brew &>/dev/null; then
                echo "    使用官方 Homebrew 源安装..."
                if brew install anomalyco/tap/opencode 2>/dev/null; then
                    echo "==> opencode 安装完成"
                    return
                fi
            fi
            # fallback: 官方一键脚本
            echo "    尝试官方安装脚本..."
            OPENCODE_INSTALL_DIR=/usr/local/bin \
                curl -fsSL --connect-timeout 30 https://opencode.ai/install | bash 2>/dev/null && \
                echo "==> opencode 安装完成" || \
                echo "    opencode 安装失败，请手动: brew install anomalyco/tap/opencode"
            ;;
        Linux)
            # 官方推荐: curl -fsSL https://opencode.ai/install | bash
            # 指定安装到 /usr/local/bin 确保终端直接可用
            echo "    使用官方安装脚本 (安装到 /usr/local/bin)..."
            if OPENCODE_INSTALL_DIR=/usr/local/bin \
                timeout 60 curl -fsSL --connect-timeout 30 https://opencode.ai/install | ${SUDO:-} bash 2>/dev/null; then
                echo "==> opencode 安装完成"
            else
                echo "    opencode 安装失败，请手动: https://opencode.ai/docs/install"
            fi
            ;;
    esac
}

# ============================================================
# 7. 写入 .zshrc
# ============================================================
write_zshrc() {
    echo "==> 写入 .zshrc..."

    # 收集需要迁移的旧配置内容
    local migrated=""
    local old_rc=""

    # 找到旧配置来源：优先 .zshrc，其次 bash 配置
    for f in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
        if [ -f "$f" ]; then
            old_rc="$f"
            break
        fi
    done

    if [ -n "$old_rc" ]; then
        echo "    发现旧配置: $old_rc，提取可迁移内容..."
        # 提取 export / alias / source / PATH 等可兼容配置行
        # 排除：Oh My Zsh 框架内容、bash 专属命令 (shopt/complete/bind)、shebang
        migrated=$(awk '
            /^[[:space:]]*#/ { next }                          # 跳过注释行
            /^[[:space:]]*$/ { next }                           # 跳过空行
            /oh-my-zsh/i { next }                               # 跳过 OMZ 相关内容
            /^[[:space:]]*shopt / { next }                      # bash 专属
            /^[[:space:]]*complete / { next }                   # bash 专属
            /^[[:space:]]*bind / { next }                       # bash 专属
            /^[[:space:]]*PROMPT_COMMAND/ { next }              # bash 专属
            /^[[:space:]]*PS1=/ { next }                        # 让 OMZ 主题接管
            /^#!\/bin\/bash/ { next }                           # shebang
            /conda initialize/ { in_conda=1 }
            in_conda { if (/<<<.*conda/) { in_conda=0; next }; next }
            { print }
        ' "$old_rc")

        # 备份旧配置
        local pre="$HOME/.zshrc.pre-oh-my-zsh"
        if [ -f "$HOME/.zshrc" ] || [ -h "$HOME/.zshrc" ]; then
            if [ -e "$pre" ]; then
                local old_pre="${pre}-$(date +%Y-%m-%d_%H-%M-%S)"
                echo "    .zshrc.pre-oh-my-zsh 已存在，重命名为 ${old_pre}"
                mv "$pre" "$old_pre"
            fi
            echo "    备份旧 .zshrc 到 .zshrc.pre-oh-my-zsh"
            mv "$HOME/.zshrc" "$pre"
        fi

        # 保存迁移内容，稍后追加到新 .zshrc
        if [ -n "$migrated" ]; then
            MIGRATED_CONTENT="$migrated"
            MIGRATED_SOURCE="$old_rc"
        fi
    fi

    cat > "$HOME/.zshrc" << 'ZSHRC_EOF'
# === 终端类型（修复远程连接时输入回显异常） ===
export TERM=xterm-256color

# === Oh My Zsh ===
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git z zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# === 通用别名 ===
alias zshconfig="vim ~/.zshrc"
if command -v trash-put &>/dev/null; then
    alias rm="trash-put"
elif command -v trash &>/dev/null; then
    alias rm="trash"
fi
alias ls='eza --icons --git --group-directories-first'
alias ll='eza -lh --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --icons'

# === 通用环境变量 ===
DEFAULT_USER=$USER

# === 自定义 Prompt：只显示最后两级目录 ===
prompt_dir() {
    prompt_segment blue $CURRENT_FG '%2~'
}

# === yazi cd hook ===
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    /bin/rm -f -- "$tmp"
}

# ============================================================
# macOS 专属配置
# ============================================================
if [[ "$(uname -s)" == "Darwin" ]]; then
    export HOMEBREW_NO_AUTO_UPDATE=true

    # GNU make 替代 BSD make
    alias make="gmake"

    # clang-format
    alias cformat_i="clang-format -i"

    # cp + 自动清理 ._ AppleDouble 文件
    cp_dot_clean() {
        local args=()
        local sources=()
        local dest=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                -r|-R|--recursive)
                    args+=("$1")
                    shift ;;
                -*)
                    args+=("$1")
                    shift ;;
                *)
                    if [[ $# -eq 1 ]]; then
                        dest="$1"
                    else
                        sources+=("$1")
                    fi
                    args+=("$1")
                    shift ;;
            esac
        done

        if [[ -z "$dest" ]] || [[ ${#sources[@]} -eq 0 ]]; then
            echo "用法: cp_dot_clean [options] source destination" >&2
            return 1
        fi

        if ! cp "${args[@]}"; then
            echo "复制失败" >&2
            return 1
        fi

        local clean_target="$dest"
        [[ -d "$dest" ]] || clean_target="$(dirname "$dest")"

        echo "正在清理 AppleDouble 文件..."
        find "$clean_target" -name "._*" -type f -delete 2>/dev/null
        if command -v dot_clean &>/dev/null; then
            dot_clean -m "$clean_target" 2>/dev/null
        fi
        echo "清理完成"
    }
fi
ZSHRC_EOF

    # 追加迁移的旧配置
    if [ -n "${MIGRATED_CONTENT:-}" ]; then
        echo "" >> "$HOME/.zshrc"
        echo "# === 以下从 ${MIGRATED_SOURCE:-旧配置} 自动迁移 ===" >> "$HOME/.zshrc"
        echo "# 如有 bash 专属语法报错，请自行删除对应行" >> "$HOME/.zshrc"
        echo "${MIGRATED_CONTENT}" >> "$HOME/.zshrc"
        echo "    已迁移 $(echo "$MIGRATED_CONTENT" | wc -l) 行旧配置"
    fi
}

# ============================================================
# 主流程
# ============================================================
setup_proxy
setup_apt_mirror
install_base_deps
install_zsh
install_ohmyzsh
set_default_shell
install_plugins
install_tools
install_opencode
write_zshrc

echo ""
echo "=============================================="
echo "  全部完成！执行 exec zsh 生效"
echo "=============================================="
echo ""
echo "  ── 工具速查 ──"
echo ""
echo "  ls      列出文件 (eza 彩色图标版)"
echo "  ll      详细列表 (权限/大小/Git 状态)"
echo "  lt      树状图 (只展开 2 层)"
echo "  rm      移到回收站 (trash-cli，非永久删除)"
echo ""
echo "  y       启动 Yazi 文件管理器 (Vim 键位)"
echo "          j/k 移动  h/l 进退目录  空格选中"
echo "          q 退出并自动 cd 到浏览目录"
echo ""
echo "  opencode   AI 编程助手"
echo "  cd 你的项目 && opencode"
echo "  进入后 /connect 连接自有的 AI 模型"
echo "=============================================="
