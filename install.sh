#!/bin/bash
# ==========================================================
# KOMPLEKSOWY SKRYPT KONFIGURACYJNY SYSTEMU (XFCE)
# ==========================================================

set -euo pipefail

# ── Wykrywanie języka systemu ──────────────────────────────────
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

# ── Kolory ────────────────────────────────────────────────────
SUCCESS='\033[0;32m'
ERR='\033[0;31m'
NC='\033[0m'

# ── Sprawdzenie uprawnień i Sudo ──────────────────────────────
if [[ "$EUID" -eq 0 ]]; then
    if [[ "$SCRIPT_LANG" == "pl" ]]; then
        echo -e "${ERR}✘ Nie uruchamiaj skryptu jako root. Uruchom jako zwykły użytkownik z sudo.${NC}"
    else
        echo -e "${ERR}✘ Do not run this script as root. Run as a normal user with sudo.${NC}"
    fi
    exit 1
fi

sudo -v || {
    if [[ "$SCRIPT_LANG" == "pl" ]]; then
        echo -e "${ERR}✘ Brak uprawnień sudo. Skrypt wymaga sudo do konfiguracji systemu.${NC}"
    else
        echo -e "${ERR}✘ No sudo privileges. The script requires sudo for system configuration.${NC}"
    fi
    exit 1
}

CURRENT_USER=$(whoami)
# Tymczasowy wyjątek sudo (aby zapobiec blokadom na hasło w trakcie ukrytych zadań)
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/99-temp-installer > /dev/null

# ── Zmienne XFCE i wielojęzyczne ścieżki XDG ──────────────────
OLD_USER_PLACEHOLDER="bartek"
USER_PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallpaper_PATH="$USER_PICTURES_DIR/wallpaper.jpg"
LOGIN_WALLPAPER_PATH="/usr/share/backgrounds/custom/login-wallpaper.png"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Ukrywanie komunikatów i tworzenie logu błędów ─────────────
TMP_LOG="$(mktemp /tmp/install-log.XXXXXX)"
LOG_FILE="$HOME/install_error_$(date +%Y%m%d_%H%M%S).log"

# fd 3 = terminal (używany WYŁĄCZNIE dla paska postępu i pytań)
exec 3>&1
exec >"$TMP_LOG" 2>&1

cleanup_on_exit() {
    local exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        cp -f "$TMP_LOG" "$LOG_FILE" 2>/dev/null || true
        echo -e "\n" >&3
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

# ── Funkcja rysująca pasek postępu ─────────────────────────────
show_progress() {
    local step=$1
    local total=$2
    local msg=$3
    local percent=$(( step * 100 / total ))
    local filled=$(( percent / 2 ))
    local empty=$(( 50 - filled ))

    local bar_filled=""
    local bar_empty=""
    if [ $filled -gt 0 ]; then printf -v bar_filled '%*s' "$filled" ''; bar_filled="${bar_filled// /#}"; fi
    if [ $empty -gt 0 ]; then printf -v bar_empty '%*s' "$empty" ''; bar_empty="${bar_empty// /-}"; fi

    printf "\r\033[K[\033[1;32m%s\033[0;90m%s\033[0m] %3d%% | \033[1;36m%s\033[0m" "$bar_filled" "$bar_empty" "$percent" "$msg" >&3
}

# ── 3 GŁÓWNE KOMUNIKATY ────────────────────────────────────────
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

# ==========================================================
# 1. KOPIOWANIE PLIKÓW KONFIGURACYJNYCH
# ==========================================================
show_progress 0 $TOTAL_STEPS "$MSG_PHASE_1"

if [[ -d "$SCRIPT_DIR/.config" ]] && [[ "$(realpath "$SCRIPT_DIR/.config")" != "$(realpath ~/.config)" ]]; then
    cp -af "$SCRIPT_DIR/.config/." ~/.config/
fi

if [[ -d "$SCRIPT_DIR/.local/share" ]] && [[ "$(realpath "$SCRIPT_DIR/.local/share")" != "$(realpath ~/.local/share)" ]]; then
    cp -af "$SCRIPT_DIR/.local/share/." ~/.local/share/
fi

if [[ -d "$SCRIPT_DIR/.icons" ]] && [[ "$(realpath "$SCRIPT_DIR/.icons")" != "$(realpath ~/.icons)" ]]; then
    cp -af "$SCRIPT_DIR/.icons/." ~/.icons/
fi

if [[ -d "$SCRIPT_DIR/.themes" ]] && [[ "$(realpath "$SCRIPT_DIR/.themes")" != "$(realpath ~/.themes)" ]]; then
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

if command -v xfconf-query >/dev/null 2>&1; then

    # Ratowanie braku połączenia z DBUS (częsty błąd przy odpalaniu z tty/su)
    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        SESSION_PID=$(pgrep -u "$CURRENT_USER" xfce4-session | head -n 1)
        if [[ -n "$SESSION_PID" ]]; then
            export DBUS_SESSION_BUS_ADDRESS=$(grep -z DBUS_SESSION_BUS_ADDRESS "/proc/$SESSION_PID/environ" 2>/dev/null | tr '\0' '\n' | grep ^DBUS_SESSION_BUS_ADDRESS= | cut -d= -f2-)
        fi
    fi

    # Szukamy obu standardów nazewnictwa właściwości tapety
    DESKTOP_PROPS=$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E "last-image$|image-path$" || true)

    if [[ -n "$DESKTOP_PROPS" ]]; then
        # Usunięcie starych miniaturek i cache'u pulpitu
        rm -f ~/.cache/xfce4/desktop/* 2>/dev/null || true

        while IFS= read -r prop; do
            # Ustawienie pustej/fałszywej wartości wymusza na demona odnotowanie zmiany tekstu
            xfconf-query -c xfce4-desktop -p "$prop" -t string -s "/dev/null" 2>/dev/null || true
            # Właściwe ustawienie tapety docelowej
            xfconf-query -c xfce4-desktop -p "$prop" -t string -s "$wallpaper_PATH" 2>/dev/null || true
        done <<< "$DESKTOP_PROPS"

        # Wymuszenie przeładowania tła od razu bez czekania na restart
        if command -v xfdesktop >/dev/null 2>&1; then
            xfdesktop --reload &>/dev/null || true
        fi
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

if [ -d "$SCRIPT_DIR/bleachbit" ]; then
    sudo mkdir -p /root/.config/bleachbit
    sudo cp -af "$SCRIPT_DIR/bleachbit/." /root/.config/bleachbit/
fi

# Zakończenie paska postępu (100%)
show_progress 6 $TOTAL_STEPS "$MSG_PHASE_3"
echo -e "\n" >&3

if [[ "$SCRIPT_LANG" == "pl" ]]; then
    echo -e "${SUCCESS}✔ KONFIGURACJA ZAKOŃCZONA SUKCESEM!${NC}" >&3
else
    echo -e "${SUCCESS}✔ CONFIGURATION COMPLETED SUCCESSFULLY!${NC}" >&3
fi

systemctl reboot
