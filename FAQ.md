# FAQ

## How to get started?

Make sure to install ansible and clone the bbb-configs repository. Then install the requirements using:

```sh
apt update
apt install -y jq
python3 -m venv venv
source venv/bin/activate
pip3 install -r requirements.txt
```

## How to spin up a config run?

```sh
ansible-playbook play.yml
```

This will generate config files for all devices for inspection. The output path is `./tmp/configs`.

## How to spin up a config run and image generation?

```sh
ansible-playbook play.yml --tags image
```

The output path for the images is `./tmp/images`.

## How to limit a config and image generation?

```sh
# config run
ansible-playbook play.yml --limit example-core # single-device
ansible-playbook play.yml --limit example-* # location
ansible-playbook play.yml --limit example-core,example-ap1 # list of specific devices

# config run and image generation
ansible-playbook play.yml --limit example-core --tags image # single-device
ansible-playbook play.yml --limit example-* --tags image # location
ansible-playbook play.yml --limit example-core,example-ap1 --tags image # list of specific devices
```

The second command doesn't work in `zsh`. If you encounter that problem consider using `bash` instead, please.

## How to spin up a config run, image generation and flash from inside freifunk network?

NOTE: This requires IPv6 Connectivity from inside the freifunk network and is not yet fully working.

```sh
ansible-playbook play.yml --tags flash
```

## What is required to bringup a location?

1. Create a location file in the `locations` directory. You might want to copy an existing location to make your start more easy.
2. Run the image creation as shown in the commands above (image will be in `tmp/images` directory).
3. Flash the image to your router.
4. Secure the router by setting a root password using SSH or the web interface.
5. Done!

Have a look at the [Developers Guide](DEVELOPER.md) for more information.

## What is required to send in a pull request?

Make sure to test your addition with yamllint and ansible-lint before sending a pull request by using:

```sh
make lint
```

## How can I mass deploy in the Freifunk Network

```sh
# Find groups matching our targets to ease selection
ansible-inventory --graph

# Generate images for a list of specific devices
ansible-playbook play.yml --tags image --limit example-core,example-ap1

# Change into images directory
cd ./tmp/images

# Optional: Keyscan for hostkeys
for i in *.bin; do hostname="$(echo $i | awk -F '.' '{print $1}')"; ssh_target="$hostname.olsr"; ssh-keyscan "$ssh_target"; done

# "oneliner" to mass-flash all devices where we have an image (use with caution)
for i in *.bin; do hostname="$(echo $i | awk -F '.' '{print $1}')"; ssh_target="root@$hostname.olsr"; path="/tmp/$i"; echo -e "\e[92m$(date +%H:%M:%S) - $hostname: Disabling non-mesh wireless networks to free memory and sleep 13 seconds until change is applied (required for 32mb devices)\e[0m";
ssh "$ssh_target" "for i in \$(uci show wireless | grep mode=\'ap\' | awk -F '.' '{print \$2}'); do uci set wireless.\$i.disabled=1; done; uci commit wireless; ubus call uci reload_config;"; sleep 13; echo -e "\e[92m$(date +%H:%M:%S) - $hostname: Disabling unnecessary services to free even more memory\e[0m";
ssh "$ssh_target" "/etc/init.d/collectd stop; /etc/init.d/luci_statistics stop; /etc/init.d/sysntpd stop; /etc/init.d/urngd stop; /etc/init.d/rpcd stop; /etc/init.d/naywatch stop 2> /dev/null"; echo -e "\e[92m$(date +%H:%M:%S) - $hostname: Transfering image\e[0m"; scp -O "$i" "$ssh_target:$path";
echo -e "\e[92m$(date +%H:%M:%S) - $hostname: Start sysupgrade \e[0m"; ssh "$ssh_target" "sysupgrade $path" ; done
```
