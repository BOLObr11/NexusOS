#!/usr/bin/env bash
set -euo pipefail

WORK_ROOT="${1:-/work/nexusos}"
OUT_DIR="${2:-/repo/release}"
PROFILE="$WORK_ROOT/profile"
ARCHISO_BASE="/usr/share/archiso/configs/releng"

log(){ printf '\n\033[1;36m[NexusOS]\033[0m %s\n' "$*"; }

if [[ $EUID -ne 0 ]]; then
  echo "Run as root inside an Arch Linux environment." >&2
  exit 1
fi

log "Preparing pacman and ArchISO"
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf || true
pacman -Syy --noconfirm
pacman -S --needed --noconfirm archiso git curl wget rsync reflector base-devel

rm -rf "$WORK_ROOT"
mkdir -p "$WORK_ROOT" "$OUT_DIR"
cp -a "$ARCHISO_BASE" "$PROFILE"

# Enable multilib in the ISO build profile.
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' "$PROFILE/pacman.conf" || true

# Branding / profile identity.
sed -i 's/^iso_name=.*/iso_name="nexusos"/' "$PROFILE/profiledef.sh"
sed -i 's/^iso_label=.*/iso_label="NEXUSOS_2026"/' "$PROFILE/profiledef.sh"
sed -i 's/^iso_publisher=.*/iso_publisher="NexusOS Project <https:\/\/github.com\/BOLObr11\/NexusOS>"/' "$PROFILE/profiledef.sh"
sed -i 's/^iso_application=.*/iso_application="NexusOS Gaming Desktop Live\/Install"/' "$PROFILE/profiledef.sh"
sed -i 's/^install_dir=.*/install_dir="nexusos"/' "$PROFILE/profiledef.sh"

# Prefer Zen kernel in the live image.
sed -i '/^linux$/d' "$PROFILE/packages.x86_64"

add_pkg(){
  local p="$1"
  if pacman -Si "$p" >/dev/null 2>&1; then
    grep -qxF "$p" "$PROFILE/packages.x86_64" || echo "$p" >> "$PROFILE/packages.x86_64"
  else
    echo "[skip] package not found in enabled repos: $p"
  fi
}

log "Adding desktop, gaming, drivers and everyday applications"
packages=(
  linux-zen linux-zen-headers linux-lts linux-lts-headers
  amd-ucode intel-ucode linux-firmware
  sudo nano vim git curl wget reflector rsync openssh bash-completion
  networkmanager network-manager-applet bluez bluez-utils firewalld
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber alsa-utils
  plasma-desktop plasma-workspace plasma-nm plasma-pa powerdevil systemsettings
  plasma-systemmonitor plasma-firewall plasma-browser-integration plasma-x11-session
  sddm sddm-kcm dolphin konsole ark kate spectacle okular gwenview
  breeze breeze-gtk kde-gtk-config xdg-desktop-portal xdg-desktop-portal-kde
  xorg-xwayland polkit-kde-agent kwallet-pam kscreen
  noto-fonts noto-fonts-emoji ttf-liberation ttf-dejavu ttf-jetbrains-mono inter-font
  papirus-icon-theme
  mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-intel lib32-vulkan-intel
  vulkan-icd-loader lib32-vulkan-icd-loader libva-mesa-driver mesa-vdpau
  intel-media-driver libva-utils mesa-utils vulkan-tools
  nvidia-open-dkms nvidia-utils lib32-nvidia-utils nvidia-settings egl-wayland
  steam steam-devices lutris gamemode lib32-gamemode mangohud lib32-mangohud
  gamescope vkbasalt lib32-vkbasalt wine-staging winetricks protonup-qt prismlauncher
  obs-studio discord lact corectrl ananicy-cpp power-profiles-daemon gpu-screen-recorder
  firefox chromium libreoffice-fresh vlc mpv telegram-desktop qbittorrent
  flatpak discover packagekit-qt6 fwupd cups cups-pdf print-manager sane simple-scan
  btrfs-progs snapper snap-pac grub grub-btrfs os-prober efibootmgr dosfstools
  ntfs-3g exfatprogs zram-generator plymouth archinstall
  retroarch libretro-core-info pcsx2 rpcs3 dolphin-emu ppsspp cemu duckstation
  kio-admin kio-extras kcalc filelight partitionmanager
)
for p in "${packages[@]}"; do add_pkg "$p"; done

# Calamares is added if the enabled repository set provides it. A branded graphical
# fallback installer remains available through archinstall when it is not present.
add_pkg calamares

