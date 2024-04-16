#!/usr/bin/env bash
# shellcheck disable=SC2002
# shellcheck disable=SC2004
# shellcheck disable=SC2015

# TODO: check for podman version

function usage(){
  cat 1>&2 << "EOF"

Usage: ./vm.sh <location> [<imagedir>]

    location  - Name of a BBB location config file stored at location/<location>.yml.
    imagedir  - Image output directory of BBB-Configs, where *-generic-kernel.img
                and *-generic-ext4-rootfs.img images for <location> can be found.
                Default: ./tmp/build/<location>-core/bin/targets/x86/64

This script starts a Firecracker micro VM for a given BBB-Configs location's corerouter.
The VM starts very fast, doesn't need root permissions, and gives access to its console.
It exposes SSH/DNS/HTTPS and meshes over a Wireguard tunnel.

This VM is meant for development and debugging, and NOT for permanent deployment.

The VM location's corerouter must have `model: "x86-64"` and it needs registered
IP addresses, just like any regular location. To enable meshing over a tunnel,
you need to configure a network with `role: uplink`, as usual.

The only system requirement is Podman 4.x, since it allows us to operate without root
permissions and without touching the host's network settings. A Podman container with
Alpine Linux is started and its isolated user and network namespaces allow root operations
such as network configuration and VM management.

To create a new VM location, replace "myvm" with your own (see locations/pktpls.yml for a working example).

    vim locations/myvm.yml                          # Create your location config
    ansible-playbook play.yml -l 'myvm-*' -t image  # Build the image
    ./vm.sh myvm                                    # Start the VM

The forwarded ports can be used once the VM has booted ("device eth0 entered promiscuous mode").

    nslookup -port=8053 myvm-core.olsr localhost    # DNS is forwarded
    firefox https://localhost:8443                  # so is HTTPS
    ssh root@localhost -p 8022                      # and SSH

We can even mount the VM's rootfs to work on it directly.

    mkdir vmfs/
    sshfs -v -p 8022 root@localhost:/ vmfs/
    ls -l vmfs/
    umount vmfs/

To shut the VM down, kill it from the outside as Firecracker doesn't support `poweroff`.

    podman kill myvm

Be careful -- all changes are lost when the VM is stopped.

EOF
  exit 1
}

set -e
set -o pipefail
[ -n "$TRACE_VMSH" ] && set -x || true

[ -n "$1" ] && location="$1" || usage
host="$(cat "locations/$location.yml" | yq -r '.hosts[] | select(.role == "corerouter") | .hostname')"

[ -n "$2" ] && imgdir="$4" || imgdir="./tmp/build/$host/bin/targets/x86/64"

# get kernel and rootfs

vmdir="./tmp/vm/$host"
mkdir -p "$vmdir"

wget -nv -O "$vmdir/extract-vmlinux.sh" https://raw.githubusercontent.com/torvalds/linux/master/scripts/extract-vmlinux
chmod +x "$vmdir/extract-vmlinux.sh"

"$vmdir"/extract-vmlinux.sh "$imgdir"/openwrt-*-generic-kernel.bin > "$vmdir/vmlinux"

gunzip -c "$imgdir"/openwrt-*-generic-ext4-rootfs.img.gz > "$vmdir/rootfs.img"

# calculate mgmt IP addresses of container and VM

netmask() {
  local mask=$((0xffffffff << (32 - $1))); shift
  local ip
  for _ in 1 2 3 4; do
    ip=$((mask & 0xff))${ip:+.}$ip
    mask=$((mask >> 8))
  done
  echo "$ip"
}

nth_ip() {
  IFS=". /" read -r i1 i2 i3 i4 mask <<< "$1"
  IFS=" ." read -r m1 m2 m3 m4 <<< "$(netmask "$mask")"
  printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$(($2 + (i4 & m4)))"
}

