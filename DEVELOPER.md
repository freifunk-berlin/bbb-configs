# Developer Guide

This guide explains the directory structure of the project and variables within the config files.

## locations/

`locations/` holds all the location specific configuration. To create a new location add a new file named  `$LOCATIONNAME.yml`. The name should only contain `a-z`, `0-9` and `-`.

As this format is new there are still some old locationdata you can find at `groups_vars/` and `host_vars/`. These old configurations work the same way except being spilt into different files. For new locations only use `locations/`.

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
location_nice: roof top, Street 42, 10573 Berlin  # any string that describes your location. It should contain an address.
latitude: 52.484948320
longitude: 13.443380903
altitude: 42                                      # in meter above sea level
height: 13                                        # in meter above ground level
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
#### PoE

Some devices use POE-Ports. To enable them, just give the parameter `poe_on` and the port. For example:

```yml
    poe_on: [0]
```

Multiple ports can be specified as a list:

```yml
    poe_on: [0,1,2,3]
```

#### MAC Addresses

A few devices also require an override to properly set the MAC address. The command to read the address from the device should be documented in the corresponding model file.

Without the `mac_override` these devices will still function, but generate a new MAC address on each boot. This causes the devices to appear multiple times in the devices listing of switches and also changes the link local address of the device as it is based on the MAC address.

```yml
    mac_override: {eth0: XX:XX:XX:XX:XX:XX}
```

#### Init Script rc.local

For special use cases you can add lines to a script file. This script runs once after installation of the image. One use case is untagging certain vlans on some ports. For this it is important to check the model file at `group_vars/` to find the correct ports.

```yml
    host__rclocal__to_merge:
      - |
        # Untag mesh traffic for a Airfiber as they cant do it themself
        uci set network.vlan_10.ports='lan1:t lan2 lan3:t lan4:t lan5:t'
        # Untag DHCP on ports 4 and 5 for convenient maintenance'
        uci set network.vlan_40.ports='lan1:t lan2:t lan3:t lan4 lan5'
        uci commit network; reload_config
```

### monitoring

All OpenWrt-devices have monitoring enabled. To activate monitoring for other devices we use SNMP. The core router will collect and report statistics for the devices. Make sure SNMP is activated on the proprietary device with the community set to public. You can find an overview with all available profiles at `group_vars/all/snmp_profiles.yml`

```yml
snmp_devices:
  - hostname: segen-f2a   # hostname
    address: 10.31.6.11   # static ip of the device
    snmp_profile: airos_8 # SNMP profile
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
```

### network

This part defines IP-Addresses, WIFI-Properties, Mesh and so on.

```yml
# ROUTER: 10.31.42.0/26       # add a overview of all reserved addresses at the top as a comment
# --MGMT: 10.31.42.0/28
# --MESH: 10.31.42.16/28
# --DHCP: 10.31.42.32/27

ipv6_prefix: "2001:bf7:860::/56"

networks:
  - vid: 10                   # vlan-id
    role: mesh                # what this vlan does (mesh, dhcp, mgmt)
    name: mesh_sama           # the name has a 12 characters limit. It should only contain lower letters and underscores
    ptp: true                 # changing the mode from mesh to ether for reducing the airtraffic for
                              # point to point connections by ignoring the hidden node problem
    prefix: 10.31.42.16/32    # single ipv4-address for meshing
    ipv6_subprefix: -10       # take an address from the back of the IPv6-block. Best practice is
                              # to use the same value as the vlan-id for everything except dhcp and
                              # mgmt to avoid duplicate addresses.
    mesh_metric_lqm: ['default 0.8'] # link quality multiplier is used to artificially make routes
                              # worse for olsr, so certain links are preferred. Must be higher then 0.2,
                              # otherwise link wont work. Only used to connect to Falter-Routers.
    mesh_metric: 1024         # overrides the default metrics for for babel routing.
                              # Lower metrics means a route is preferred. Babel is used within bbb-configs.
                              # Defaults can be found at group_vars/all/general.yml
    untagged: true            # untags the vlan. It is commonly used for tunnel-uplinks. Only one
                              # network can be untagged. For more advanced use cases, look under
                              # hosts section at rc.local

  - vid: 20
    role: mesh
    name: 11s_n_5g
    prefix: 10.31.42.17/32
    ipv6_subprefix: -20
    mesh_ap: magda-core       # name of the ap that should mesh via 802.11s. Must be the same as in the hosts section above
    mesh_radio: 11a_standard  # name of the wireless band. Can be 11a_standard for 5 GHz and 11g_standard for 2.4 GHz
    mesh_iface: mesh

  - vid: 40
    role: dhcp                # dhcp server will run on core-router and serve it's network on vid 40
    prefix: 10.31.42.32/27
    ipv6_subprefix: 0
    inbound_filtering: true   # blocks traffic from outside to the dhcp clients. This helps with client security
    enforce_client_isolation: true # blocks traffic between clients within this vlan. This helps with client security
    no_corerouter_dns_record: true # Add this option to every dhcp-network that is not the main one, for example a private dhcp-network
    assignments:              # assign static addresses to devices
      magda-core: 1

  - vid: 42
    role: mgmt                # create a management vlan in which we can reach every device on this site for maintenance
    prefix: 10.31.42.0/28
    gateway: 1
    dns: 1                    # used to tell accesspoints the location of dns server at assignment number n
    ntp: 1                    # used to tell accesspoints to use the ntp server of the core router
    ipv6_subprefix: 1
    assignments:              # assign static(!) addresses from mgmt-network to individual devices/interfaces.
      magda-core: 1           # core router gets 1st address. In result it will be reachable at 10.31.42.1
      magda-switch: 2         # 10.31.42.2 ...
      magda-sama: 3           # interface for mesh link to sama def'd at vid-10 (see above) gets 3rd address (for mgmt only)
      magda-ost-5ghz: 4
      magda-ap1: 5
      magda-ap2: 6
      magda-ap3: 7
      magda-ap4: 8            # 10.31.42.8

location__channel_assignments_11a_standard__to_merge:
  # AP-id, wifi-channel, bandwidth, txpower. Can be empty for default values
  magda-ap1: 36-20-15
  magda-ap2: 40-20-15
  magda-ap3: 44-20-15
```

