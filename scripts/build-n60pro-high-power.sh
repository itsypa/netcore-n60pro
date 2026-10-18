#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
	echo "Usage: $0 <openwrt-source-dir> <project-dir>" >&2
	exit 64
fi

SOURCE_DIR="$(readlink -f "$1")"
PROJECT_DIR="$(readlink -f "$2")"
CONFIG_FILE="$PROJECT_DIR/configs/n60pro-high-power.config"
HIGH_POWER_TEMPLATE="$SOURCE_DIR/defconfig/mt7975-ipailna-high-power.config"
PATCH_SCRIPT="$PROJECT_DIR/scripts/apply-n60pro-high-power-patch.py"
EXPECTED_DEVICE="CONFIG_TARGET_mediatek_filogic_DEVICE_netcore_n60-pro=y"
JOBS="${JOBS:-4}"
DIST_DIR="$PROJECT_DIR/dist"

log() {
	printf '\n==> %s\n' "$*"
}

resolve_upstream_version() {
	local version=""

	if [ -f "$SOURCE_DIR/include/version.mk" ]; then
		version="$(sed -n 's/.*,\([0-9][0-9.]*\)-SNAPSHOT.*/\1/p' \
			"$SOURCE_DIR/include/version.mk" | head -n 1)"
	fi

	if [ -z "$version" ]; then
		echo "Could not resolve the upstream major.minor version" >&2
		return 1
	fi

	printf '%s\n' "$version"
}

retry() {
	"$@" && return 0
	sleep 5
	"$@" && return 0
	sleep 5
	"$@"
}

command -v make >/dev/null 2>&1 || {
	echo "make is required" >&2
	exit 69
}

command -v python3 >/dev/null 2>&1 || {
	echo "python3 is required" >&2
	exit 69
}

[ -d "$SOURCE_DIR" ] || {
	echo "Source directory not found: $SOURCE_DIR" >&2
	exit 66
}

[ -f "$CONFIG_FILE" ] || {
	echo "Config file not found: $CONFIG_FILE" >&2
	exit 66
}

[ -f "$HIGH_POWER_TEMPLATE" ] || {
	echo "High-power defconfig not found: $HIGH_POWER_TEMPLATE" >&2
	exit 66
}

[ -f "$PATCH_SCRIPT" ] || {
	echo "High-power package patch not found: $PATCH_SCRIPT" >&2
	exit 66
}

log "Checking that the selected upstream contains N60 Pro support"
[ -f "$SOURCE_DIR/target/linux/mediatek/dts/mt7986a-netcore-n60-pro.dts" ] || {
	echo "N60 Pro DTS is missing from the selected upstream revision" >&2
	exit 65
}
grep -q 'define Device/netcore_n60-pro' \
	"$SOURCE_DIR/target/linux/mediatek/image/filogic.mk" || {
	echo "N60 Pro image recipe is missing from the selected upstream revision" >&2
	exit 65
}

log "Switching the N60 Pro image recipe to mt_wifi-only wireless packages"
python3 "$PATCH_SCRIPT" \
	"$SOURCE_DIR/target/linux/mediatek/image/filogic.mk"

log "Updating package feeds"
cd "$SOURCE_DIR"
retry ./scripts/feeds update -a
retry ./scripts/feeds install -a

log "Selecting the single N60 Pro high-power target"
if [ -z "${VERSION:-}" ]; then
	VERSION="$(resolve_upstream_version)"
fi

if ! printf '%s\n' "$VERSION" | grep -Eq '^[0-9A-Za-z._-]+$'; then
	echo "Invalid upstream version: $VERSION" >&2
	exit 65
fi

log "Building N60 Pro high-power version $VERSION"
cp -f "$CONFIG_FILE" .config

{
	printf '\n# High-power RF options from mt7975-ipailna-high-power.config\n'
	awk '/^#? ?CONFIG_(MTK_|WARP_)|^CONFIG_first_card_name/' \
		"$HIGH_POWER_TEMPLATE"
} >> .config

