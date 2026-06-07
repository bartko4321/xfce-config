# 🚀 Skrypt Automatycznej Konfiguracji Środowiska XFCE

Skrypt powdrożeniowy (`install.sh`), który automatyzuje proces personalizacji systemu Linux (ze szczególnym uwzględnieniem środowiska **XFCE** oraz menedżera logowania **LightDM**). Kopiuje pliki konfiguracyjne, ustawia motywy, ikony, tapety oraz avatar użytkownika.

---

## 📋 Spis treści
1. [Funkcje skryptu](#-funkcje-skryptu)
2. [Wymagana struktura katalogów](#-wymagana-struktura-katalogów)
3. [Wymagania wstępne](#-wymagania-wstępne)
4. [Instrukcja uruchomienia](#-instrukcja-uruchomienia)
5. [⚠️ Ważne uwagi](#️-ważne-uwagi)

---

## ✨ Funkcje skryptu

### 🎨 Konfiguracja wizualna (Użytkownik)
* **Kopiowanie dotychczasowej konfiguracji:** Przenosi foldery `.config`, `.local/share`, `.icons` oraz `.themes` bezpośrednio do Twojego katalogu domowego (`~`).
* **Automatyczna zmiana tapety:** Kopiuje plik `tapeta.jpg` do folderu `~/Dokumenty` i aplikuje go jako tło pulpitu XFCE za pomocą `xfconf-query`.
* **Aktualizacja ścieżek (Username Fix):** Przeszukuje pliki `.conf`, `.json` oraz `.ini`, automatycznie podmieniając zakodowaną na sztywno ścieżkę starego użytkownika (`bartek`) na Twoją aktualną nazwę systemową.
* **Avatar użytkownika:** Ustawia plik `piwo.png` jako Twój oficjalny avatar w systemie (poprzez integrację z `AccountsService`).

### ⚙️ Konfiguracja systemowa (Sudo)
* **Ekran logowania (LightDM):** Kopiuje `login-wallpaper.png` do bezpiecznej lokalizacji systemowej i ustawia go jako tło ekranu powitalnego w `lightdm-gtk-greeter.conf`.
* **Podtrzymanie sesji sudo:** Skrypt prosi o hasło administratora tylko raz na początku, a następnie automatycznie odświeża uprawnienia w tle, aby proces nie zaciął się podczas pracy.

---

## 📁 Wymagana struktura katalogów

Aby skrypt zadziałał poprawnie, przed jego uruchomieniem upewnij się, że w tym samym katalogu znajdują się odpowiednie pliki i foldery:

```text
.
├── install.sh              # Ten skrypt
├── tapeta.jpg              # Tapeta na pulpit użytkownika
├── piwo.png                # Avatar użytkownika (AccountsService)
├── login-wallpaper.png     # Tapeta na ekran logowania LightDM
├── .config/                # (Opcjonalnie) Twoje pliki konfiguracyjne aplikacji
├── .local/share/           # (Opcjonalnie) Dane lokalne aplikacji, czcionki itp.
├── .icons/                 # (Opcjonalnie) Twoje paczki ikon
└── .themes/                # (Opcjonalnie) Twoje motywy GTK/XFWM
```

---

## 🔍 Wymagania wstępne

* System operacyjny z rodziny Linux (rekomendowane środowisko **XFCE**).
* Menedżer logowania **LightDM** wraz z zainstalowanym `lightdm-gtk-greeter`.
* Użytkownik z uprawnieniami do używania polecenia `sudo`.

---

## 🚀 Instrukcja uruchomienia

### 1. Sklonuj repozytorium lub pobierz pliki
```bash
git clone https://github.com/bartko4321/xfce-config.git
cd xfce-config
```

### 2. Nadaj uprawnienia do uruchomienia skryptu
```bash
chmod +x install.sh
```

### 3. Uruchom skrypt
> ⚠️ **WAŻNE:** Skrypt należy uruchomić jako **zwykły użytkownik** (NIE jako root/sudo). Skrypt sam poprosi o hasło administratora na początku, aby skonfigurować tymczasowe uprawnienia.

```bash
./install.sh
```

---

Wsparcie numer konta: 06291000060000000005038936

## ⚠️ Ważne uwagi

> 🚨 **AUTOREBOOT:** Po pomyślnym zakończeniu wszystkich konfiguracji, skrypt automatycznie wykona restart komputera (`systemctl reboot`), aby wszystkie zmiany (w tym LightDM i AccountsService) zostały poprawnie załadowane. Zapisz swoją pracę przed uruchomieniem skryptu!
