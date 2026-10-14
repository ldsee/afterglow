# Afterglow

Maintenance builds of Asuswrt-Merlin 386 for the ASUS RT-AC68U.

The last official Merlin release for this router, 386.14_2 (November 2024), is no longer maintained. Afterglow applies fixes to that release and publishes builds.

Unofficial fork. Not affiliated with, endorsed or supported by Asuswrt-Merlin or ASUS.

For the RT-AC68U hardware revisions V1 to V3 only. Do not flash it on a V4: that revision needs a different image.

## Background

Since the DNS root zone moved to a new signing key (KSK-2024, key tag 38696), 386.14_2 can no longer validate DNSSEC. It only trusts the old key (20326), so with "Enable DNSSEC support" on, every lookup fails with SERVFAIL. Newer Merlin releases include the fix but do not support this hardware.

## Changes in 386.14_2-ag1

- Adds the KSK-2024 trust anchor to the dnsmasq configuration (`rc/services.c` and `trust-anchors.conf`), as upstream did in 3004.388.
- Version string suffixed with `-ag1`.

## Testing

| Check | Result |
| --- | --- |
| Patch applies to upstream and the firmware builds | Done |
| Image unpacks and reports version 386.14_2-ag1 | Done |
| dnsmasq from the image, run under qemu: old key only fails, both keys validate | Done |
| Boot and operation on an RT-AC68U | Not tested yet |

## Installation

1. Download the `.trx` from Releases and verify its SHA-256.
2. Back up the router settings (Administration > Restore/Save/Upload Setting).
3. Flash it under Administration > Firmware Upgrade.
4. Check DNS: `dig +dnssec iana.org @<router ip>` should return the `ad` flag.

To revert, flash the official 386.14_2. If the router does not boot after flashing, recover it with the ASUS Firmware Restoration tool.

### Without flashing

On stock 386.14_2, enable Administration > System > "Enable JFFS custom scripts and configs", then over ssh:

    echo 'trust-anchor=.,38696,8,2,683D2D0ACB8C9B712A1948B27F741219298D0A450D612C483AF444A4C0FB2B16' >> /jffs/configs/dnsmasq.conf.add
    service restart_dnsmasq

The digest is from <https://data.iana.org/root-anchors/root-anchors.xml>. Disabling DNSSEC also restores DNS, without validation.

## Building

Ubuntu 20.04 with about 30 GB of free disk space:

    bash build-rt-ac68u.sh

The script fetches the upstream source and toolchain at pinned revisions, applies `patches/`, sets the version from `VERSION` and runs the Merlin build. Output: `RT-AC68U_386.14_2-ag1.trx`.

`tests/dnssec-userland.sh` checks DNSSEC validation using the dnsmasq binary from a built image.

## Limitations

The RT-AC68U runs Linux 2.6.36 with closed Broadcom Wi-Fi and switch drivers. The kernel cannot be updated, and Afterglow does not change it. Do not expose the web interface or ssh to the internet, and disable UPnP if it is not needed.

## Planned

Updates for the network-facing services: dropbear, OpenVPN, miniupnpd, dnsmasq.

## Credits and licence

Based on [Asuswrt-Merlin](https://github.com/RMerl/asuswrt-merlin.ng) (`386_x`) by Eric Sauvageau, itself based on ASUSWRT by ASUSTeK, with toolchains from [am-toolchains](https://github.com/RMerl/am-toolchains).

Patches and scripts: GPL v2, see `LICENSE`. Built images also contain proprietary ASUS and Broadcom components, licensed only for use on ASUS devices. Provided without warranty.
