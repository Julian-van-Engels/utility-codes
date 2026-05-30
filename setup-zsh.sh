#!/usr/bin/env bash
set -euo pipefail

OS="$(uname -s)"

# ============================================================
# 1. 安装 Oh My Zsh
# ============================================================
echo "==> 安装 Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# ============================================================
# 2. 安装自定义插件
# ============================================================
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
mkdir -p "$ZSH_CUSTOM"

if [ ! -d "$ZSH_CUSTOM/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/zsh-autosuggestions"
fi
if [ ! -d "$ZSH_CUSTOM/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/zsh-syntax-highlighting"
fi

# ============================================================
# 3. 安装命令行工具
# ============================================================
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
        if command -v apt &>/dev/null; then
            sudo apt update -qq
            sudo apt install -y eza trash-cli yazi 2>/dev/null || true
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y eza trash-cli yazi 2>/dev/null || true
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm eza trash-cli yazi 2>/dev/null || true
        else
            echo "未检测到支持的包管理器，请手动安装: eza, trash-cli, yazi"
        fi
        ;;
esac

# ============================================================
# 4. 写入 .zshrc
# ============================================================
cat > "$HOME/.zshrc" << 'ZSHRC_EOF'
# === Oh My Zsh ===
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git z zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# === 通用别名 ===
alias zshconfig="vim ~/.zshrc"
alias rm="trash"
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

echo "==> 完成！执行 'exec zsh' 或重新打开终端即可生效。"
