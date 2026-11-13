#!/bin/sh
# Mosaic OS study mode: installs the service for your user (no root).
#   scripts/estudo/instalar.sh
# The service is its own systemd user unit, apart from the shell, so restarting
# Quickshell does not turn the mode off. It comes back by itself when killed
# (Restart=always) and refuses a plain `systemctl --user stop` (RefuseManualStop).
# The site block is separate and needs sudo once: instalar-sites.sh.
set -eu
HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
UNIT="$HOME/.config/systemd/user/mosaic-estudo.service"
STATE="$HOME/.local/state/mosaic-os/estudo"

mkdir -p "$(dirname "$UNIT")" "$STATE" "$HOME/.config/mosaic-os/estudo"
# the first day is free: an empty snapshot, so the first setup can be redone at will
[ -f "$STATE/vigente.json" ] || printf '{"dia": "%s", "agenda": {}}\n' "$(date +%F)" > "$STATE/vigente.json"

cat > "$UNIT" <<UNIT
[Unit]
Description=Mosaic OS: modo Estudo
RefuseManualStop=yes

[Service]
ExecStart=/usr/bin/python3 $HERE/estudo.py daemon
Restart=always
RestartSec=2
Nice=10

[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now mosaic-estudo.service
echo "Modo Estudo instalado. Configure em: qs -c mosaic ipc call mosaicSettings estudo"
