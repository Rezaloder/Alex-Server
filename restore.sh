#!/usr/bin/env bash
# Restore a backup made by backup.sh onto a NEW server.
# Order on the new server:
#   1) copy the repo + your .env, run ./install.sh   (installs packages, firewall, panel)
#   2) sudo ./restore.sh alex-backup-XXXX.tar.gz      (brings back users, keys, usage)
#   3) point your DNS record (SHARE_ADDR / DOMAIN) to the new IP
# Users keep their configs: same keys, same UUIDs, same domain.
set -euo pipefail
[[ $(id -u) -eq 0 ]] || { echo "run as root (sudo)"; exit 1; }
B=${1:?usage: restore.sh <alex-backup-*.tar.gz>}
[[ -f "$B" ]] || { echo "no such file: $B"; exit 1; }
[[ -x /usr/local/x-ui/x-ui ]] || { echo "run ./install.sh first"; exit 1; }

echo "stopping services"
systemctl stop x-ui wg-quick@wg-out wg-quick@wg-clients xl2tpd 2>/dev/null || true

SAFE=/root/pre-restore-$(date +%Y%m%d-%H%M).tar.gz
tar -C / -czf "$SAFE" etc/x-ui/x-ui.db etc/alex-server etc/wireguard etc/ppp/chap-secrets etc/ipsec.secrets 2>/dev/null || true
echo "current state saved to $SAFE"

tar -C / -xzf "$B"
chmod 600 /etc/x-ui/x-ui.db /etc/ppp/chap-secrets /etc/ipsec.secrets
chmod -R go-rwx /etc/alex-server /etc/wireguard

echo "starting services"
systemctl restart alex-routing
systemctl start wg-quick@wg-clients x-ui
[[ -f /etc/wireguard/wg-out.conf ]] && systemctl start wg-quick@wg-out
systemctl restart strongswan-starter xl2tpd
ipsec rereadsecrets >/dev/null 2>&1 || true
echo "restored. Now update your DNS record to this server's IP and run: sudo alex-status"
