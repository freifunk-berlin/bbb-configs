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

Depending on your system you might need more requirements. If something fails check out [this OpenWRT page](https://openwrt.org/docs/guide-developer/toolchain/install-buildsystem).

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

## How can I mass deploy in the Freifunk Network?

1. Clear folder `tmp/images`.
2. Generate images for every location you want to update
3. Use `mass-update.sh` while you are connected to the Freifunk Network. It will automatically connect via ssh to all routers and install the new firmware.

## How can I have my own website/blog/service ?

You need to host your service on a separate device like your old computer.
to make it reachable within Freifunk define a static IP Address in the config file of your location like this:
```yml
[...]
    assignments:
      foo-core: 1
      foo-service: 2
```
You could choose an existing network like `mgmt` or define a extra one. Just make sure it doesn't have `inbound_filtering: true` set.

Set the corresponding static IP on your separate device. It will be reachable via the IP Address or via its internal Domain `foo-service.ff`.

If you encounter problems with reaching the local services make sure to check if you are connected via a VPN or have a different DNS configured.

### How can I reach it from outside the Freifunk network

Freifunk Berlin uses a public routable IPv6 Addressroom within its network. We can open the firewall to let traffic in. After you finished these steps you can reach your service via IPv6 from all over the world.

1. Make sure your router doesnt block incoming traffic e.g. the subnetwork doesnt have `inbound_filtering`
2. Add the following to `group_vars/role_gateway/general.yml`

```yml
inbound_allow:
 - name: Rule Description (mandatory)
   dst: Destination IP (mandatory)
   src: Source IP
   proto: [tcp, udp, icmp.]
   src_port:
   dst_port: 22
```
3. Update the Firewall of the Gateways

   _Note: This can only be done by the maintainers of the bbb_

4. Check your separate device for its IPv6 Address (starting with 2001:) - it is reachbale now.

   _Note: IPv6 Addresses are handed out via SLAAC and might not be static. Define a static Address so it doesnt change over time_
