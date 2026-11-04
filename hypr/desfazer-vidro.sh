#!/usr/bin/env bash
# Volta o Hyprland ao jeito de antes do vidro em mosaico: devolve os três
# arquivos originais (cópias de backup-20261104-1933) e troca o plugin de volta.
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"
cp "$AQUI/backup-20261104-1933/"{execs,rules,variables}.lua ~/.config/hypr/hyprland/
hyprctl plugin unload /home/amendoa/hyprglass-mosaic/hyprglass.so || true
hyprctl plugin load /home/amendoa/hyprglass/hyprglass.so
hyprctl reload config-only
echo "Hyprland de volta ao original."
