# 🚀 XFCE Environment Automatic Configuration Script

A post-deployment script (`install.sh`) that automates the process of customizing a Linux system (with a specific focus on the **XFCE** desktop environment and the **LightDM** login manager). It copies configuration files, sets themes, icons, wallpapers, and the user's avatar.

---

## 📋 Table of Contents
1. [Script Features](#-script-features)
2. [Required Directory Structure](#-required-directory-structure)
3. [Prerequisites](#-prerequisites)
4. [How to Run](#-how-to-run)
5. [⚠️ Important Notes](#️-important-notes)

---

## ✨ Script Features

### 🎨 Visual Configuration (User)
* **Copying existing configuration:** Moves the `.config`, `.local/share`, `.icons`, and `.themes` folders directly to your home directory (`~`).
* **Automatic wallpaper change:** Copies the `tapeta.jpg` file to the `~/Dokumenty` (Documents) folder and applies it as the XFCE desktop background using `xfconf-query`.
* **Path update (Username Fix):** Searches through `.conf`, `.json`, and `.ini` files, automatically replacing the hardcoded path of the old user (`bartek`) with your current system username.
* **User avatar:** Sets the `piwo.png` file as your official system avatar (via integration with `AccountsService`).

### ⚙️ System Configuration (Sudo)
* **Login screen (LightDM):** Copies `login-wallpaper.png` to a secure system location and sets it as the greeter screen background in `lightdm-gtk-greeter.conf`.
* **Sudo session keep-alive:** The script asks for the administrator password only once at the beginning, and then automatically refreshes permissions in the background so the process doesn't stall during execution.

---

## 📁 Required Directory Structure

For the script to work correctly, make sure the following files and folders are located in the same directory before running it:

```text
.
├── install.sh              # This script
├── tapeta.jpg              # User desktop wallpaper
├── piwo.png                # User avatar (AccountsService)
├── login-wallpaper.png     # LightDM login screen wallpaper
├── .config/                # (Optional) Your application configuration files
├── .local/share/           # (Optional) Local application data, fonts, etc.
├── .icons/                 # (Optional) Your icon packs
└── .themes/                # (Optional) Your GTK/XFWM themes
🔍 Prerequisites
A Linux-based operating system (XFCE environment recommended).

LightDM login manager with lightdm-gtk-greeter installed.

A user with privileges to use the sudo command.

🚀 How to Run
1. Clone the repository or download the files
Bash
git clone [https://github.com/bartko4321/xfce-config.git](https://github.com/bartko4321/xfce-config.git)
cd xfce-config
2. Grant execution privileges to the script
Bash
chmod +x install.sh
3. Run the script
⚠️ IMPORTANT: The script must be run as a regular user (NOT as root/sudo). The script will ask for the administrator password at the beginning to configure temporary privileges.

Bash
./install.sh
If you like this project, leave a star! ⭐

Support account number: 06291000060000000005038936

⚠️ Important Notes
🚨 AUTOREBOOT: After successfully completing all configurations, the script will automatically reboot the computer (systemctl reboot) so that all changes (including LightDM and AccountsService) are correctly loaded. Save your work before running the script!
