# bbb-configs (Ansible Config Management)

![Freifunk Berlin](https://user-images.githubusercontent.com/10708466/174321624-b43cedab-53e8-4b56-b1fb-a051e18b21bb.png)

BBB-Configs manages and provisions OpenWrt mesh nodes in the city-wide backbone of Freifunk Berlin via ansible. It abstracts the typical OpenWrt mesh config to generic templates. Those templates provision all locations more or less the same helping the maintainers to orientate on all sites.

The provision of a router works by generating the necessary OpenWrt configs and feeding the OpenWrt-Imagebuilder with it. In the end, ansible generates a self-contained binary image ready to be flashed on a router. Due to the self-contained property bbb-configs can ensure to function properly on a router in a specific location. Maintainers can remotely upgrade sites without having to worry about wrong configurations.

## Getting Started

Using bbb-configs is quite simple. The TL;DR version for anyone not wanting to read the [FAQ](FAQ.md) is:

    ansible-playbook play.yml --limit location-* --tags image

## How it Works

Ansible playbooks offer simple, repeatable, and reusable execution of tasks making them perfectly fit into the Freifunk world. Daily Freifunk maintenance consists of updating a location to the newest software version or deploying a new service. Sometimes new sites are acquired with the constraint of producing a network plan and flashing dozens of routers with OpenWrt. We map these tasks in files following the YAML format and integrate them into our playbook. Commonly, playbooks execute ansible tasks on remote machines changing configuration files or installing new software on runtime. Here, we use the playbook to perform tasks with the outcome of a binary image containing all configuration files on compile time. The only remote execution at runtime on the network device may be a sysupgrade-command of the final binary.

We follow the common ansible scheme of locations and hosts. We see a location as an autonomous layer 2 domain connected with other locations in a layer 3 fashion. We call these layer 2 constructions a core-router setup implying only one router is acting as a gateway and provides services, like DHCP. Further, these routers maintain layer 3 connectivity to other locations with mesh routing daemons like babeld. A core setup can have an unbound number of access points. As a layer 2 domain, a network client can roam between all devices, and no routing is done inside the location.  Mapping that on our playbook, the location contains the network plan and also service descriptions that are valid for all hosts inside a location. Host entities describe the physical or virtual network entity by its actual hardware, e.g. Belkin RT3200 router, and can also override service descriptions set by the location. The mapping between hosts and location is done inside the host's definition by the location variable.

The image compilation takes the variables defined by the hosts and location files to generate the OpenWrt config syntax for each physical or virtual host. The generation is based on template files written in the Jinja language. Based on the actual hardware, different files are included to fit the underlying system and drivers, e.g. some drivers expect network config concerning the distributed switching architecture, and some use the legacy sw-config format. Based on the predefined roles, core-router, access point, and gateway, a customized set of tasks are executed. The last step is to download the correct OpenWrt-Imagebuilder for the host and give it all generated config files. The Imagebuilder generates a binary image embedded with the customized config for this one host in the particular location. Flashing this image to a router will set the router after boot directly in the correct operating state. Further, this router will not be able to lose any of its configurations since it is embedded into its image.

If we need someone to reproduce our setup, the person can just generate the image for the involved routers, aka hosts, and provision them. Everyone can reproduce our setup and can work with us on our configurations from all other the world. In the future, it may be possible to abstract the actual router hardware with QEMU opening new interesting use cases.

## Developers and Maintainers

If you want to use bbb-configs for locations that are not included in bbb-configs yet or to work on a fork of the code yourself then see the [Developers Guide](DEVELOPER.md).
