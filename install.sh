#!/bin/bash
# ==========================================================
# KOMPLEKSOWY SKRYPT KONFIGURACYJNY SYSTEMU (XFCE)
# ==========================================================

set -Eeuo pipefail

detect_system_lang() {
    local sys_lang="${LANG:-}"
    [[ -z "$sys_lang" ]] && sys_lang="${LC_ALL:-${LC_MESSAGES:-}}"
    if [[ "$sys_lang" == pl_PL* || "$sys_lang" == pl* ]]; then
        echo "pl"
    else
        echo "en"
    fi
}
SCRIPT_LANG="$(detect_system_lang)"

SUCCESS='\033[0;32m'
ERR='\033[0;31m'
INFO='\033[0;36m'
WARN='\033[0;33m'
NC='\033[0m'

TMP_LOG="$(mktemp /tmp/install-log.XXXXXX)"
LOG_FILE="$HOME/install_error_$(date +%Y%m%d_%H%M%S).log"

exec 3>&1
exec >>"$TMP_LOG" 2>&1

printf '\033[?7l' >&3

cleanup_on_exit() {
    local exit_code=$?
    printf '\033[?7h' >&3
    if [ "$exit_code" -ne 0 ]; then
        echo -e "\n" >&3
        cp -f "$TMP_LOG" "$LOG_FILE" 2>/dev/null || true
        if [[ "$SCRIPT_LANG" == "pl" ]]; then
            echo -e "${ERR}✘ Wystąpił błąd (kod: $exit_code). Szczegółowy log zapisano w: $LOG_FILE${NC}" >&3
        else
            echo -e "${ERR}✘ An error occurred (code: $exit_code). Detailed log saved to: $LOG_FILE${NC}" >&3
        fi
    fi
    sudo rm -f /etc/sudoers.d/99-temp-installer 2>/dev/null || true
    rm -f "$TMP_LOG" 2>/dev/null || true
}
trap cleanup_on_exit EXIT

