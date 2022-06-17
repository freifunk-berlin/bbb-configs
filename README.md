# bbb-configs (Ansible Config Management)

![Freifunk Berlin](https://user-images.githubusercontent.com/10708466/174321624-b43cedab-53e8-4b56-b1fb-a051e18b21bb.png)

BBB-Configs manages and provisions OpenWrt mesh nodes in the city-wide backbone of Freifunk Berlin via ansible. It abstracts the typical OpenWrt mesh config to generic templates. Those templates provision all locations more or less the same helping the maintainers to orientate on all sites.

The provision of a router works by generating the necessary OpenWrt configs and feeding the OpenWrt-Imagebuilder with it. In the end, ansible generates a self-contained binary image ready to be flashed on a router. Due to the self-contained property bbb-configs can ensure to function properly on a router in a specific location. Maintainers can remotely upgrade sites without having to worry about wrong configurations.

## Getting Started

Using bbb-configs is quite simple. The TL;DR version for anyone not wanting to read the [FAQ](FAQ.md) is:

    ansible-playbook play.yml --limit location-* --tags image

## Developers and Maintainers

If you want to use bbb-configs for locations that are not included in bbb-configs yet or to work on a fork of the code yourself then see the [Developers Guide](DEVELOPER.md).