The VLAN ID (vid) usually follow this numbering convention. They should be sorted in ascending order in the file.

```yml
10+ for airmax & co mesh links
20+ for 11s mesh
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

  - role: tunnel              # only one tunnel is required. Running two makes the failover faster when one breaks
    ifname: ts_wg1
    mtu: 1280
    prefix: 10.31.142.121/32
    wireguard_port: 51821
```

If there are routes via the tunnels the following command will show a non empty result, when run on the node
`(echo /routes | nc 127.0.0.1 9090) | grep '"networkInterface": "ts_'`. For uplinks that should only act as backup connection you should adjust the link metrics. See the network section for a example of Babel Metric and OLSR LQM.

If you have multiple uplinks and want one to be preferred, set different link metrics for the different uplinks.

### uplink over LTE modem

Many LTE USB sticks work as a so called USB CDC Net device. They emulate a standard ethernet device without any need for further configuration.

```yml
  - vid: 50
    untagged: true
    ifname: eth1
    role: uplink

  - role: tunnel
    ifname: ts_wg0
    mtu: 1280
    prefix: 10.31.142.120/32
    wireguard_port: 51820
```

Some integrated LTE modems work with the QMI protocol instead, which requires basic configuration of the modem.

```yml
  - vid: 50
    untagged: true
    ifname: wwan0
    role: uplink
    uplink_mode: direct
    wwan:
      proto: qmi
      device: /dev/cdc-wdm0
      apn: internet
      pdptype: ipv4

  - role: tunnel
    ifname: ts_wg0
    mtu: 1280
    prefix: 10.31.142.120/32
    wireguard_port: 51820
```


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
      - radio: 11g_standard
      - radio: 11a_mesh
      - radio: 11a_standard
        disabled: false # Enable radio (default)
        legacy_rates: false # Disable lower bandwidth rates (default)
        country: 'DE' # Set German country code for radio compliance (default)

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
        key: 'file:/root/wifi_pass'  # the location of the file containing the wifi password
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

These files define how bbb-configs needs to handle different hardware models:

```yml
---
target: "ipq40xx/generic"               # target of router model
brand_nice: TP-Link                     # brand from the router in human readable form
model_nice: Archer C7                   # model from the router in human readable form
version_nice: v2                        # version from the router in human readable form, not always present

# This section is only needed for devices still using swconfig
switch_ports: 6                         # number of physical ports + one (CPU)
switch_int_port: 0                      # port-id of the CPU
switch_ignore_ports: [1, 2, 3, 4]       # omit ports, that exist in software but not in hardware (i.e. MikroTik SXTsq 5ac)
int_port: eth0                          # hardware-device on which swconfig works on

# For DSA use
dsa_ports:                              # list of ports obtained from boards.json
  - lan1
  - lan2
  - wan

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

poe_ports:                              # definitions for the devices poe Ports. You can obtain this info from /etc/boards.json
  - name: PoE Power Port0
    gpio_pin: 400
    value: 0
```

Possible values for `band` are 2g for 2.4 GHz, 5g for 5 GHz, 6g for 6 GHz and 60g for 60 GHz.
Band replaces hwmode since 21.02.2.

Possible values for `htmode_prefix` are HT (802.11n), VHT (802.11ac) and HE (802.11ax).
The htmode_prefix setting corresponds with the htmode option.

To create a new model file for a device with **swconfig** you can use the following commands to get information about the switch on a standard OpenWRT install:

- `swconfig list` to list all switches e.g. switch0
- `swconfig dev switch0 help` to get information about the switch
- `swconfig dev switch0 show` to get information about the state of the switch and ports

Note: If you want to create a new model_file you can have a look at `/etc/config/wireless` on a standard OpenWRT
install to obtain the path information for the wireless_devices.

For a model using **DSA** instead of swconfig you can obtain the needed information from

`cat /etc/board.json`

## inventory/

This is an internal directory on which you don't need to care about now. If you like to learn more on it, you might read
the `README.md` file inside of it.

## roles/

This directory contains magical ansible-stuff. Unless you want to develop for this system you can safely ignore this.