mgmtnet="$(cat "locations/$location.yml" | yq -r '.networks[] | select(.role == "mgmt") | .prefix')"
vmipn="$(cat "locations/$location.yml" | yq -r '.networks[] | select(.role == "mgmt") | .assignments["'"$host"'"]')"
maxipn="$(cat "locations/$location.yml" | yq -r '.networks[] | select(.role == "mgmt") | .assignments | to_entries | max_by(.value) | .value')"
vmip="$(nth_ip "$mgmtnet" "$vmipn")"
cnip="$(nth_ip "$mgmtnet" "$(("$maxipn" + 1))")"

# firecracker definition of our openwrt VM
cat << EOF > "$vmdir/vmconfig.json"
{
  "machine-config": {
    "vcpu_count": 1,
    "mem_size_mib": 128,
    "smt": false
  },
  "boot-source": {
    "kernel_image_path": "./vmlinux",
    "boot_args": "ro console=ttyS0 noapic reboot=k panic=1 pci=off nomodules random.trust_cpu=on i8042.noaux"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "./rootfs.img",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "network-interfaces": [
    {
      "host_dev_name": "vmeth0",
      "iface_id": "eth0",
      "guest_mac": "02:fc:00:00:00:06"
    }
  ]
}
EOF

# entrypoint script of the surrounding podman container
cat << EOF > "$vmdir/entrypoint.sh"
#!/bin/sh

# while true ; do echo sleep 5 ; sleep 5 ; done

echo 'nameserver 10.0.2.3' > /etc/resolv.conf

ip tuntap add dev vmeth0 mode tap
ip link set up vmeth0
ip link add link vmeth0 name vmeth0.50 type vlan id 50
ip link set up vmeth0.50

ip link add link vmeth0 name vmeth0.42 type vlan id 42
ip link set up vmeth0.42
ip addr add $cnip dev vmeth0.42
ip route add $mgmtnet dev vmeth0.42

brctl addbr wan
brctl addif wan vmeth0.50
brctl addif wan tap0
ip link set up wan
ip route del \`ip r | grep '24 dev tap0'\`
ip route del \`ip r | grep 'default'\`
ip route add 10.0.2.0/24 dev wan
ip route add default via 10.0.2.2 dev wan

socat -d TCP-LISTEN:8022,fork,reuseaddr TCP-CONNECT:$vmip:22 &
socat -d UDP-LISTEN:8053,fork,reuseaddr UDP-CONNECT:$vmip:53 &
socat -d TCP-LISTEN:8080,fork,reuseaddr TCP-CONNECT:$vmip:80 &
socat -d TCP-LISTEN:8443,fork,reuseaddr TCP-CONNECT:$vmip:443 &

cd /vmdir

while true ; do
  firecracker --no-api --no-seccomp --config-file vmconfig.json
  echo "Restarting VM in 5 seconds, press Ctrl+C to abort..."
  sleep 5
done
EOF
chmod +x "$vmdir/entrypoint.sh"

podman build -t localhost/bbb-configs -f - << EOF
FROM alpine:edge

RUN echo https://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories
RUN apk upgrade musl
RUN apk add bash openssh-client git vim mtr curl wget tcpdump iproute2 bridge-utils dhclient firecracker socat
EOF

podman run -it --rm --name="$location" \
  -v "$vmdir:/vmdir:Z" \
  --user=root --userns=keep-id --security-opt="label=disable" \
  --device=/dev/kvm --device=/dev/net/tun --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -p 8022:8022 -p 8053:8053/udp -p 8080:8080 -p 8443:8443 \
  --network=slirp4netns:mtu=1280 \
  localhost/bbb-configs /vmdir/entrypoint.sh

echo "Done."

# Pasta user-mode networking:
#
# Both IPv6 and IPv4 work nicely, but we need to start with our own addresses,
# and enable DNS/DHCP/v6 servers to be used by the VM's uplink interface.
#
# https://docs.podman.io/en/latest/markdown/podman-run.1.html#network-mode-net
#
# podman run -it --rm --name="pktpls-core" -v "./tmp/vm/pktpls-core:/vmdir:Z" --user=root --userns=keep-id --device=/dev/kvm --device=/dev/net/tun --security-opt="label=disable" --cap-add=NET_ADMIN --cap-add=NET_RAW --network=pasta docker.io/library/alpine:3.18
