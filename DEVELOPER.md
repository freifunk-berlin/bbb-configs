# Developer Guide

This guide explains the directory structure of the project and variables within the config files.

## locations/

`locations/` holds all the location specific configuration. To create a new location add a new file named  `$LOCATIONNAME.yml`. The name should only contain `a-z`, `0-9` and `-`.

As this format is new there are still some old locationdata you can find at `groups_vars/` and `host_vars/`. These old configurations work the same way exept being spilt into different files. For new locations only use `locations/`.

There are default values defined in `group_vars/all/`. You can override the variables by redefining them in the `$LOCATIONNAME.yml`.

The following chapters describes the individual parts of the configuration file.

### location name

This name has to be consistent with the filename and the prefix for individual devices.

```yml
---

location: magda # a string with the name of the location
```
### general infos

This part defines general values that are used e.g. in [Hopglass](https://hopglass.berlin.freifunk.net) and [OpenWifiMap](https://openwifimap.net).

```yml
location_nice: roof top, Example-Street 24, 10573 Berlin        # any string that describes your location. It should contain an address.
latitude: 52.484948320
longitude: 13.443380903
```

### contact details

Please mind that a contact is mandatory. If you don't like to give your email address, you can use the link to the contact form, that you've got from [config.berlin.freifunk.net](https://config.berlin.freifunk.net). Locations maintained by the entire community can use `community: true` instead. This will set default community values.

```yml
contact_name: 'Petrosilius Quaccus'
contact_nickname: 'Petro'
# contacts must be a list. Even if only one contact is given
contacts:
  - 'quaccus@example.com'
  - 'https://config.berlin.freifunk.net/contact/446x/ImZmZnctZV0LTA0Ig.FFbQ8w._ZCA4hFY3zR8MdDVNrv3okqwPU'
```
### hosts

This section describes every OpenWrt-device.

```yml
hosts:
  - hostname: magda-core               # the name of the device. The location-part of the name must match `location:` defined above
    role: corerouter                   # devices role. Could either be 'corerouter', 'ap' or 'gateway'
    model: "avm_fritzbox-7530"         # model name like written in the corresponding file name in group_vars/
    wireless_profile: freifunk_default # activates wifi with freifunk-default-settings on this device. By default only APs have activated wifi.
```

Some devices use POE-Ports. To enable them, just give the parameter `poe_on` and the port. For example:

```yml
    poe_on: [0]
```

Multiple ports can be specified as a list:

```yml
    poe_on: [0,1,2,3]
```
### monitoring

All OpenWrt-devices have monitoring enabled. To activate monitoring for other devices we use SNMP. The core router will collect and report statistics for the devices. Make shure SNMP is activated on the properitary device. You can find an overview with all available profiles at `group_vars/all/snmp_profiles.yml`

```yml
snmp_devices:
  - hostname: segen-f2a   # hostname
    address: 10.31.6.11   # static ip of the device
    snmp_profile: airos_8 # SNMP profile

  - hostname: segen-test
    address: 10.31.6.12
    snmp_profile: af60

  - hostname: segen-sw
    address: 10.31.6.13
    snmp_profile: airos_6
```

### airos dfs reset

This section holds information about airos devices and how to access them. The information is used to initiate a DFS reset within a specific time window after a DFS event was detected.

```yml
airos_dfs_reset:
  - name: "segen-f2a"          # name of the device
    target: "10.31.6.11"       # static ip of the device
    username: "ubnt"           # root username
    password: "file:/root/pwd" # location to a password file within the core-router
    daytime_limit: "2-7"       # time window for DFS reset

  - name: "segen-mabb"
    target: "10.31.6.12"
    username: "ubnt"
    password: "file:/root/pwd"
    daytime_limit: "2-7"
```

### network

This part defines IP-Addresses, WIFI-Properties, Mesh and so on. Lets have a (shortened) example of a `networks.yml` from the magda-location:

```yml

# mesh: 10.31.83.60/30        # add a overview of all reserved adresses at the top as a comment
# dhcp: 10.31.83.192/26
# mgmt: 10.31.83.112/28

ipv6_prefix: "2001:bf7:860::/56"

networks:
  - vid: 10                   # vlan-id
    role: mesh                # what this vlan does (mesh vs. dhcp)
    name: mesh_sama           # the name has a 12 characters limit. It should only contain lower letters and underscores
    ptp: true                 # changing the mode from mesh to ether for reducing the airtraffic for point to point connections by ignoring the hidden node problem
    prefix: 10.31.83.60/32    # single ipv4-address for meshing
    ipv6_subprefix: -10       # take an address from the back of the IPv6-block. Best practise is to use the same value as the vlan-id to avoid duplicate adresses.
     mesh_metric_lqm: ['default 0.8'] # link quality multiplier is used to artificially make routes worse, so certain links are preferred. Must be higher then 0.2, otherwise link wont work.
    untagged: true            # untags the vlan. It is commenly used for tunnel-uplinks

  - vid: 11
    role: mesh
    name: mesh_ost
    prefix: 10.31.83.61/32
    ipv6_subprefix: -2

  - vid: 40
    role: dhcp                # dhcp server will run on core-router and serve it's network on vid 40
    prefix: 10.31.83.192/26
    ipv6_subprefix: 0
    assignments:              # assign static addresses to devices
      magda-core: 1

  - vid: 42
    role: mgmt                # create a management vlan in which we can reach every device on this site for maintenance
    prefix: 10.31.83.112/28
    gateway: 1
    dns: 1
    ntp: 1                    # used to tell accesspoints to use the ntp server of the core router
    ipv6_subprefix: 1
    assignments:              # assign static(!) addresses from mngt-network to individual devices/interfaces.
      magda-core: 1           # core router gets 1st address. In result it will be reachable at 10.31.83.113
      magda-switch: 2         # 10.31.83.114 ...
      magda-sama: 3           # interface for mesh link to sama def'd at vid-10 (see above) gets 3rd address (for mngt only)
      magda-ost-5ghz: 4       # mesh link on vid-11
      magda-ap1: 5
      magda-ap2: 6
      magda-ap3: 7
      magda-ap4: 8

location__channel_assignments_11a_standard__to_merge:
  # AP-id, wifi-channel, bandwidth, txpower
  magda-ap1: 36-20-15
  magda-ap2: 40-20-15
  magda-ap3: 44-20-15
```

The VLAN ID (vid) usually follow this numbering convention. They should be sorted in ascending order in the file.

```yml
10+ for airmax & co mesh links
20+ for 11s
40+ DHCP Clients
42  MGMT
50  Wireguardtunnel
```

### uplink via tunnel

A local uplink over a "normal" internet connection can be added. All the traffic will be routed through a Wireguard-VPN-Tunnel. The lo
If for some reason you are in need of an uplink via a "normal" internet connection, a wireguard
tunnel can be an easy and safe solution. In that case you can add one or more tunnel networks:

```yml
  - vid: 50
    role: uplink

  - role: tunnel
    ifname: ts_wg0
    mtu: 1280
    prefix: 10.31.142.120/32
    wireguard_port: 51820

  - role: tunnel
    ifname: ts_wg1
    mtu: 1280
    prefix: 10.31.142.121/32
    wireguard_port: 51821
```

The values of the Babel Metric and the OLSR LQM are optional and influence how the uplink works. If the uplink tunnel is intended
as a backup connection, and you see traffic flow through the tunnel, you should set a higher value for the babeld
metric and a lower value for the OLSR LQM. The lowest possible LQM value is 0.2. Below that value the uplink will
not work.

If there are routes via the tunnels the following command will show a non empty result, when run on the node
`(echo /routes | nc 127.0.0.1 9090) | grep '"networkInterface": "ts_'`. In this case you should adjust the link metrics
for uplinks that should only act as backup connection.

If you have multiple uplinks and want one to be prefered, set different link metrics for the different uplinks.

### ssh-keys

By default the ssh-keys within `all/ssh-keys.yml` will be installed on all hosts. To add additional ssh keys use this format:

```yml
location__ssh_keys__to_merge:
  - comment: John
    key: ssh-ed25519 XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX Keyname
```

If you do not want the ssh-keys within `all/ssh-keys.yml` installed, you can use this way to override the default keys:

```yml
ssh_keys:
  - comment: John
    key: ssh-ed25519 XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX Keyname
```
### wireless profiles

<!-- TODO: this section needs to be improved -->

An individual wireless profile can be added to your location. A common use case is a private SSID.

```yml
location__wireless_profiles__to_merge:

  - name: foobar
    devices:
      - radio: 11a_standard
        legacy_rates: false
        country: DE
      - radio: 11g_standard
        legacy_rates: false
        country: DE

    ifaces:
      - mode: ap
        ssid: berlin.freifunk.net
        encryption: none
        network: dhcp
        radio: [11a_standard, 11g_standard]
        ifname_hint: ff

      - mode: ap
        ssid: berlin.freifunk.net Encrypted
        encryption: owe
        network: dhcp
        radio: [11a_standard, 11g_standard]
        ifname_hint: ffowe
        ieee80211w: 1

      - mode: ap
        ssid: Private Wifi
        encryption: psk2
        key: 'file:/root/wifi_pass'
        network: prdhcp
        radio: [11a_standard, 11g_standard]
        ifname_hint: prdhcp
```

## groups_vars/

### all/

This directory holds base configuration options that will be inserted into every router configuration. Each device will
get this options, like timezones, DNS-servers, the packagefeed-URL and so on.

There are also files for the standard ssh keys and definitions for the Wi-Fi profiles.

### model_files

These files define how bbb-configs needs to handle different hardware models. This example shows a WDR4900:

```yml
---
target: "ipq40xx/generic"               # target of router model
brand_nice: TP-Link                     # brand from the router in human readable form
model_nice: Archer C7                   # model from the router in human readable form
version_nice: v2                        # version from the router in human readable form, not always present

switch_ports: 6                         # number of physical ports + one (CPU)
switch_int_port: 0                      # port-id of the CPU
switch_ignore_ports: [1, 2, 3, 4]       # omit ports, that exist in software but not in hardware (i.e. MikroTik SXTsq 5ac)

int_port: eth0                          # hardware-device on which swconfig works on

wireless_devices:                       # definitions for the devices radios
  - name: 11a_standard                  # 5GHz radio
    band: 5g
    htmode_prefix: VHT
    path: ffe09000.pcie/pci9000:00/9000:00:00.0/9000:01:00.0
    ifname_hint: wlan5
  - name: 11g_standard                  # 2.4GHz radio
    band: 2g
    htmode_prefix: VHT
    path: ffe0a000.pcie/pcia000:02/a000:02:00.0/a000:03:00.0
    ifname_hint: wlan2
```

Possible values for band are 2g for 2.4 GHz, 5g for 5 GHz, 6g for 6 GHz and 60g for 60 GHz.
Band replaces hwmode since 21.02.2.

Possible values for htmode_prefix are HT (802.11n), VHT (802.11ac) and HE (802.11ax).
The htmode_prefix setting corresponds with the htmode option.

For a model using DSA instead of swconfig, you may refer to [`model_ubnt_edgerouter_x_sfp.yml`](https://github.com/freifunk-berlin/bbb-configs/blob/master/group_vars/model_ubnt_edgerouter_x_sfp.yml)

Note: If you want to create a new model_file you can have a look at `/etc/config/wireless` on a standard OpenWRT
install to obtain the path information for the wireless_devices.


## inventory/

This is an internal diretory on which you don't need to care about now. If you like to learn mor on it, you might read
the `README.md` file inside of it.

## roles/

This directory contains magical ansible-stuff. Unless you want to develop for this system you can safely ignore this.
