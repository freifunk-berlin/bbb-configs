# FAQ

## How to get started

```sh
pip3 install -r requirements.txt
```

## How to spin up a config run (generate only, output path is /tmp/configs/..:

```sh
ansible-playbook play.yml
```

## How to spin up a config run and generate images

```sh
ansible-playbook play.yml --tags image
```

## How to limit image creation to a single location

```sh
ansible-playbook play.yml --limit example-core
ansible-playbook play.yml --limit example-*
```

The second command doesn't work in `zsh`. If you encounter that problem consider using `bash` instead, please.

## How to spin up a config run, generate image and flash (Requires IPv6 Connectivity from inside freifunk network, not yet fully working)

```sh
ansible-playbook play.yml --tags flash
```

## Whats required to bringup a location?

1. Create a location folder at `/group_vars/` and fill in at least `general.yml`, `networks.yml` and `owm.yml`.
2. Create a folder for every OpenWrt device at the location under `/host_vars/`. Paste the `base.yml` in there.
3. Run the image creation as shown in the commands above (image will be in `/tmp/ansible-openwrt/images/`).
4. Flash the image to your router.
5. Secure the router by setting a root password using SSH or the web interface.
6. Done!

## How can I mass deploy in the Freifunk Network

```sh

# Find groups matching our targets to ease selection
ansible-inventory --graph

# Generate images for all devices
ansible-playbook play.yml --tags image --limit model_ubnt_nanostation_m5_xm,model_ubnt_nanostation_m5_xw,model_ubnt_nanostation_m2_xm,model_ubnt_nanostation_loco_m2_xm,model_ubnt_nanostation_ac_loco,model_mikrotik_sxtsq_5_ac,model_mikrotik_sxtsq_2_lite

# Change into images directory
cd /tmp/ansible-openwrt/images

# "oneliner" to mass-flash all devices where we have an image (use with caution)
for i in *.bin; do hostname="$(echo $i | awk -F '.' '{print $1}')"; ssh_target="root@$hostname.olsr"; path="/tmp/$i"; echo -e "\e[92m$(date +%H:%M:%S) - $hostname: Disabling non-mesh wireless networks to free memory and sleep 13 seconds until change is applied (required for 32mb devices)\e[0m"; ssh "$ssh_target" "for i in \$(uci show wireless | grep mode=\'ap\' | awk -F '.' '{print \$2}'); do uci set wireless.\$i.disabled=1; done; uci commit wireless; ubus call uci reload_config;"; sleep 13; echo -e "\e[92m$(date +%H:%M:%S) - $hostname: Disabling unnecessary services to free even more memory\e[0m"; ssh "$ssh_target" "/etc/init.d/collectd stop; /etc/init.d/luci_statistics stop; /etc/init.d/sysntpd stop; /etc/init.d/urngd stop; /etc/init.d/rpcd stop; /etc/init.d/naywatch stop 2> /dev/null"; echo -e "\e[92m$(date +%H:%M:%S) - $hostname: Transfering image\e[0m"; scp -O "$i" "$ssh_target:$path"; echo -e "\e[92m$(date +%H:%M:%S) - $hostname: Start sysupgrade \e[0m"; ssh "$ssh_target" "sysupgrade $path" ; done
```
