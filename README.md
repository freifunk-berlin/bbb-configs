# BerlinBackBone Configuration (BBB-configs)


BBB-Configs manages and provisions OpenWrt mesh nodes in the city-wide backbone of Freifunk Berlin via ansible. It abstracts the typical OpenWrt mesh config to generic templates. Those templates provision all locations more or less the same helping the maintainers to orientate on all sites.

With BBB-Configs we

* describe all aspects of a location in a configuration file
* build firmware images ready to be flashed onto routers including the full configuration
* provide scripts to efficiently update multiple routers

<br>

![Freifunk Berlin](https://user-images.githubusercontent.com/10708466/174321624-b43cedab-53e8-4b56-b1fb-a051e18b21bb.png)

## How it Works

### Short Version

With ansible you can build a specifically configured firmware image to flash onto your OpenWrt router. Due to properties of that image, BBB-configs can ensure proper function at certain locations, as it includes the full configuration. It also makes it easier for maintainers to remotely upgrade sites without worrying about configurations.

<details>

### Technical Version

The provision of a router works by generating the necessary OpenWrt configs and feeding the OpenWrt-Imagebuilder with it. In the end, ansible generates a self-contained binary firmware image ready to be flashed onto a router. Due to the self-contained property BBB-Configs can ensure to function properly on a router in a specific location as it includes the full configuration. Maintainers can remotely upgrade sites without having to worry about wrong configurations. Ansible playbooks offer simple, repeatable, and reusable execution of tasks making them perfectly fit into the Freifunk world. Daily Freifunk maintenance consists of updating a location to the newest software version or deploying a new service. Sometimes new sites are acquired with the constraint of producing a network plan and flashing dozens of routers with OpenWrt. We map these tasks in files following the YAML format and integrate them into our playbook. Commonly, playbooks execute ansible tasks on remote machines changing configuration files or installing new software on runtime. Here, we use the playbook to perform tasks with the outcome of a binary image containing all configuration files on compile time. The only remote execution at runtime on the network device may be a sysupgrade-command of the final binary.

We follow the common ansible scheme of locations and hosts. We see a location as an autonomous layer 2 domain connected with other locations in a layer 3 fashion. We call these layer 2 constructions a core-router setup implying only one router is acting as a gateway and provides services, like DHCP. Further, these routers maintain layer 3 connectivity to other locations with mesh routing daemons like babeld. A core setup can have an unbound number of access points. As a layer 2 domain, a network client can roam between all devices, and no routing is done inside the location. Mapping that on our playbook, the location contains the network plan and also service descriptions that are valid for all hosts inside a location. Host entities describe the physical or virtual network entity by its actual hardware, e.g. Belkin RT3200 router, and can also override service descriptions set by the location. The mapping between hosts and location is done inside the host's definition by the location variable.

The image compilation takes the variables defined by the hosts and location files to generate the OpenWrt config syntax for each physical or virtual host. The generation is based on template files written in the Jinja language. Based on the actual hardware, different files are included to fit the underlying system and drivers, e.g. some drivers expect network config concerning the distributed switching architecture, and some use the legacy sw-config format. Based on the predefined roles, core-router, access point, and gateway, a customized set of tasks are executed. The last step is to download the correct OpenWrt-Imagebuilder for the host and give it all generated config files. The Imagebuilder generates a binary image embedded with the customized config for this one host in the particular location. Flashing this image to a router will set the router after boot directly in the correct operating state. Further, this router will not be able to lose any of its configurations since it is embedded into its image.

If we need someone to reproduce our setup, the person can just generate the image for the involved routers, aka hosts, and provision them. Everyone can reproduce our setup and can work with us on our configurations from all over the world. In the future, it may be possible to abstract the actual router hardware with QEMU opening new interesting use cases.

</details>

## Getting Started

Using bbb-configs is quite simple. In the sections below you can find simple introductions to what you can do with bbb-configs. But before you can get started you might need to install some dependencies so everything will work properly.

### 1. Install OpenWRT build dependencies

First install the OpenWRT build dependencies. You can find the dependencies for your specific Linux distribution [here](https://openwrt.org/docs/guide-developer/toolchain/install-buildsystem#linux_gnu-linux_distributions). As of 07/2025 there arent all dependencies available for Apple M-Chips.

### 2. Install BBB-configs dependencies

Now install the BBB-configs dependencies. Depending on your distributions you might need to use a different package management system than `apt`.

```sh
apt update
apt install -y jq
python3 -m venv venv
source venv/bin/activate
pip3 install -r requirements.txt
```

### 3. What do you want to set up?

**often needed**

- <details>
  <summary>images</summary>

  #### Generate images

  You can generate images using the generate-images script that brings up a menu

  ```sh
  ./generate-images.sh
  ```

  or by passing locations or hostnames as comma separated list even with wildcards if properly quoted

  ```sh
  ./generate-images.sh location1,host1,host2,location2,"host-*","location-*"
  ```

  or by passing running the ansible playbook directly with a limit parameter containing locations or hosts as a comma separated list.

  Note: Locations must be prefixed witch `location_` and within the location name `-` must be converted to `_`.

  ```sh
  ansible-playbook play.yml --limit location_loc_name,host --tags image
  ```
  #### Flash images

  After building firmware images you can update multiple routers using the mass-update script, which updates every node,that has an image in `tmp/images/`. This works best using SSH keys for authentication.

  Another suitable way to flash our image might be the web GUI or via your terminal using `scp`.

  ```
  ./mass-update.sh
  ```
  </details>
- <details>
  <summary>locations</summary>

  #### Set up new location

     1. Create a location file in the `locations` directory. You might want to copy an existing location to make your start more easy.
     2. Run the image creation as shown in the commands above (image will be in `tmp/images` directory).
     3. Flash the image to your router
     4. Secure the router by setting a root password using SSH or the web interface.
     5. Done!

    Have a look at the [Developers Guide](DEVELOPER.md) for more information.


     <!-- TODO -> create example location which people can copy to start set up their own location with examples and explanations of what you can do -->

  </details>

**rarely needed**

- <details>
  <summary>models</summary>

  Take a look at this section in DEVELOPER.md: [model-files](https://github.com/freifunk-berlin/bbb-configs/blob/main/DEVELOPER.md#groups_vars)

  </details>
- <details>
  <summary>gateways</summary>
  <br>
  This section is not finished yet, feel free to contribute.

  </details>

### 4. Contributing guidelines

To contribute your work, it is helpful to stick to the [contributing guidelines](https://github.com/freifunk-berlin/bbb-configs/blob/main/CONTRIBUTING.md#contributing-to-bbb-configs) so contributions are easy to understand and standardised.

### 5. Ansible Introduction

Ansible is a suite of software tools that enables infrastructure as code. It is open-source and the suite includes software provisioning, configuration management, and application deployment functionality.[[1]](https://en.wikipedia.org/wiki/Ansible_(software)) Ansible playbooks offer simple, repeatable, and reusable execution of tasks making them perfectly fit into the Freifunk world. We map these tasks in files following the YAML format and integrate them into our playbook. We follow the common ansible scheme of locations and hosts.

#### How to get started?

Make sure to install ansible and clone the bbb-configs repository. Also don`t forget to check your dependencies.

Depending on your system you might need more requirements. If something fails check out [this OpenWRT page](https://openwrt.org/docs/guide-developer/toolchain/install-buildsystem).

## Developers and Maintainers

If you want to use bbb-configs to work on a fork of the code yourself or do something else you should start reading the [FAQ](FAQ.md) and [Developers Guide](DEVELOPER.md).

## Support Information

* [Support Chat](https://matrix.to/#/#berlin.freifunk.net:matrix.org): Channel `#berlin.freifunk.net` on **matrix.org**.
* [Mailing List](https://lists.berlin.freifunk.net/cgi-bin/mailman/listinfo/berlin): For usage, support, discussions and hardware advise.