A="$PROFILE/airootfs"
mkdir -p \
  "$A/etc/sddm.conf.d" \
  "$A/etc/sysctl.d" \
  "$A/etc/modprobe.d" \
  "$A/etc/systemd/system/multi-user.target.wants" \
  "$A/etc/systemd/system/graphical.target.wants" \
  "$A/etc/systemd/zram-generator.conf.d" \
  "$A/etc/skel/.config/autostart" \
  "$A/etc/skel/.config/MangoHud" \
  "$A/etc/skel/Desktop" \
  "$A/usr/local/bin" \
  "$A/usr/share/applications" \
  "$A/usr/share/backgrounds/nexusos" \
  "$A/usr/share/plymouth/themes/nexusos" \
  "$A/usr/share/nexusos"

cat > "$A/etc/os-release" <<'EOF'
NAME="NexusOS"
PRETTY_NAME="NexusOS Gaming 2026"
ID=nexusos
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;0;217;255"
HOME_URL="https://github.com/BOLObr11/NexusOS"
DOCUMENTATION_URL="https://github.com/BOLObr11/NexusOS"
SUPPORT_URL="https://github.com/BOLObr11/NexusOS/issues"
BUG_REPORT_URL="https://github.com/BOLObr11/NexusOS/issues"
LOGO=nexusos
EOF

cat > "$A/etc/hostname" <<'EOF'
nexusos-live
EOF

cat > "$A/etc/locale.conf" <<'EOF'
LANG=pt_BR.UTF-8
EOF
cat > "$A/etc/vconsole.conf" <<'EOF'
KEYMAP=br-abnt2
EOF
cat > "$A/etc/locale.gen" <<'EOF'
en_US.UTF-8 UTF-8
pt_BR.UTF-8 UTF-8
es_ES.UTF-8 UTF-8
EOF

cat > "$A/etc/sysctl.d/90-nexusos-gaming.conf" <<'EOF'
# NexusOS conservative gaming defaults.
vm.max_map_count=2147483642
vm.swappiness=10
vm.vfs_cache_pressure=50
fs.inotify.max_user_watches=1048576
fs.inotify.max_user_instances=1024
kernel.nmi_watchdog=0
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

cat > "$A/etc/modprobe.d/nvidia.conf" <<'EOF'
options nvidia_drm modeset=1 fbdev=1
EOF

cat > "$A/etc/systemd/zram-generator.conf.d/nexusos.conf" <<'EOF'
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
swap-priority = 100
EOF

cat > "$A/etc/sddm.conf.d/nexusos.conf" <<'EOF'
[Autologin]
User=gamer
Session=plasma
Relogin=true

[General]
DisplayServer=wayland
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[Theme]
Current=breeze
EOF

cat > "$A/usr/local/bin/nexus-live-setup" <<'EOF'
#!/usr/bin/env bash
set -e
if ! id gamer >/dev/null 2>&1; then
  useradd -m -G wheel,audio,video,input,storage -s /bin/bash gamer
  passwd -d gamer >/dev/null 2>&1 || true
fi
install -d -m 0700 -o gamer -g gamer /home/gamer/.config
chown -R gamer:gamer /home/gamer
cat >/etc/sudoers.d/00_nexus_live <<'SUDO'
%wheel ALL=(ALL:ALL) NOPASSWD: ALL
SUDO
chmod 440 /etc/sudoers.d/00_nexus_live
locale-gen || true
systemctl enable --now NetworkManager.service >/dev/null 2>&1 || true
systemctl enable --now bluetooth.service >/dev/null 2>&1 || true
systemctl enable --now firewalld.service >/dev/null 2>&1 || true
systemctl enable --now power-profiles-daemon.service >/dev/null 2>&1 || true
systemctl enable --now lactd.service >/dev/null 2>&1 || true
# Enable Flathub without downloading optional apps automatically.
if command -v flatpak >/dev/null 2>&1; then
  flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
fi
EOF
chmod +x "$A/usr/local/bin/nexus-live-setup"

cat > "$A/etc/systemd/system/nexus-live-setup.service" <<'EOF'
[Unit]
Description=Prepare NexusOS live desktop
Before=sddm.service display-manager.service
After=systemd-user-sessions.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nexus-live-setup
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
ln -sf ../nexus-live-setup.service "$A/etc/systemd/system/multi-user.target.wants/nexus-live-setup.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service "$A/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/sddm.service "$A/etc/systemd/system/graphical.target.wants/sddm.service"
ln -sf /usr/lib/systemd/system/graphical.target "$A/etc/systemd/system/default.target"

