# Netcore N60 Pro High-Power ImmortalWrt Builder

This is a small build wrapper for producing **only** a high-power Netcore
N60 Pro (`netcore_n60-pro`) ImmortalWrt firmware image.

The OpenWrt/ImmortalWrt source is not stored in this repository. GitHub Actions
checks out the selected upstream revision (the latest
`openwrt-24.10-6.6` branch by default), installs the build dependencies, builds
the single device target, and uploads the resulting `sysupgrade` image as an
artifact.

Upstream project:
<https://github.com/padavanonly/immortalwrt-mt798x-6.6>

## What it builds

- Target: MediaTek / Filogic
- Device: Netcore N60 Pro
- Release image: `netcore-n60pro-<upstream-version>.bin`
  (currently `netcore-n60pro-24.10.bin`)
- Wireless stack: MediaTek `mt_wifi` with `mtwifi-cfg` and LuCI support
- RF profile: `mt7975-ipailna-high-power.config` (`iPAiLNA`, AX6000 SKU)

RF template:
<https://github.com/padavanonly/immortalwrt-mt798x-6.6/blob/openwrt-24.10-6.6/defconfig/mt7975-ipailna-high-power.config>

The build script rejects a configuration that selects more than one device.
It also rejects a build where the high-power `iPAiLNA` option, MT7986 ADIE
profile, or `kmod-mt_wifi` package was dropped.

The target and package selections live in
[`configs/n60pro-high-power.config`](configs/n60pro-high-power.config). The
RF options are copied from the selected upstream
`defconfig/mt7975-ipailna-high-power.config` during the build, so the exact
driver feature set stays aligned with the selected upstream revision.
The template filename mentions MT7975, but its contents select the MT7976
ADIE type; this project follows the template contents rather than the
filename.

The build workspace applies a small compatibility patch to the N60 Pro image
recipe. It removes the stock `kmod-mt7915e`, `kmod-mt7986-firmware`, and
`mt7986-wo-firmware` package tokens so the radio is handled by `mt_wifi`
instead of competing with the open-source `mt76` stack. USB, automount, and
other non-wireless device packages remain unchanged.

## Build on GitHub

1. Create a new repository in your GitHub account and push this directory to it.
2. Open the **Actions** tab and enable workflows if GitHub asks you to.
3. Select **Build and publish Netcore N60 Pro high-power firmware**.
4. Click **Run workflow**.
5. When the job finishes, the firmware is published automatically as a
   GitHub Release.

The artifact contains the firmware, `SHA256SUMS`, the resolved `build.config`,
the source high-power template, the package compatibility patch, and
`BUILD_INFO.txt` with the exact upstream commit used for the build.

The Release version is read from the upstream `include/version.mk`. For the
current upstream branch this produces Release tag `v24.10` and the only Release
asset `netcore-n60pro-24.10.bin`. The Actions artifact still keeps the
diagnostic files, but they are not uploaded to the Release.

The workflow is manual-only. Pushing code, branches, or tags does not start it;
use the Actions page to start a build. A successful manual build publishes the
Release automatically.

The workflow runs on `ubuntu-22.04`, has a six-hour timeout, and can be
triggered only manually from the Actions page.
It removes unused preinstalled runner toolchains before building because
OpenWrt is larger than the runner's normal 14 GB working space. If repeated
builds hit a disk limit, use a larger or self-hosted runner.

GitHub-hosted standard runners are free for public repositories. A private
repository uses the account's Actions minutes and storage quota.

By default, the workflow tracks the latest `openwrt-24.10-6.6` branch, so an
upstream update can be built by manually running the workflow again. Enter
`pinned` in the `source_ref` input to use the known-good commit recorded in
[`upstream.env`](upstream.env), or enter any branch, tag, or commit for a
one-off build. The chosen upstream commit is written to the workflow summary.

## Publish a release

Start the workflow manually after pushing the repository:

**Actions → Build and publish Netcore N60 Pro high-power firmware → Run workflow**

The workflow creates or updates Release `v24.10` automatically. If that
Release already exists, all existing Release assets are removed and only
`netcore-n60pro-24.10.bin` is uploaded. The workflow requires repository
`contents: write` permission for this step.

## Flashing caution

This project produces a `sysupgrade` image. The upstream device recipe does
not define a `factory` image for the N60 Pro, so this repository does not
provide a one-step image for the stock Netcore web interface.

This is a vendor high-power RF profile. It changes the PA/LNA calibration
profile and can increase heat, power consumption, interference, and radio
emissions. Make sure the physical PA/LNA variant and regional radio
regulations match your hardware before using it. A profile intended for a
different RF board revision may produce poor performance or damage the
radio, so back up calibration data first.

Before flashing:

- Verify that the router is exactly a Netcore **N60 Pro**, not an N60.
- Confirm the installed bootloader and flash layout.
- Back up the original firmware and calibration data.
- Do not flash an image built for a different revision or device.

## Local build

Use a case-sensitive Linux filesystem. Install the dependencies listed in the
workflow, check out the pinned upstream source, then run:

```bash
bash scripts/build-n60pro-high-power.sh /path/to/immortalwrt-mt798x-6.6 .
```

The built files are copied to `dist/`.

## Updating upstream

The workflow can build a newer upstream revision without editing this
project. After a successful build, update `UPSTREAM_PINNED_REF` in
[`upstream.env`](upstream.env) to record a new known-good commit that still
contains:

- `target/linux/mediatek/dts/mt7986a-netcore-n60-pro.dts`
- `define Device/netcore_n60-pro` in
  `target/linux/mediatek/image/filogic.mk`
- `defconfig/mt7975-ipailna-high-power.config`

The build script checks all three before starting.

## Notes

This is an unofficial build wrapper. It is not affiliated with Netcore,
OpenWrt, ImmortalWrt, or the upstream repository maintainer. The upstream
source and firmware components remain subject to their own licenses and
usage terms.
