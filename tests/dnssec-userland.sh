#!/usr/bin/env bash
# Runs the dnsmasq from a built image under qemu-user and checks DNSSEC with the old
# root key only and with both keys. Needs network, qemu-user-static and dig.
#
#   bash tests/dnssec-userland.sh <rootfs>
#
# <rootfs> is the router's root filesystem: router/arm-uclibc/target in the build tree,
# or the unpacked squashfs from the .trx.
# Expected: cloudflare.com SERVFAIL with the old key only and NOERROR + ad flag with
# both; dnssec-failed.org (broken on purpose) is SERVFAIL either way.
set -u
T="${1:?usage: dnssec-userland.sh <rootfs>}"
command -v qemu-arm-static >/dev/null || { echo "need qemu-user-static"; exit 1; }
command -v dig >/dev/null || { echo "need dig (dnsutils)"; exit 1; }
OLD='trust-anchor=.,20326,8,2,E06D44B80B8F1D39A95C0B0D7C65D08458E880409BBC683457104237C7F8EC8D'
NEW='trust-anchor=.,38696,8,2,683D2D0ACB8C9B712A1948B27F741219298D0A450D612C483AF444A4C0FB2B16'

try() {   # name, trust-anchor lines
  cat > /tmp/dm-$1.conf <<CONF
port=5399
listen-address=127.0.0.1
bind-interfaces
no-resolv
no-hosts
server=1.1.1.1
server=9.9.9.9
dnssec
dnssec-check-unsigned
$2
CONF
  qemu-arm-static -L "$T" "$T/usr/sbin/dnsmasq" -k -C /tmp/dm-$1.conf --pid-file=/tmp/dm-$1.pid >/tmp/dm-$1.log 2>&1 &
  sleep 4
  echo "== $1: cloudflare.com"
  dig @127.0.0.1 -p 5399 cloudflare.com A +dnssec +time=8 +tries=1 | grep -E "status:|flags:"
  echo "== $1: dnssec-failed.org"
  dig @127.0.0.1 -p 5399 dnssec-failed.org A +time=8 +tries=1 | grep -E "status:"
  pkill -f "dm-$1.conf"; sleep 1
}

try old "$OLD"
try both "$OLD
$NEW"
