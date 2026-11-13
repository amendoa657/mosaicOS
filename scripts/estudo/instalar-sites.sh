#!/bin/sh
# Mosaic OS study mode: the site block needs root once, to install
#   /usr/local/libexec/mosaic-estudo-hosts   the helper that edits /etc/hosts
#   /etc/sudoers.d/mosaic-estudo             lets your user run it (and only it) without a password
# Run it yourself:   sudo ~/.config/quickshell/mosaic/scripts/estudo/instalar-sites.sh
# To undo:           sudo ~/.config/quickshell/mosaic/scripts/estudo/instalar-sites.sh --remover
set -eu
[ "$(id -u)" = 0 ] || { echo "Rode com sudo." >&2; exit 1; }
USER_NAME=${SUDO_USER:?rode com sudo, a partir do seu usuário}
HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
HELPER=/usr/local/libexec/mosaic-estudo-hosts
RULE=/etc/sudoers.d/mosaic-estudo

if [ "${1:-}" = "--remover" ]; then
    [ -x "$HELPER" ] && "$HELPER" off
    rm -f "$HELPER" "$RULE"
    echo "Bloqueio de sites removido."
    exit 0
fi

install -D -o root -g root -m 755 "$HERE/mosaic-estudo-hosts" "$HELPER"
tmp=$(mktemp)
echo "$USER_NAME ALL=(root) NOPASSWD: $HELPER on, $HELPER off" > "$tmp"
visudo -cf "$tmp" >/dev/null
install -o root -g root -m 440 "$tmp" "$RULE"
rm -f "$tmp"
echo "Pronto: o modo Estudo já pode bloquear sites."
