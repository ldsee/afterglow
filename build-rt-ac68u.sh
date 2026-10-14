#!/usr/bin/env bash
# Build Afterglow for the RT-AC68U on Ubuntu 20.04 (native, WSL2 or a VM).
# Follows the "Compile Firmware from source" page of the Asuswrt-Merlin wiki.
# Needs about 30 GB of disk and 1-2 hours.
#
#   bash build-rt-ac68u.sh [workdir]        (default workdir: ~/afterglow-build)
set -euo pipefail
WORK="${1:-$HOME/afterglow-build}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# upstream revisions this was built against
MERLIN_URL="${MERLIN_URL:-https://github.com/RMerl/asuswrt-merlin.ng}"
MERLIN_REF="${MERLIN_REF:-97d2d21ee1262a0e5a7618097ec60f70a8107a9d}"   # branch 386_x, 2025-02-23
TOOLCHAIN_URL="${TOOLCHAIN_URL:-https://github.com/RMerl/am-toolchains}"
TOOLCHAIN_REF="${TOOLCHAIN_REF:-d1af80e6b6686a4edc680386c09a8361453dd5c1}"

fetch_pinned() {   # dir url sha
  [ -d "$1/.git" ] || { git init -q "$1" && git -C "$1" remote add origin "$2"; }
  git -C "$1" fetch -q --depth 1 origin "$3"
  git -C "$1" checkout -q -f FETCH_HEAD
}

sudo dpkg --add-architecture i386
sudo apt-get update
echo "dash dash/sh boolean false" | sudo debconf-set-selections && sudo dpkg-reconfigure -f noninteractive dash
sudo apt-get install -y \
  autoconf automake autopoint bison build-essential bzip2 cmake curl flex g++ g++-multilib gawk gcc-multilib gettext git gperf intltool \
  libc6-dev-i386 libglib2.0-dev libgmp3-dev libltdl-dev liblzo2-dev libmpc-dev libmpfr-dev libncurses5-dev libproxy-dev libtool libtool-bin \
  libxml-parser-perl lib32z1-dev libc6-i386 libstdc++6:i386 make m4 patch pkg-config python3 rsync sed texinfo unzip uuid-dev wget xsltproc zlib1g-dev

# The old 4.5.3 ARM compiler needs 32-bit libelf, libmpfr.so.4 and libmpc.so.2.
# Ubuntu 20.04 only has the first, so the other two come from an older release.
sudo apt-get install -y libelf1:i386 libgmp10:i386 libmpfr6:i386 libmpc3:i386 zlib1g:i386
( cd /tmp && curl -sfLO http://old-releases.ubuntu.com/ubuntu/pool/main/m/mpfr4/libmpfr4_3.1.2-1_i386.deb \
  && curl -sfLO http://old-releases.ubuntu.com/ubuntu/pool/main/m/mpclib/libmpc2_0.9-4_i386.deb \
  && sudo dpkg -i --force-depends libmpfr4_3.1.2-1_i386.deb libmpc2_0.9-4_i386.deb ) \
  || sudo ln -sf /usr/lib/i386-linux-gnu/libmpc.so.3 /usr/lib/i386-linux-gnu/libmpc.so.2
sudo ldconfig

mkdir -p "$WORK" && cd "$WORK"
fetch_pinned am-toolchains "$TOOLCHAIN_URL" "$TOOLCHAIN_REF"
fetch_pinned asuswrt-merlin.ng "$MERLIN_URL" "$MERLIN_REF"
cd asuswrt-merlin.ng
for p in "$HERE"/patches/*.patch; do
  echo "applying $(basename "$p")"
  git apply --whitespace=nowarn "$p"
done
sed -i "s/^EXTENDNO=.*/EXTENDNO=$(cat "$HERE/VERSION")/" release/src-rt/version.conf

cd "$WORK"
rm -rf amng-build && mkdir amng-build && rsync -a --del asuswrt-merlin.ng/ amng-build
sudo ln -sfn "$WORK/am-toolchains/brcm-arm-sdk/hndtools-arm-linux-2.6.36-uclibc-4.5.3" /opt/brcm-arm
ln -sfn "$WORK/am-toolchains/brcm-arm-sdk" amng-build/release/src-rt-6.x.4708/toolchains
export PATH="$PATH:/opt/brcm-arm/bin"
cd amng-build/release/src-rt-6.x.4708
make rt-ac68u
echo "done, the image is in $WORK/amng-build/release/src-rt-6.x.4708/image/"
