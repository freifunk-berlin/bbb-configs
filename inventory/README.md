
# Inventory construction

Inventory data is used to generate host-specific OpenWrt config files,
which are then combined into an image file that can be flashed to a device.

Data model concepts are most easily explained by example,
so please also check out the location files in the `locations/` directory.
We have one file per network location, and one or more hosts in each location.
Ansible had groups and hosts, one file per host, which wasn't practical for us.

There are five (now four) stages that construct our inventory data:

1. The base inventory script
  - Handled by Ansible's "script" inventory plugin.
  - Translates our location-centered data model to Ansible's data model.
  - It collects the hostvars for all hosts, which consist of the host object
    in a location file, merged with the surrounding location object.
  - See documentation in `base_inventory` for more details.
2. `host_vars/`
  - In earlier times we used individual files in `host_vars/`.
3. Keyed groups, pt. 1
  - Handled by Ansible's "constructed" inventory plugin.
  - Injects additional data based on certain property values.
  - There are two parts so that new data from part 1 can set properties
    that result in more new data in part 2 (e.g. `model` and OpenWrt version).
  - This stage handles `target`, `model`, and `role`.
4. Keyed groups, pt. 2
  - Same, but handles `target` and `openwrt_version`.
5. Merge vars
  - Handled by Ansible's "merge_vars" action plugin.
  - All hostvars construction so far was only able to overwrite properties,
    but in some cases we need to merge with the existing property.
  - For specific properties, a "merge var" can be set:
    `packages: ["some-pkg"]` and `xxx__packages__to_merge: ["another-pkg"]`
    where `xxx` is an arbitrary name to allow for multiple merge vars.
    For this arbitrary name we usually pick something that describes the
    scope we're currently in, e.g. `location__packages__to_merge`.
  - These merge vars are merged together into one
    before any templates or tasks make use of hostvars.
  - Handles `ssh_keys`, `packages`, `sysctl`, `rclocal`,
    `disabled_services`, `wireless_profiles`, `channel_assignments_*`.
