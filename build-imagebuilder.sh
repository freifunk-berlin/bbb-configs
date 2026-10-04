#!/bin/bash
#
# Build an OpenWrt ImageBuilder from a local OpenWrt tree which contains all
# packages of the given hosts. Use it to build images with patched or
# additional packages, see DEVELOPER.md.

set -euo pipefail

usage() {
	cat <<EOF
Usage: $0 [-o <package-dir>]... [-n] <openwrt-dir> <hostname>...

  -o <package-dir>  use the package in this directory instead of the one
                    from the feeds, can be given several times
  -n                only write the OpenWrt .config, don't build

All hosts have to use the same OpenWrt target.
EOF
	exit 1
}

die() {
	echo "Error: $*" >&2
	exit 1
}

overrides=()
build=1
while getopts "o:nh" opt; do
	case "$opt" in
	o) overrides+=("$(realpath "$OPTARG")") ;;
	n) build=0 ;;
	*) usage ;;
	esac
done
shift $((OPTIND - 1))
[ $# -ge 2 ] || usage

openwrt=$(realpath "$1")
shift
hosts=("$@")
bbb=$(dirname "$(realpath "$0")")

[ -x "$openwrt/scripts/feeds" ] || die "$openwrt is not an OpenWrt tree"

echo "Collecting the packages of ${hosts[*]}"
limit=$(
	IFS=,
	echo "${hosts[*]}"
)
(cd "$bbb" && ansible-playbook play.yml --limit "$limit" --tags config >/dev/null) ||
	die "rendering the configs failed, run: ansible-playbook play.yml --limit $limit --tags config"

target=
profiles=()
packages=()
for host in "${hosts[@]}"; do
	json="$bbb/tmp/images/$host.json"
	[ -f "$json" ] || die "unknown host $host"

	host_target=$(jq -r '.target' "$json")
	[ -z "$target" ] || [ "$target" = "$host_target" ] ||
		die "$host uses target $host_target, the other hosts $target"
	target=$host_target

	profiles+=("$(jq -r '.override_target // .model' "$json")")
	mapfile -t -O "${#packages[@]}" packages < <(jq -r '.packages[] | select(startswith("-") | not)' "$json")
done
mapfile -t profiles < <(printf '%s\n' "${profiles[@]}" | sort -u)
mapfile -t packages < <(printf '%s\n' "${packages[@]}" | sort -u)

board=${target%/*}
subtarget=${target#*/}

cd "$openwrt"

./scripts/feeds update -i -a >/dev/null 2>&1 || die "updating the feed index failed"
./scripts/feeds install -a >/dev/null 2>&1 || die "installing the feed packages failed"

for dir in "${overrides[@]}"; do
	[ -f "$dir/Makefile" ] || die "$dir is not a package directory"
	name=$(basename "$dir")
	echo "Using $name from $dir"
	./scripts/feeds uninstall "$name" >/dev/null 2>&1 || true
	mkdir -p package/bbb-override
	ln -sfn "$dir" "package/bbb-override/$name"
done

# keep a config which was not written by this script
if [ -f .config ] && ! cmp -s .config tmp/.config-bbb-imagebuilder; then
	backup=".config.backup-$(date +%Y%m%d-%H%M%S)"
	cp .config "$backup"
	echo "Saved the old OpenWrt config to $openwrt/$backup"
fi

write_config() {
	{
		echo "CONFIG_TARGET_${board}=y"
		echo "CONFIG_TARGET_${board}_${subtarget}=y"
		if [ "${#profiles[@]}" -eq 1 ]; then
			echo "CONFIG_TARGET_${board}_${subtarget}_DEVICE_${profiles[0]}=y"
		else
			echo "CONFIG_TARGET_MULTI_PROFILE=y"
			for profile in "${profiles[@]}"; do
				echo "CONFIG_TARGET_DEVICE_${board}_${subtarget}_DEVICE_${profile}=y"
			done
		fi
		# contains all built packages and uses no remote repositories
		echo "CONFIG_IB=y"
		echo "CONFIG_IB_STANDALONE=y"
		for package in "${packages[@]}"; do
			echo "CONFIG_PACKAGE_${package}=m"
		done
	} >.config
	make defconfig >/dev/null 2>&1 || die "make defconfig failed in $openwrt"
}

# Print what is missing to get all wanted packages selected: the variants
# of virtual packages like "ip" and dependencies which are not selected
# automatically. Prints "!<package>" if a package can't be selected at all.
missing_packages() {
	python3 - "$@" <<'PYTHON'
import re
import sys

wanted = sys.argv[1:]
depends = {}
provides = {}
name = None
for line in open("tmp/.packageinfo", errors="replace"):
    if line.startswith("Package: "):
        name = line.split()[1]
        depends[name] = []
    elif name and line.startswith("Depends: "):
        for dep in line.split()[1:]:
            if dep[0] not in "+@!":
                depends[name].append(dep.split(":")[-1])
    elif name and line.startswith("Provides: "):
        for virtual in line.split()[1:]:
            provides.setdefault(virtual.lstrip("@"), []).append(name)

selected = set(re.findall(r"^CONFIG_PACKAGE_(\S+)=[ym]$", open(".config").read(), re.M))


def is_selected(package):
    return package in selected or any(p in selected for p in provides.get(package, []))


for package in wanted:
    if is_selected(package):
        continue
    more = [d for d in depends.get(package, []) if not is_selected(d)]
    if package not in depends:
        more = provides.get(package, [])
    more = [m for m in more if m not in wanted]
    print("\n".join(more) if more else "!" + package)
PYTHON
}

select_packages() {
	write_config
	while true; do
		mapfile -t more < <(missing_packages "${packages[@]}" | sort -u)
		[ "${#more[@]}" -gt 0 ] || break

		mapfile -t unknown < <(printf '%s\n' "${more[@]}" | sed -n 's/^!//p')
		[ "${#unknown[@]}" -eq 0 ] ||
			die "these packages can't be selected in $openwrt, check its feeds: ${unknown[*]}"

		packages+=("${more[@]}")
		write_config
	done
	cp .config tmp/.config-bbb-imagebuilder
}

# Print the runtime dependencies of the selected packages which are not
# available. Packages can have dependencies the build system doesn't know
# (EXTRA_DEPENDS), they are only found in the built packages.
missing_runtime_depends() {
	find bin/packages "bin/targets/$target/packages" -name '*.apk' -print0 |
		xargs -0 -n1 staging_dir/host/bin/apk adbdump 2>/dev/null |
		python3 -c '
import re
import sys

selected = set(re.findall(r"^CONFIG_PACKAGE_(\S+)=[ym]$", open(".config").read(), re.M))
available = set(selected)
wanted = set()
name = section = None
for line in sys.stdin:
    if line.startswith("  name: "):
        name = line.split()[1]
        # an old kernel module which is not selected does not fit the kernel
        if name in selected or not name.startswith("kmod-"):
            available.add(name)
    elif re.match(r"  (depends|provides):", line):
        section = line.split(":")[0].strip()
    elif section and line.startswith("    - "):
        entry = re.split(r"[<>=~]", line[6:].strip())[0]
        if section == "depends" and name in selected:
            wanted.add(entry)
        elif section == "provides" and name in available:
            available.add(entry)
    else:
        section = None
print("\n".join(sorted(n for n in wanted - available if not n.startswith("!"))))
'
}

# runtime dependencies found by earlier runs, to select them right away
extra_cache=tmp/bbb-imagebuilder-extra-packages
write_config
if [ -f "$extra_cache" ]; then
	while read -r package; do
		if grep -q "^Package: $package\$" tmp/.packageinfo; then
			packages+=("$package")
		fi
	done <"$extra_cache"
fi
extra=()

select_packages

for profile in "${profiles[@]}"; do
	grep -q "DEVICE_${profile}=y$" .config || die "unknown device profile $profile"
done

echo "Selected ${#packages[@]} packages for ${profiles[*]} ($target)"
[ "$build" -eq 1 ] || exit 0

previous=
while true; do
	make -j"$(nproc)" || die "the build failed, for details run: make -C $openwrt -j1 V=s"

	mapfile -t more < <(missing_runtime_depends)
	if [ "${#more[@]}" -eq 0 ] || [ -z "${more[0]}" ]; then
		break
	fi
	[ "${more[*]}" != "$previous" ] || die "can't build these runtime dependencies: ${more[*]}"
	previous="${more[*]}"

	echo "Adding the runtime dependencies ${more[*]}"
	packages+=("${more[@]}")
	extra+=("${more[@]}")
	select_packages
done
if [ "${#extra[@]}" -gt 0 ]; then
	printf '%s\n' "${extra[@]}" >>"$extra_cache"
	sort -u -o "$extra_cache" "$extra_cache"
fi

imagebuilder=$(find "bin/targets/$target" -maxdepth 1 -name 'openwrt-imagebuilder-*.tar.zst' -printf '%T@ %p\n' |
	sort -n | tail -1 | cut -d' ' -f2-)
[ -n "$imagebuilder" ] || die "no ImageBuilder found in bin/targets/$target"

cat <<EOF

Built $openwrt/$imagebuilder

Set this for the hosts and build the images as usual:

    imagebuilder: "$openwrt/$imagebuilder"
    imagebuilder_standalone: true
EOF
