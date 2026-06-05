#!/bin/bash

# --- Kolory ---
INFO='\033[0;34m'
SUCCESS='\033[0;32m'
ERROR='\033[0;31m'
WARN='\033[0;33m'
NC='\033[0m'

log_info()  { echo -e "${INFO}==> $*${NC}"; }
log_ok()    { echo -e "${SUCCESS}==> $*${NC}"; }
log_err()   { echo -e "${ERROR}==> BŁĄD: $*${NC}" >&2; }
log_warn()  { echo -e "${WARN}==> UWAGA: $*${NC}"; }

# Pułapka błędów
trap 'log_warn "Błąd w linii $LINENO. Polecenie: $BASH_COMMAND — kontynuuję"' ERR

# --- Zmienne ---
CURRENT_USER=$(whoami)
OLD_USER_PLACEHOLDER="bartek"
TAPETA_PATH="/home/$CURRENT_USER/Dokumenty/tapeta.jpg"
LOGIN_WALLPAPER_PATH="/usr/share/backgrounds/custom/login-wallpaper.png"

# Upewnij się, że skrypt NIE jest uruchamiany jako root
if [[ "$EUID" -eq 0 ]]; then
    log_err "Nie uruchamiaj skryptu jako root. Uruchom jako zwykły użytkownik z dostępem do sudo."
    exit 1
fi

# Zdobądź uprawnienia sudo na początku, aby skrypt nie zawiesił się później czekając na hasło
log_info "Sprawdzam i autoryzuję uprawnienia sudo..."
sudo -v || { log_err "Brak uprawnień sudo. Skrypt wymaga sudo do konfiguracji systemu."; exit 1; }

# Utrzymaj uprawnienia sudo w tle dla długich instalacji
(while true; do sudo -v; sleep 60; kill -0 "$$" || exit; done) 2>/dev/null &

# ==========================================================
# 1. KONFIGURACJA WIZUALNA (BEZ SUDO)
# ==========================================================
log_info "Rozpoczynam konfigurację wizualną użytkownika..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Kopiowanie plików konfiguracyjnych
[[ -d "$SCRIPT_DIR/.config" ]] && \
    [[ "$(realpath "$SCRIPT_DIR/.config")" != "$(realpath ~/.config)" ]] && \
    cp -af "$SCRIPT_DIR/.config/." ~/.config/

[[ -d "$SCRIPT_DIR/.local/share" ]] && \
    [[ "$(realpath "$SCRIPT_DIR/.local/share")" != "$(realpath ~/.local/share)" ]] && \
    cp -af "$SCRIPT_DIR/.local/share/." ~/.local/share/

[[ -d "$SCRIPT_DIR/.icons" ]] && \
    [[ "$(realpath "$SCRIPT_DIR/.icons")" != "$(realpath ~/.icons)" ]] && \
    cp -af "$SCRIPT_DIR/.icons/." ~/.icons/

[[ -d "$SCRIPT_DIR/.themes" ]] && \
    [[ "$(realpath "$SCRIPT_DIR/.themes")" != "$(realpath ~/.themes)" ]] && \
    cp -af "$SCRIPT_DIR/.themes/." ~/.themes/

# Kopiowanie tapety pulpitu (z poprawką na brakujący folder)
if [[ -f "$SCRIPT_DIR/tapeta.jpg" ]] && [[ "$(realpath "$SCRIPT_DIR/tapeta.jpg")" != "$(realpath "$TAPETA_PATH" 2>/dev/null)" ]]; then
    mkdir -p "$(dirname "$TAPETA_PATH")"
    cp -af "$SCRIPT_DIR/tapeta.jpg" "$TAPETA_PATH"
fi

# --- ZMIANA TAPETY W XFCE ---
if command -v xfconf-query >/dev/null 2>&1; then
    log_info "Ustawiam tapetę w systemie XFCE..."

    # Pobieramy właściwości last-image; jeśli brak — pomijamy bez błędu
    DESKTOP_PROPS=$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep "last-image" || true)
    if [[ -z "$DESKTOP_PROPS" ]]; then
        log_warn "Brak właściwości last-image w xfce4-desktop — pomijam ustawienie tapety."
    else
        while IFS= read -r prop; do
            xfconf-query -c xfce4-desktop -p "$prop" -s "$TAPETA_PATH" 2>/dev/null || \
                log_warn "Nie udało się ustawić: $prop"
        done <<< "$DESKTOP_PROPS"
        log_ok "Tapeta XFCE została zaktualizowana."
    fi
else
    log_warn "xfconf-query nie znaleziony – pomijam automatyczną zmianę tapety."
fi

# Zamiana ścieżek w plikach tekstowych (.config) z obsługą spacji w nazwach plików
if [[ "$OLD_USER_PLACEHOLDER" != "$CURRENT_USER" ]]; then
    log_info "Aktualizuję ścieżki użytkownika w plikach konfiguracyjnych..."
    grep -rlZ --include="*.conf" --include="*.json" --include="*.ini" \
        "/home/$OLD_USER_PLACEHOLDER" ~/.config 2>/dev/null \
        | xargs -0 -r sed -i "s|/home/$OLD_USER_PLACEHOLDER|/home/$CURRENT_USER|g"
fi

# --- ZMIANA AVATARA UŻYTKOWNIKA ---
if [[ -f "$SCRIPT_DIR/piwo.png" ]]; then
    log_info "Ustawiam avatar użytkownika..."
    AVATAR_DEST="/var/lib/AccountsService/icons/$CURRENT_USER"
    sudo cp -af "$SCRIPT_DIR/piwo.png" "$AVATAR_DEST"
    sudo chmod 644 "$AVATAR_DEST"

    # Rejestracja avatara w AccountsService
    ACCOUNTS_FILE="/var/lib/AccountsService/users/$CURRENT_USER"
    if [[ -f "$ACCOUNTS_FILE" ]]; then
        if sudo grep -q "^Icon=" "$ACCOUNTS_FILE"; then
            sudo sed -i "s|^Icon=.*|Icon=$AVATAR_DEST|" "$ACCOUNTS_FILE"
        else
            # Jeśli jest sekcja [User], dopisz. Jeśli nie ma, dopisz na koniec.
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
# 2. KONFIGURACJA SYSTEMOWA (SUDO)
# ==========================================================
log_info "Konfiguruję ekran logowania (LightDM)..."

if [[ -f "$SCRIPT_DIR/login-wallpaper.png" ]]; then
    # 1. Kopiowanie tapety do zasobów systemowych
    sudo mkdir -p /usr/share/backgrounds/custom
    sudo cp -af "$SCRIPT_DIR/login-wallpaper.png" "$LOGIN_WALLPAPER_PATH"
    sudo chmod 644 "$LOGIN_WALLPAPER_PATH"

    # 2. Sprawdzenie czy zainstalowany jest LightDM GTK Greeter
    if [ -f /etc/lightdm/lightdm-gtk-greeter.conf ]; then
        log_info "Aktualizuję tło w lightdm-gtk-greeter.conf..."

        # Upewnij się, że sekcja [greeter] istnieje
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

log_ok "KONFIGURACJA ZAKOŃCZONA SUKCESEM!"
systemctl reboot
