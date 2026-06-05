#!/usr/bin/env bash
set -e

echo "==> 检查 Ghostty 安装状态..."

if command -v ghostty &>/dev/null; then
    echo "==> Ghostty 已安装，跳过安装步骤"
else
    echo "==> 安装 Ghostty..."

    # 检测发行版
    if ! command -v lsb_release &>/dev/null; then
        sudo apt update -qq && sudo apt install -y lsb-release
    fi

    distro=$(lsb_release -is 2>/dev/null)
    codename=$(lsb_release -cs 2>/dev/null)

    # 使用社区维护的 apt 源 (支持 Debian + Ubuntu)
    if command -v apt &>/dev/null; then
        echo "    添加 Ghostty apt 源..."
        sudo curl -fsSL https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc \
            | sudo gpg --dearmor -o /usr/share/keyrings/debian.griffo.io.gpg

        echo "deb [signed-by=/usr/share/keyrings/debian.griffo.io.gpg] \
https://debian.griffo.io/apt ${codename} main" \
            | sudo tee /etc/apt/sources.list.d/debian.griffo.io.list > /dev/null

        sudo apt update -qq
        sudo apt install -y ghostty
        echo "==> Ghostty 安装完成"
    else
        echo "未检测到 apt，请手动安装 Ghostty: https://ghostty.org/docs/install/binary"
        exit 1
    fi
fi

# ============================================================
# 写入配置
# ============================================================
CONFIG_DIR="$HOME/.config/ghostty"
mkdir -p "$CONFIG_DIR"
BACKUP=""
if [ -f "$CONFIG_DIR/config" ]; then
    BACKUP="$CONFIG_DIR/config.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_DIR/config" "$BACKUP"
    echo "==> 已备份旧配置到: $BACKUP"
fi

echo "==> 写入 Ghostty 配置..."
cat > "$CONFIG_DIR/config" << 'EOF'
# === 字体 ===
font-family = "Maple Mono NF CN"
font-size = 14
font-thicken = true
adjust-cell-height = 2

# === 主题 ===
theme = Catppuccin Macchiato

# === 窗口 ===
background-opacity = 0.9
background-blur-radius = 20
window-padding-x = 10
window-padding-y = 8
window-save-state = always
window-theme = auto
gtk-titlebar = false

# === 光标 ===
cursor-style = bar
cursor-style-blink = true
cursor-opacity = 0.8

# === 鼠标 ===
mouse-shift-capture = true
mouse-hide-while-typing = true
copy-on-select = clipboard

# === 快速终端 ===
quick-terminal-position = top
quick-terminal-screen = main
quick-terminal-autohide = true
quick-terminal-animation-duration = 0.15

# === 剪贴板 ===
clipboard-paste-protection = true
clipboard-paste-bracketed-safe = true

# === Shell 集成 ===
shell-integration = detect

# === 按键绑定 (super 键兼容 Linux/Mac) ===
keybind = super+t=new_tab
keybind = super+shift+left=previous_tab
keybind = super+shift+right=next_tab
keybind = super+w=close_surface

keybind = super+d=new_split:right
keybind = super+shift+d=new_split:down
keybind = super+alt+left=goto_split:left
keybind = super+alt+right=goto_split:right
keybind = super+alt+up=goto_split:top
keybind = super+alt+down=goto_split:bottom

keybind = super+plus=increase_font_size:1
keybind = super+minus=decrease_font_size:1
keybind = super+zero=reset_font_size

keybind = global:ctrl+grave_accent=toggle_quick_terminal

keybind = super+shift+e=equalize_splits
keybind = super+shift+f=toggle_split_zoom

keybind = super+shift+comma=reload_config

# === 回滚 ===
scrollback-limit = 25000000
EOF

echo ""
echo "=============================================="
echo "  Ghostty 配置完成！"
echo "  配置: $CONFIG_DIR/config"
if [ -n "$BACKUP" ]; then
    echo "  备份: $BACKUP"
fi
echo ""
echo "  注意: 字体 'Maple Mono NF CN' 需手动安装"
echo "  https://github.com/subframe7536/maple-font/releases"
echo "=============================================="
