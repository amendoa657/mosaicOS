#!/usr/bin/env bash
# Liga ou desliga o Mosaic OS (este shell) no lugar do ii, sem mexer em nenhum
# arquivo do Hyprland: troca a variável qsConfig em tempo real (atalhos e scripts
# passam a chamar o shell certo) e reinicia o Quickshell com a outra config.
# Ao sair e entrar de novo na sessão, volta o ii (variables.lua manda).
#
#   mosaic-os.sh ligar      Mosaic OS
#   mosaic-os.sh desligar   volta para o ii
set -euo pipefail

case "${1:-}" in
  ligar) alvo=mosaic ;;
  desligar) alvo=ii ;;
  *) echo "uso: $0 ligar|desligar" >&2; exit 1 ;;
esac

hyprctl eval "hl.env(\"qsConfig\", \"$alvo\")" >/dev/null
pkill -x qs || true
sleep 0.5
hyprctl dispatch "hl.dsp.exec_cmd(\"qs -c $alvo\")" >/dev/null
echo "Shell agora: $alvo"