make defconfig

grep -qx "$EXPECTED_DEVICE" .config || {
	echo "The N60 Pro device was not selected in .config" >&2
	exit 65
}

grep -qx 'CONFIG_MTK_FIRST_IF_IPAILNA=y' .config || {
	echo "The iPAiLNA high-power RF option was not applied" >&2
	exit 65
}

grep -qx 'CONFIG_MTK_WIFI_ADIE_TYPE="mt7976"' .config || {
	echo "The MT7986 ADIE type from the high-power template was not applied" >&2
	exit 65
}

grep -qx 'CONFIG_PACKAGE_kmod-mt_wifi=y' .config || {
	echo "The MediaTek mt_wifi driver was not selected" >&2
	exit 65
}

grep -qx 'CONFIG_PACKAGE_mtwifi-cfg=y' .config || {
	echo "The MediaTek mtwifi-cfg package was not selected" >&2
	exit 65
}

grep -qx 'CONFIG_PACKAGE_luci-app-mtwifi-cfg=y' .config || {
	echo "The LuCI mt_wifi configuration package was not selected" >&2
	exit 65
}

enabled_devices="$({
	grep -E '^CONFIG_TARGET_(DEVICE_)?mediatek_filogic_DEVICE_.*=y$' .config || true
} | wc -l | tr -d '[:space:]')"

if [ "$enabled_devices" -ne 1 ]; then
	echo "Expected exactly one device target, found $enabled_devices" >&2
	grep -E '^CONFIG_TARGET_(DEVICE_)?mediatek_filogic_DEVICE_.*=y$' .config >&2 || true
	exit 65
fi

log "Downloading package sources"
retry make download -j"$JOBS"

log "Building firmware"
make -j"$JOBS" V=s 2>&1 | tee "$PROJECT_DIR/build.log"

log "Collecting the sysupgrade image"
image="$(
	find "$SOURCE_DIR/bin/targets/mediatek/filogic" \
		-maxdepth 1 -type f -name '*netcore_n60-pro*sysupgrade*' \
		-print -quit
)"

if [ -z "$image" ]; then
	echo "No N60 Pro sysupgrade image was produced" >&2
	exit 66
fi

image_extension="${image##*.}"
if [ "$image_extension" != "bin" ]; then
	echo "Expected a .bin sysupgrade image, got .$image_extension" >&2
	exit 65
fi
artifact_image="netcore-n60pro-${VERSION}.bin"

mkdir -p "$DIST_DIR"
cp -f "$image" "$DIST_DIR/$artifact_image"
cp -f .config "$DIST_DIR/build.config"
cp -f "$HIGH_POWER_TEMPLATE" "$DIST_DIR/high-power-template.config"
cp -f "$PATCH_SCRIPT" "$DIST_DIR/apply-n60pro-high-power-patch.py"
printf '%s\n' "$VERSION" > "$DIST_DIR/VERSION.txt"

if git rev-parse HEAD >/dev/null 2>&1; then
	upstream_commit="$(git rev-parse HEAD)"
else
	upstream_commit="unknown"
fi

{
	printf 'device=netcore_n60-pro\n'
	printf 'version=%s\n' "$VERSION"
	printf 'release_tag=v%s\n' "$VERSION"
	printf 'wireless_profile=mt7975-ipailna-high-power\n'
	printf 'wireless_packages=mt_wifi-only\n'
	printf 'upstream_repository=padavanonly/immortalwrt-mt798x-6.6\n'
	printf 'upstream_commit=%s\n' "$upstream_commit"
	printf 'build_date_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
	printf 'image=%s\n' "$artifact_image"
} > "$DIST_DIR/BUILD_INFO.txt"

(
	cd "$DIST_DIR"
	sha256sum \
		"$artifact_image" \
		build.config \
		high-power-template.config \
		apply-n60pro-high-power-patch.py \
		VERSION.txt \
		BUILD_INFO.txt \
		> SHA256SUMS
)

log "Build complete"
ls -lh "$DIST_DIR"
