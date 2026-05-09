#!/bin/bash
#
# collect-packages.sh
#
# Collects all packages used across all bbb-configs hosts and generates
# a complete OpenWrt build-system .config per target architecture.
#
# The generated .config files contain:
#   - Target/subtarget selection  (CONFIG_TARGET_*)
#   - Imagebuilder output flag    (CONFIG_IB=y)
#   - All packages for that target (CONFIG_PACKAGE_*=y)
#
# Usage:
#   ./collect-packages.sh [--skip-ansible]
#
# Output:
#   tmp/packages/<arch>-<subtarget>.config
#
# Workflow:
#   cp tmp/packages/mediatek-filogic.config openwrt/.config
#   cd openwrt && make defconfig && make -j$(nproc)
#
# Note: packages from the Falter feed (bird2-babelpatch, bgpdisco, falter-*)
# are not in the upstream OpenWrt repo. Add the feed before building:
#   echo 'src-git falter https://github.com/freifunk-berlin/falter-packages' \
#     >> feeds.conf.default
#   ./scripts/feeds update -a && ./scripts/feeds install -a

set -euo pipefail

IMAGES_DIR="tmp/images"
OUTPUT_DIR="tmp/packages"

# ---------------------------------------------------------------------------
# Step 1: run ansible to produce per-host JSON dumps in tmp/images/
# ---------------------------------------------------------------------------

if [[ "${1:-}" != "--skip-ansible" ]]; then
	echo "Running ansible to collect host configurations..."
	echo "(pass --skip-ansible to reuse existing tmp/images/*.json)"
	echo ""
	ansible-playbook play.yml
	echo ""
fi

# ---------------------------------------------------------------------------
# Step 2: verify JSON dumps exist
# ---------------------------------------------------------------------------

shopt -s nullglob
json_files=("$IMAGES_DIR"/*.json)
shopt -u nullglob

if [[ ${#json_files[@]} -eq 0 ]]; then
	echo "Error: no JSON files found in $IMAGES_DIR"
	echo "Run without --skip-ansible or run 'ansible-playbook play.yml' first."
	exit 1
fi

echo "Found ${#json_files[@]} host JSON files in $IMAGES_DIR"
echo ""

# ---------------------------------------------------------------------------
# Step 3: generate one complete .config per OpenWrt target
# ---------------------------------------------------------------------------

mkdir -p "$OUTPUT_DIR"

mapfile -t targets < <(jq -r '.target' "${json_files[@]}" | sort -u)

for target in "${targets[@]}"; do
	safe_target="${target//\//-}"
	config_file="$OUTPUT_DIR/${safe_target}.config"

	# Split "arch/subtarget" into its two parts
	arch="${target%%/*}"
	subtarget="${target##*/}"

	{
		# --- Target selection ---
		echo "# Target: $target"
		echo "CONFIG_TARGET_${arch}=y"
		echo "CONFIG_TARGET_${arch}_${subtarget}=y"
		echo ""

		# --- Build the imagebuilder tarball as output ---
		echo "# Build imagebuilder"
		echo "CONFIG_IB=y"
		echo ""

		# --- Packages ---
		echo "# Packages"
		jq -r --arg target "$target" \
			'select(.target == $target) | .packages[] | select(startswith("-") | not)' \
			"${json_files[@]}" |
			sort -u |
			awk '{print "CONFIG_PACKAGE_" $1 "=y"}'

	} >"$config_file"

	pkg_count=$(grep -c '^CONFIG_PACKAGE_' "$config_file")
	echo "  $target  ->  $config_file  ($pkg_count packages)"
done

# ---------------------------------------------------------------------------
# Step 4: usage instructions
# ---------------------------------------------------------------------------

echo ""
echo "To build an imagebuilder for a target:"
echo ""
echo "  1. Clone OpenWrt source matching the version in group_vars/all/imageprofile.yml:"
echo "       git clone https://git.openwrt.org/openwrt/openwrt.git && cd openwrt"
echo ""
echo "  2. Add the Falter feed (bird2-babelpatch, bgpdisco, falter-*, ...):"
echo "       echo 'src-git falter https://github.com/freifunk-berlin/falter-packages' \\"
echo "         >> feeds.conf.default"
echo "       ./scripts/feeds update -a && ./scripts/feeds install -a"
echo ""
echo "  3. Copy the config for your target, e.g. mediatek/filogic:"
echo "       cp $(pwd)/$OUTPUT_DIR/mediatek-filogic.config .config"
echo ""
echo "  4. Expand and build:"
echo "       make defconfig && make -j\$(nproc)"
echo ""
echo "  The imagebuilder tarball ends up in:"
echo "       bin/targets/<arch>/<subtarget>/openwrt-imagebuilder-*.tar.*"
echo ""
echo "  To use it in bbb-configs, host the tarball on a local HTTP server and"
echo "  set openwrt_mirror in group_vars/all/imageprofile.yml to point at it."
