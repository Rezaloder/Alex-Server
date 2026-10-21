#!/usr/bin/env bash
# Full backup of everything needed to move this server:
# panel DB (users, usage, Reality keys), L2TP users + PSK, WireGuard keys,
# Alex Server state (.env, keys, WG user configs) and TLS certificates.
# Usage: sudo ./backup.sh [output-dir]      -> alex-backup-<date>.tar.gz
set -euo pipefail
[[ $(id -u) -eq 0 ]] || { echo "run as root (sudo)"; exit 1; }
OUT=${1:-/root}
STAMP=$(date +%Y%m%d-%H%M)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/etc/x-ui"
sqlite3 /etc/x-ui/x-ui.db ".backup '$TMP/etc/x-ui/x-ui.db'"   # consistent copy while running

paths=(/etc/alex-server /etc/wireguard /etc/ppp/chap-secrets /etc/ipsec.secrets)
[[ -d /root/cert ]] && paths+=(/root/cert)
[[ -d /root/.acme.sh ]] && paths+=(/root/.acme.sh)
tar -C / -cf "$TMP/files.tar" "${paths[@]#/}"
tar -C "$TMP" -rf "$TMP/files.tar" etc/x-ui/x-ui.db

umask 077
gzip -c "$TMP/files.tar" > "$OUT/alex-backup-$STAMP.tar.gz"
echo "backup written: $OUT/alex-backup-$STAMP.tar.gz"
echo "it contains secrets — copy it off the server and keep it private"
