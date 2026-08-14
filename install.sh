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
INFO='\033[0;34m'
SUCCESS='\033[0;32m'
WARN='\033[0;33m'
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

# ── System logowania i ukrywanie komunikatów ──────────────────
TMP_LOG="$(mktemp /tmp/install-log.XXXXXX)"
LOG_FILE="$HOME/install_error_$(date +%Y%m%d_%H%M%S).log"

# fd 3 = terminal (używany WYŁĄCZNIE dla paska postępu i pytania końcowego)
exec 3>&1
exec >>"$TMP_LOG" 2>&1

cleanup_on_exit() {
    local exit_code=$?
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
    rm -f "$TMP_LOG"
}
trap cleanup_on_exit EXIT

# Funkcje logujące w tle (zapisują tylko do ukrytego pliku)
log_info()  { echo -e "${INFO}==> $*${NC}"; }
log_ok()    { echo -e "${SUCCESS}✔ $*${NC}"; }
log_err()   { echo -e "${ERR}✖ BŁĄD: $*${NC}" >&2; }
log_warn()  { echo -e "${WARN}⚠ UWAGA: $*${NC}"; }

trap 'log_warn "Błąd w linii $LINENO. Polecenie: $BASH_COMMAND — kontynuuję"' ERR

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
log_info "Rozpoczynam konfigurację wizualną użytkownika..."

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
    log_info "Aktualizuję ścieżki użytkownika w plikach konfiguracyjnych..."
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
    log_info "Ustawiam tapetę w systemie XFCE..."
    DESKTOP_PROPS=$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep "last-image" || true)

    if [[ -z "$DESKTOP_PROPS" ]]; then
        log_warn "Brak właściwości last-image w xfce4-desktop — pomijam ustawienie tapety."
    else
        while IFS= read -r prop; do
            xfconf-query -c xfce4-desktop -p "$prop" -s "$wallpaper_PATH" 2>/dev/null || log_warn "Nie udało się ustawić: $prop"
        done <<< "$DESKTOP_PROPS"
        log_ok "Tapeta XFCE została zaktualizowana."
    fi
else
    log_warn "xfconf-query nie znaleziony – pomijam automatyczną zmianę tapety."
fi

show_progress 4 $TOTAL_STEPS "$MSG_PHASE_2"

if [[ -f "$SCRIPT_DIR/piwo.png" ]]; then
    log_info "Ustawiam avatar użytkownika..."
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
    log_ok "Avatar użytkownika został ustawiony."
else
    log_warn "Nie znaleziono pliku piwo.png — pomijam ustawienie avatara."
fi

# ==========================================================
# 3. KONFIGURACJA EKRANU LOGOWANIA I UPRAWNIEŃ ROOTA
# ==========================================================
show_progress 5 $TOTAL_STEPS "$MSG_PHASE_3"

log_info "Konfiguruję ekran logowania (LightDM)..."
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
        log_ok "Ekran logowania został skonfigurowany."
    else
        log_warn "Nie znaleziono pliku konfiguracyjnego LightDM GTK Greeter."
    fi
else
    log_warn "Nie znaleziono pliku login-wallpaper.png — pomijam tapetę ekranu logowania."
fi

if [ -d "$SCRIPT_DIR/bleachbit" ]; then
    sudo mkdir -p /root/.config/bleachbit
    sudo cp -af "$SCRIPT_DIR/bleachbit/." /root/.config/bleachbit/
    log_ok "Skopiowano konfigurację BleachBit."
else
    log_warn "Folder $SCRIPT_DIR/bleachbit nie istnieje — pomijam."
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