cat > "$A/usr/local/bin/nexus-install" <<'EOF'
#!/usr/bin/env bash
set -e
if command -v calamares >/dev/null 2>&1; then
  exec pkexec calamares
fi
kdialog --title "NexusOS Installer" --warningyesno "Calamares is not available in this build. Open the official Arch guided installer as the fallback?" || exit 0
exec konsole -e sudo archinstall
EOF
chmod +x "$A/usr/local/bin/nexus-install"

cat > "$A/usr/share/applications/nexus-install.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Install NexusOS
Comment=Install NexusOS on this computer
Exec=/usr/local/bin/nexus-install
Icon=system-software-install
Terminal=false
Categories=System;
EOF
cp "$A/usr/share/applications/nexus-install.desktop" "$A/etc/skel/Desktop/Install-NexusOS.desktop"
chmod +x "$A/etc/skel/Desktop/Install-NexusOS.desktop"

cat > "$A/usr/local/bin/nexus-control-center" <<'EOF'
#!/usr/bin/env bash
set -u
while true; do
  choice=$(kdialog --title "NexusOS Control Center" --menu "Gaming system controls" \
    update "Update system" \
    drivers "GPU / Vulkan information" \
    profile "Performance profile" \
    overlay "MangoHud overlay" \
    snapshot "Create BTRFS snapshot" \
    shader "Clear Steam shader cache" \
    flatpak "Install optional gaming apps" \
    kernel "Installed kernels" \
    quit "Close") || exit 0
  case "$choice" in
    update) konsole -e bash -lc 'sudo snapper create --description "Before NexusOS update" 2>/dev/null || true; sudo pacman -Syu; echo; read -p "Press Enter to close"' ;;
    drivers) konsole -e bash -lc 'lspci -k | grep -EA4 "VGA|3D|Display"; echo; vulkaninfo --summary 2>/dev/null | head -80 || true; echo; read -p "Press Enter to close"' ;;
    profile) p=$(kdialog --menu "Choose profile" balanced "Balanced" performance "Performance" power-saver "Battery") || continue; powerprofilesctl set "$p" 2>/dev/null || true ;;
    overlay) kdialog --msgbox "For Steam games use: mangohud %command%\nGlobal config: ~/.config/MangoHud/MangoHud.conf" ;;
    snapshot) sudo snapper create --description "Manual NexusOS snapshot" && kdialog --msgbox "Snapshot created." || kdialog --error "Snapshot is available after an installed BTRFS system is configured." ;;
    shader) if kdialog --warningyesno "Clear Steam shader cache for this user?"; then rm -rf "$HOME/.local/share/Steam/steamapps/shadercache"/* 2>/dev/null || true; fi ;;
    flatpak) /usr/local/bin/nexus-optional-apps ;;
    kernel) kdialog --msgbox "$(pacman -Q | grep -E '^linux(|-zen|-lts|-cachyos)' || true)" ;;
    quit) exit 0 ;;
  esac
done
EOF
chmod +x "$A/usr/local/bin/nexus-control-center"

cat > "$A/usr/share/applications/nexus-control-center.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=NexusOS Control Center
Comment=Gaming, update and hardware controls
Exec=/usr/local/bin/nexus-control-center
Icon=preferences-system
Terminal=false
Categories=Settings;System;
EOF

cat > "$A/usr/local/bin/nexus-optional-apps" <<'EOF'
#!/usr/bin/env bash
set -e
apps=$(kdialog --title "NexusOS Optional Apps" --checklist "Choose apps to install from Flathub" \
  heroic "Heroic Games Launcher" on \
  bottles "Bottles" on \
  spotify "Spotify" off \
  peazip "PeaZip" off) || exit 0
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
for app in $apps; do
  case "$app" in
    heroic) flatpak install -y --user flathub com.heroicgameslauncher.hgl ;;
    bottles) flatpak install -y --user flathub com.usebottles.bottles ;;
    spotify) flatpak install -y --user flathub com.spotify.Client ;;
    peazip) flatpak install -y --user flathub io.github.peazip.PeaZip ;;
  esac
done
kdialog --msgbox "Selected applications are installed."
EOF
chmod +x "$A/usr/local/bin/nexus-optional-apps"

cat > "$A/usr/local/bin/nexus-welcome" <<'EOF'
#!/usr/bin/env bash
set -e
marker="$HOME/.config/nexusos-welcome-done"
[[ -e "$marker" ]] && exit 0
kdialog --title "Welcome to NexusOS" --msgbox "Welcome to NexusOS Gaming.\n\nKDE Plasma 6 • Wayland • Steam • Lutris • Gamescope • MangoHud • OBS\n\nUse the NexusOS Control Center for gaming and system controls."
if kdialog --title "NexusOS" --yesno "Install Heroic and Bottles now? Internet connection required."; then
  /usr/local/bin/nexus-optional-apps || true
fi
touch "$marker"
EOF
chmod +x "$A/usr/local/bin/nexus-welcome"

cat > "$A/etc/skel/.config/autostart/nexus-welcome.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=NexusOS Welcome
Exec=/usr/local/bin/nexus-welcome
OnlyShowIn=KDE;
X-KDE-autostart-after=panel
EOF

cat > "$A/etc/skel/.config/MangoHud/MangoHud.conf" <<'EOF'
fps
frametime
frame_timing=1
cpu_stats
cpu_temp
gpu_stats
gpu_temp
vram
ram
wine
vulkan_driver
resolution
refresh_rate
position=top-left
font_size=22
background_alpha=0.35
round_corners=10
toggle_hud=Shift_R+F12
EOF

cat > "$A/etc/skel/.config/kglobalshortcutsrc" <<'EOF'
[org.kde.dolphin.desktop]
_k_friendly_name=Dolphin
new-window=Meta+E,Meta+E,Dolphin

[org.kde.konsole.desktop]
_k_friendly_name=Konsole
new-window=Ctrl+Alt+T,Ctrl+Alt+T,Konsole

[org.kde.spectacle.desktop]
_k_friendly_name=Spectacle
RectangularRegion=Meta+Shift+S,Meta+Shift+S,Capture Rectangular Region
EOF

cat > "$A/etc/skel/.config/kwinrc" <<'EOF'
[Compositing]
LatencyPolicy=Low

[Effect-overview]
BorderActivate=9

[Plugins]
blurEnabled=true
contrastEnabled=true
diminactiveEnabled=false
overviewEnabled=true
slideEnabled=true
wobblywindowsEnabled=false

[Wayland]
InputMethod[$e]=
EOF

cat > "$A/etc/skel/.config/kdeglobals" <<'EOF'
[General]
ColorScheme=BreezeDark
Name=NexusOS
font=Inter,10,-1,5,50,0,0,0,0,0
fixed=JetBrains Mono,10,-1,5,50,0,0,0,0,0

[Icons]
Theme=Papirus-Dark

[KDE]
SingleClick=false
EOF

cat > "$A/usr/share/backgrounds/nexusos/nexusos.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
<defs>
 <radialGradient id="g" cx="52%" cy="45%" r="70%"><stop offset="0" stop-color="#13263b"/><stop offset="0.55" stop-color="#090d15"/><stop offset="1" stop-color="#030508"/></radialGradient>
 <filter id="glow"><feGaussianBlur stdDeviation="14" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
</defs>
<rect width="1920" height="1080" fill="url(#g)"/>
<g transform="translate(960 470)" fill="none" stroke="#00d9ff" stroke-width="14" stroke-linecap="round" stroke-linejoin="round" filter="url(#glow)">
 <path d="M0 -190 L165 -95 L165 95 L0 190 L-165 95 L-165 -95 Z" opacity=".7"/>
 <path d="M-95 105 L0 -115 L95 105 M-58 25 H58"/>
</g>
<text x="960" y="760" text-anchor="middle" fill="#f5f7fa" font-family="sans-serif" font-weight="700" font-size="58" letter-spacing="14">NEXUSOS</text>
<text x="960" y="815" text-anchor="middle" fill="#8da2b7" font-family="sans-serif" font-size="22" letter-spacing="5">PLAY WITHOUT LIMITS</text>
</svg>
EOF

cat > "$A/usr/local/bin/nexus-apply-look" <<'EOF'
#!/usr/bin/env bash
wall=/usr/share/backgrounds/nexusos/nexusos.svg
plasma-apply-wallpaperimage "$wall" >/dev/null 2>&1 || true
kwriteconfig6 --file kdeglobals --group General --key ColorScheme BreezeDark
kwriteconfig6 --file kdeglobals --group Icons --key Theme Papirus-Dark
EOF
chmod +x "$A/usr/local/bin/nexus-apply-look"
cat > "$A/etc/skel/.config/autostart/nexus-look.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=NexusOS Look
Exec=/usr/local/bin/nexus-apply-look
OnlyShowIn=KDE;
X-KDE-autostart-phase=1
EOF

# Plymouth theme: intentionally simple and fast.
cat > "$A/usr/share/plymouth/themes/nexusos/nexusos.plymouth" <<'EOF'
[Plymouth Theme]
Name=NexusOS
Description=NexusOS glowing boot splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/nexusos
ScriptFile=/usr/share/plymouth/themes/nexusos/nexusos.script
EOF
cat > "$A/usr/share/plymouth/themes/nexusos/nexusos.script" <<'EOF'
Window.SetBackgroundTopColor(0.01,0.02,0.03);
Window.SetBackgroundBottomColor(0.01,0.02,0.03);
text = Image.Text("NEXUSOS", 0.0, 0.85, 1.0);
sprite = Sprite(text);
sprite.SetX(Window.GetWidth()/2 - text.GetWidth()/2);
sprite.SetY(Window.GetHeight()/2 - text.GetHeight()/2);
progress = Image.Text("GAMING SYSTEM", 0.0, 0.55, 0.7);
p = Sprite(progress);
p.SetX(Window.GetWidth()/2 - progress.GetWidth()/2);
p.SetY(Window.GetHeight()/2 + 55);
EOF

# Game-mode session. It starts Steam through Gamescope; Desktop Mode simply logs out
# and lets SDDM choose Plasma again.
cat > "$A/usr/local/bin/nexus-game-mode" <<'EOF'
#!/usr/bin/env bash
export STEAM_GAMESCOPE_VRR_SUPPORTED=1
export ENABLE_GAMESCOPE_WSI=1
exec gamescope -e -f -- steam -gamepadui -steamos3
EOF
chmod +x "$A/usr/local/bin/nexus-game-mode"
mkdir -p "$A/usr/share/wayland-sessions"
cat > "$A/usr/share/wayland-sessions/nexus-game.desktop" <<'EOF'
[Desktop Entry]
Name=NexusOS Game Mode
Comment=Console-like Steam Gamescope session
Exec=/usr/local/bin/nexus-game-mode
Type=Application
DesktopNames=gamescope
EOF

# Default GameMode profile.
mkdir -p "$A/etc/gamemode.ini.d"
cat > "$A/etc/gamemode.ini" <<'EOF'
[general]
renice=5
ioprio=0
softrealtime=auto
inhibit_screensaver=1

[filter]
whitelist=steam
whitelist=lutris

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
amd_performance_level=high
EOF

# Right-click helper for EXE files. Dolphin exposes this as a service menu.
mkdir -p "$A/usr/share/kio/servicemenus"
cat > "$A/usr/share/kio/servicemenus/nexus-wine.desktop" <<'EOF'
[Desktop Entry]
Type=Service
MimeType=application/x-ms-dos-executable;application/x-msdownload;
Actions=RunWithWine;
X-KDE-ServiceTypes=KonqPopupMenu/Plugin

[Desktop Action RunWithWine]
Name=Run with Wine
Icon=wine
Exec=wine %f
EOF

# Ensure the standard Arch live root autologin is disabled in favor of SDDM where possible.
rm -f "$A/etc/systemd/system/getty@tty1.service.d/autologin.conf" 2>/dev/null || true

# Make the live boot menu visibly branded without replacing ArchISO's tested boot logic.
for f in "$PROFILE"/syslinux/*.cfg "$PROFILE"/grub/*.cfg; do
  [[ -f "$f" ]] || continue
  sed -i 's/Arch Linux/NexusOS Gaming/g; s/Arch Linux install medium/NexusOS Live\/Install/g' "$f" || true
done

# Permissions for generated scripts and desktop launcher.
find "$A/usr/local/bin" -type f -exec chmod 0755 {} +
chmod 0755 "$A/etc/skel/Desktop/Install-NexusOS.desktop"

log "Final package count: $(grep -Ev '^(#|$)' "$PROFILE/packages.x86_64" | wc -l)"
log "Building hybrid BIOS/UEFI ISO"
rm -rf "$WORK_ROOT/work" "$WORK_ROOT/out"
mkdir -p "$WORK_ROOT/work" "$WORK_ROOT/out"
mkarchiso -v -w "$WORK_ROOT/work" -o "$WORK_ROOT/out" "$PROFILE"

ISO=$(find "$WORK_ROOT/out" -maxdepth 1 -type f -name '*.iso' -print -quit)
if [[ -z "${ISO:-}" ]]; then
  echo "No ISO was produced." >&2
  exit 1
fi

FINAL="$OUT_DIR/NexusOS-Gaming-2026.09-x86_64.iso"
cp -f "$ISO" "$FINAL"
sha256sum "$FINAL" > "$FINAL.sha256"

log "ISO complete"
ls -lh "$FINAL" "$FINAL.sha256"
