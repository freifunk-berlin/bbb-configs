# FAQ

<details>
<summary> How can I mass deploy in the Freifunk Network? </summary>
<br>

1. Clear folder `tmp/images`.
2. Generate images for every location you want to update
3. Use `mass-update.sh` while you are connected to the Freifunk Network. It will automatically connect via ssh to all routers and install the new firmware.

</details>

<details>
<summary> Automatic Updates for wiki.freifunk.net </summary>
<br>

[wiki.freifunk.net](https://wiki.freifunk.net/)

By default all articles that follow the convention will be updated automatically when config changes get merged into the main branch.
To add this option to your wikiarticle add a section called "Konfiguration" and replace all values that you want to automatically change as you can see in [this example-article](https://wiki.freifunk.net/Berlin:Standorte:Fesev). If you want to add a new location you can start with [this template](https://wiki.freifunk.net/Berlin:Standorte:Template).

Wikiupdater expects an article or a redirect to the article at `wiki.freifunk.net/Berlin:Standorte:$LOCATION` where `$LOCATION` is the location name defined in your file at `locations/$LOCATION.yml`. You can manually run this update by using `--tags wiki` in a ansible config run. If you dont need the config files generated you can skip it by adding `--skip-tags`

</details>

<details>
<summary> Hosting your own service ( inside FreiFunk )</summary>

## How can I have my own website/blog/service?
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

</details>
