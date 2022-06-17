## VLAN-Numbering-Convention

```
10+ for airmax & co mesh links
20+ for 11s
40+ DHCP Clients
42  MGMT
```

## Variables and structures explained

### group_vars/

`group_vars/` holds tree types of resources: the `all/`-directory, location directories and model files.

#### all/

This directory holds base configuration options that will be inserted into every router configuration. Each device will get this options, like timezones, DNS-servers, the packagefeed-URL and so on.

There are also files for the standard ssh keys and definitions for the wifi profiles.

#### model_files

These files define how bbb-configs needs to handle different hardware models. This example shows a WDR4900:
```yml
---
target: "ipq40xx/generic"       # target of router model

switch_ports: 6             # number of physical ports + one (CPU)
switch_int_port: 0          # port-id of the CPU
switch_ignore_ports: []     # omit ports, that exist in software but not in hardware (i.e. MikroTik SXTsq 5ac)

int_port: eth0              # hardware-device on which swconfig works on

wireless_devices:                       # definitions for the devices radios
  - name: 11a_standard                  # 5GHz radio
    hwmode: 11a
    path: ffe09000.pcie/pci9000:00/9000:00:00.0/9000:01:00.0
    ifname_hint: wlan5
  - name: 11g_standard                  # 2.4GHz radio
    hwmode: 11g
    path: ffe0a000.pcie/pcia000:02/a000:02:00.0/a000:03:00.0
    ifname_hint: wlan2
```

For a model using DSA instead of swconfig, you may refer to [`model_ubnt_edgerouter_x_sfp.yml`](https://github.com/Freifunk-Spalter/bbb-configs/blob/master/group_vars/model_ubnt_edgerouter_x_sfp.yml)

#### location-directories

When defining a new location, you need to create a directory named like `location_$NAME/`. In that directory goes the location specific configuration. It consists of several files. You can override the variables defined from the `all` directory by creating a file named like that one in `all/` and redefine any variable.

##### general.yml

This file might be fairly self-explanatory. Please mind that a contact is mandatory. _If you don't like to give your email address, you can use the link to the contact form, that you've got from [config.berlin.freifunk.net](https://config.berlin.freifunk.net)_.

```yml
---
contact_name: 'Petrosilius Quaccus'
contact_nickname: 'Petro'
contact_email: 'quaccus@example.com'
# or:
contact_email: 'https://config.berlin.freifunk.net/contact/446x/ImZmZnctZV0LTA0Ig.FFbQ8w._ZCA4hFY3zR8MdDVNrv3okqwPU'
```

##### owm.yml

This file defines some values to get the location to the [OpenWifiMap](https://openwifimap.net).

```yml
---
location_nice: roof top, Example-Street 24, 10573 Berlin        # any string that describes your location. Could be an address or something
latitude: 52.484948320
longitude: 13.443380903
```

##### networks.yml

This file is the most important one of your setup. It defines IP-Addresses, WIFI-Properties, Mesh and so on. Lets have a (shortened) example of a `networks.yml` from the magda-location:

```yml
---
ipv6_prefix: "2001:bf7:860::/56"

# Mesh: 10.31.83.60/30
networks:
  - vid: 10                   # vlan-id
    role: mesh                # what this vlan does (mesh vs. dhcp)
    name: mesh_sama
    prefix: 10.31.83.60/32    # single ipv4-address for meshing
    ipv6_subprefix: -1        # take an address from the back of the IPv6-block

  - vid: 11
    role: mesh
    name: mesh_ost
    prefix: 10.31.83.61/32
    ipv6_subprefix: -2

  - vid: 42
    role: mgmt                # create a management vlan in which we can reach every device on this site for maintenance
    prefix: 10.31.83.112/28
    gateway: 1
    dns: 1
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

  - vid: 40
    role: dhcp                # dhcp server will run on core-router and serve it's network on vid 40
    prefix: 10.31.83.192/26
    ipv6_subprefix: 0
    assignments:              # assign static addresses to devices
      magda-core: 1

location__channel_assignments_11a_standard__to_merge:
  # AP-id, wifi-channel, bandwidth, txpower
  magda-ap1: 36-20-15
  magda-ap2: 40-20-15
  magda-ap3: 44-20-15
```

### host_vars/

The `host-vars`-dir contains one directory for every OpenWrt-device. The directory-name is the routers hostname. Currently, in that directory theres only one file, called `base.yml`. One Example for that file:

```yml
---

location: sama                  # locations short name, like def'd in location-directories
role: corerouter                # devices role. Could either be 'corerouter', 'ap' or 'uplink_gateway'
model: "avm_fritzbox-7530"      # model name like written in the corresponding file name in group_vars/

wireless_profile: freifunk_default      # activates wifi with freifunk-default-settings on this device by overriding default wireless profile for corerouters, which is the profile disable
```

Some devices use POE-Ports. To enable them, just give the parameter `poe_on` and the port. For example:

```yml
---

location: koepi
role: ap
target: "ath79/generic"
model: "ubnt_nanostation-m5_xm"

poe_on: [0]
```

### inventory/

This is an internal diretory on which you don't need to care about now. If you like to learn mor on it, you might read the `README.md` file inside of it.

### roles/

This directory contains magical ansible-stuff. Unless you want to develop for this system you can safely ignore this.