_pick_msg() { [[ "$SCRIPT_LANG" == "pl" ]] && echo "$1" || echo "$2"; }
log_info() { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${INFO}==> $m${NC}"; }
log_ok()   { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${SUCCESS}✔ $m${NC}"; }
log_err()  { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${ERR}✘ ERROR: $m${NC}"; }
log_warn() { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${WARN}⚠ WARN: $m${NC}"; }

trap 'log_err "Błąd w linii $LINENO. Polecenie: $BASH_COMMAND" "Error at line $LINENO. Command: $BASH_COMMAND"' ERR

show_progress() {
    local step=$1
    local total=$2
    local msg=$3
    local percent=$(( step * 100 / total ))

    local cols
    cols=$(tput cols 2>/dev/null)
    [[ "$cols" =~ ^[0-9]+$ ]] || cols=80

    local bar_width=50
    local reserved=12
    if (( cols - reserved < bar_width )); then
        bar_width=$(( cols - reserved ))
        (( bar_width < 10 )) && bar_width=10
    fi

    local overhead=$(( bar_width + reserved ))
    local avail=$(( cols - overhead ))
    if (( avail < 5 )); then avail=5; fi
    if (( ${#msg} > avail )); then
        msg="${msg:0:$((avail - 1))}…"
    fi

    local filled=$(( percent * bar_width / 100 ))
    local empty=$(( bar_width - filled ))

    local bar_filled=""
    local bar_empty=""
    if [ $filled -gt 0 ]; then printf -v bar_filled '%*s' "$filled" ''; bar_filled="${bar_filled// /#}"; fi
    if [ $empty -gt 0 ]; then printf -v bar_empty '%*s' "$empty" ''; bar_empty="${bar_empty// /-}"; fi

    printf "\r\033[K[\033[1;32m%s\033[0;90m%s\033[0m] %3d%% | \033[1;36m%s\033[0m" "$bar_filled" "$bar_empty" "$percent" "$msg" >&3
}

if [[ "$SCRIPT_LANG" == "pl" ]]; then
    MSG_PHASE_1="[1/3] Kopiowanie plików konfiguracyjnych i motywów..."
    MSG_PHASE_2="[2/3] Konfiguracja środowiska XFCE i avatara..."
    MSG_PHASE_3="[3/3] Konfiguracja ekranu logowania i uprawnień roota..."
else
    MSG_PHASE_1="[1/3] Copying configuration files and themes..."
    MSG_PHASE_2="[2/3] Configuring XFCE environment and avatar..."
    MSG_PHASE_3="[3/3] Configuring login screen and root permissions..."
fi

TOTAL_STEPS=6

CURRENT_USER=$(whoami)
OLD_USER_PLACEHOLDER="bartek"
USER_PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallpaper_PATH="$USER_PICTURES_DIR/wallpaper.jpg"
LOGIN_WALLPAPER_PATH="/usr/share/backgrounds/custom/login-wallpaper.png"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$EUID" -eq 0 ]]; then
    if [[ "$SCRIPT_LANG" == "pl" ]]; then
        echo -e "${ERR}✘ Nie uruchamiaj skryptu jako root. Uruchom jako zwykły użytkownik z sudo.${NC}" >&3
    else
        echo -e "${ERR}✘ Do not run this script as root. Run as a normal user with sudo.${NC}" >&3
    fi
    exit 1
fi

sudo -v
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/99-temp-installer > /dev/null

# ==========================================================
# 1. KOPIOWANIE PLIKÓW KONFIGURACYJNYCH
# ==========================================================
show_progress 0 $TOTAL_STEPS "$MSG_PHASE_1"

if [[ -d "$SCRIPT_DIR/.config" ]] && [[ "$(realpath "$SCRIPT_DIR/.config" 2>/dev/null)" != "$(realpath ~/.config 2>/dev/null)" ]]; then
    mkdir -p ~/.config
    cp -af "$SCRIPT_DIR/.config/." ~/.config/
fi

if [[ -d "$SCRIPT_DIR/.local/share" ]] && [[ "$(realpath "$SCRIPT_DIR/.local/share" 2>/dev/null)" != "$(realpath ~/.local/share 2>/dev/null)" ]]; then
    mkdir -p ~/.local/share
    cp -af "$SCRIPT_DIR/.local/share/." ~/.local/share/
fi

if [[ -d "$SCRIPT_DIR/.icons" ]] && [[ "$(realpath "$SCRIPT_DIR/.icons" 2>/dev/null)" != "$(realpath ~/.icons 2>/dev/null)" ]]; then
    mkdir -p ~/.icons
    cp -af "$SCRIPT_DIR/.icons/." ~/.icons/
fi

if [[ -d "$SCRIPT_DIR/.themes" ]] && [[ "$(realpath "$SCRIPT_DIR/.themes" 2>/dev/null)" != "$(realpath ~/.themes 2>/dev/null)" ]]; then
    mkdir -p ~/.themes
    cp -af "$SCRIPT_DIR/.themes/." ~/.themes/
fi

show_progress 1 $TOTAL_STEPS "$MSG_PHASE_1"

if [[ -f "$SCRIPT_DIR/wallpaper.jpg" ]] && [[ "$(realpath "$SCRIPT_DIR/wallpaper.jpg")" != "$(realpath "$wallpaper_PATH" 2>/dev/null)" ]]; then
    mkdir -p "$(dirname "$wallpaper_PATH")"
    cp -af "$SCRIPT_DIR/wallpaper.jpg" "$wallpaper_PATH"
fi

if [[ "$OLD_USER_PLACEHOLDER" != "$CURRENT_USER" ]]; then
    grep -rlZ --include="*.conf" --include="*.json" --include="*.ini" \
        "/home/$OLD_USER_PLACEHOLDER" ~/.config 2>/dev/null \
        | xargs -0 -r sed -i "s|/home/$OLD_USER_PLACEHOLDER|/home/$CURRENT_USER|g" || true
fi

show_progress 2 $TOTAL_STEPS "$MSG_PHASE_1"

# ==========================================================
# 2. KONFIGURACJA ŚRODOWISKA XFCE I AVATARA
# ==========================================================
show_progress 3 $TOTAL_STEPS "$MSG_PHASE_2"

chmod 644 "$wallpaper_PATH" 2>/dev/null || true

SESSION_PID=$(pgrep -u "$CURRENT_USER" xfce4-session | head -n 1 || true)

if [[ -n "$SESSION_PID" ]] && command -v xfconf-query >/dev/null 2>&1; then
    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        export DBUS_SESSION_BUS_ADDRESS=$(grep -z DBUS_SESSION_BUS_ADDRESS "/proc/$SESSION_PID/environ" 2>/dev/null | tr '\0' '\n' | grep ^DBUS_SESSION_BUS_ADDRESS= | cut -d= -f2- || true)
    fi

    mapfile -t DESKTOP_PROPS < <(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E "last-image$|image-path$" || true)

    if [[ ${#DESKTOP_PROPS[@]} -eq 0 ]]; then
        DESKTOP_PROPS=("/backdrop/screen0/monitor0/workspace0/last-image")
    fi

    if [[ -d ~/.cache/xfce4/desktop ]]; then
        find ~/.cache/xfce4/desktop -type f -iname "*$(basename "$wallpaper_PATH")*" -delete 2>/dev/null || true
    fi

    for prop in "${DESKTOP_PROPS[@]}"; do
        style_prop="${prop%last-image}image-style"
        [[ "$prop" == *image-path ]] && style_prop="${prop%image-path}image-style"

        xfconf-query -c xfce4-desktop -p "$prop" -n -t string -s "/dev/null" 2>/dev/null \
            || xfconf-query -c xfce4-desktop -p "$prop" -t string -s "/dev/null" 2>/dev/null || true
        sleep 0.2
        xfconf-query -c xfce4-desktop -p "$prop" -n -t string -s "$wallpaper_PATH" 2>/dev/null \
            || xfconf-query -c xfce4-desktop -p "$prop" -t string -s "$wallpaper_PATH" 2>/dev/null || true

        xfconf-query -c xfce4-desktop -p "$style_prop" -n -t int -s 5 2>/dev/null \
            || xfconf-query -c xfce4-desktop -p "$style_prop" -t int -s 5 2>/dev/null || true
    done

    if command -v xfdesktop >/dev/null 2>&1 && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        pkill -u "$CURRENT_USER" -x xfdesktop 2>/dev/null || true
        sleep 0.5
        nohup xfdesktop >/dev/null 2>&1 &
        disown
    fi
else
    XFCE_DESKTOP_XML="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
    mkdir -p "$(dirname "$XFCE_DESKTOP_XML")"
    if [[ ! -f "$XFCE_DESKTOP_XML" ]]; then
        cat > "$XFCE_DESKTOP_XML" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="$wallpaper_PATH"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF
    else
        sed -i -E 's|name="last-image" type="string" value="[^"]+"|name="last-image" type="string" value="'"$wallpaper_PATH"'"|g' "$XFCE_DESKTOP_XML" || true
        sed -i -E 's|name="image-path" type="string" value="[^"]+"|name="image-path" type="string" value="'"$wallpaper_PATH"'"|g' "$XFCE_DESKTOP_XML" || true
    fi
fi

show_progress 4 $TOTAL_STEPS "$MSG_PHASE_2"

if [[ -f "$SCRIPT_DIR/piwo.png" ]]; then
    AVATAR_DEST="/var/lib/AccountsService/icons/$CURRENT_USER"
    sudo cp -af "$SCRIPT_DIR/piwo.png" "$AVATAR_DEST"
    sudo chmod 644 "$AVATAR_DEST"

    ACCOUNTS_FILE="/var/lib/AccountsService/users/$CURRENT_USER"
    if [[ -f "$ACCOUNTS_FILE" ]]; then
        if sudo grep -q "^Icon=" "$ACCOUNTS_FILE"; then
            sudo sed -i "s|^Icon=.*|Icon=$AVATAR_DEST|" "$ACCOUNTS_FILE"
        else
            if sudo grep -q "^\[User\]" "$ACCOUNTS_FILE"; then
                sudo sed -i "/^\[User\]/a Icon=$AVATAR_DEST" "$ACCOUNTS_FILE"
            else
                echo "Icon=$AVATAR_DEST" | sudo tee -a "$ACCOUNTS_FILE" > /dev/null
            fi
        fi
    else
        echo -e "[User]\nIcon=$AVATAR_DEST" | sudo tee "$ACCOUNTS_FILE" > /dev/null
    fi
fi

# ==========================================================
# 3. KONFIGURACJA EKRANU LOGOWANIA I UPRAWNIEŃ ROOTA
# ==========================================================
show_progress 5 $TOTAL_STEPS "$MSG_PHASE_3"

if [[ -f "$SCRIPT_DIR/login-wallpaper.png" ]]; then
    sudo mkdir -p /usr/share/backgrounds/custom
    sudo cp -af "$SCRIPT_DIR/login-wallpaper.png" "$LOGIN_WALLPAPER_PATH"
    sudo chmod 644 "$LOGIN_WALLPAPER_PATH"

    if [ -f /etc/lightdm/lightdm-gtk-greeter.conf ]; then
        if ! grep -q "^\[greeter\]" /etc/lightdm/lightdm-gtk-greeter.conf 2>/dev/null; then
            echo "[greeter]" | sudo tee -a /etc/lightdm/lightdm-gtk-greeter.conf > /dev/null
        fi

        if sudo grep -q "^background=" /etc/lightdm/lightdm-gtk-greeter.conf; then
            sudo sed -i "s|^background=.*|background=$LOGIN_WALLPAPER_PATH|" /etc/lightdm/lightdm-gtk-greeter.conf
        else
            sudo sed -i "/^\[greeter\]/a background=$LOGIN_WALLPAPER_PATH" /etc/lightdm/lightdm-gtk-greeter.conf
        fi
    fi
fi

sudo rm -f /etc/sudoers.d/99-temp-installer

show_progress 6 $TOTAL_STEPS "$MSG_PHASE_3"
echo -e "\n" >&3

if [[ "$SCRIPT_LANG" == "pl" ]]; then
    echo -e "${SUCCESS}✔ KONFIGURACJA ZAKOŃCZONA SUKCESEM!${NC}" >&3
else
    echo -e "${SUCCESS}✔ CONFIGURATION COMPLETED SUCCESSFULLY!${NC}" >&3
fi

systemctl reboot || true
