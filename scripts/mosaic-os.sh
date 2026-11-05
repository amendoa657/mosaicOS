#!/usr/bin/env bash
# Troca o shell do Quickshell entre o Mosaic OS e o ii, e lembra da escolha.
# - A escolha fica em ~/.local/state/mosaic-os/shell. O ~/.config/hypr/custom/env.lua
#   lê esse arquivo ao iniciar ou recarregar o Hyprland, então reiniciar o PC
#   mantém o shell escolhido.
# - "alternar" olha qual qs está rodando de verdade (não só a variável), para
#   nunca ficar fora de sincronia se algo reiniciar o qs por fora.
# - Também serve para só reiniciar o shell escolhido: mosaic-os.sh reiniciar.
#
#   mosaic-os.sh ligar       Mosaic OS
#   mosaic-os.sh desligar    volta para o ii
#   mosaic-os.sh alternar    um ou outro (Ctrl+Super+M)
#   mosaic-os.sh reiniciar   reinicia o shell salvo, sem trocar
set -uo pipefail

ESTADO="$HOME/.local/state/mosaic-os/shell"

# o shell rodando agora: o "-c X" do processo qs; senão o salvo; senão ii
atual() {
  local rodando
  rodando=$(pgrep -ax qs | sed -n 's/.* -c \([a-zA-Z0-9_-]*\).*/\1/p' | head -1)
  [ -n "$rodando" ] && { echo "$rodando"; return; }
  [ -f "$ESTADO" ] && { cat "$ESTADO"; return; }
  echo ii
}

case "${1:-}" in
  alternar) [ "$(atual)" = mosaic ] && alvo=ii || alvo=mosaic ;;
  ligar) alvo=mosaic ;;
  desligar) alvo=ii ;;
  reiniciar) alvo=$(cat "$ESTADO" 2>/dev/null || echo ii) ;;
  *) echo "uso: $0 ligar|desligar|alternar|reiniciar" >&2; exit 1 ;;
esac

mkdir -p "$(dirname "$ESTADO")"
echo "$alvo" > "$ESTADO"

hyprctl eval "hl.env(\"qsConfig\", \"$alvo\")" >/dev/null
# O vidro do Mosaic OS (hypr/mosaic.lua) entra ou sai com a config recarregada
hyprctl reload config-only >/dev/null
pkill -x qs
# espera o qs antigo sair de vez (senão o novo briga com ele pelas notificações)
for _ in $(seq 20); do pgrep -x qs >/dev/null || break; sleep 0.1; done
hyprctl dispatch "hl.dsp.exec_cmd(\"qs -c $alvo\")" >/dev/null
echo "Shell agora: $alvo"
