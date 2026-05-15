#!/usr/bin/env python3
"""Check assignment values in location network configurations."""
# pylint: disable=invalid-name,missing-function-docstring,broad-exception-caught
import ipaddress
import sys
from pathlib import Path

import yaml


def load_yaml(file_path):
    with open(file_path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def calculate_usable_hosts(prefix_str):
    try:
        network = ipaddress.ip_network(prefix_str, strict=False)
    except Exception:
        return None, None, None

    num_addresses = network.num_addresses
    max_host = max(1, num_addresses - 2)
    if num_addresses == 1:
        first_ip = str(network.network_address)
        last_ip = str(network.network_address)
    else:
        first_ip = str(network.network_address + 1)
        last_ip = str(network.network_address + max_host)

    return max_host, first_ip, last_ip


def check_assignments_for_network(location_file, network, vid):
    errors = []
    prefix_str = network.get("prefix")
    if not prefix_str:
        return errors

    try:
        ipaddress.ip_network(prefix_str, strict=False)
    except Exception:
        errors.append(f"{location_file}: VID {vid} - prefix {prefix_str} is invalid")
        return errors

    assignments = network.get("assignments", {})
    if not assignments:
        return errors

    max_host, first_ip, last_ip = calculate_usable_hosts(prefix_str)
    if max_host is None:
        errors.append(
            f"{location_file}: VID {vid} - prefix {prefix_str} could not be parsed"
        )
        return errors

    seen_values = {}
    for host, value in assignments.items():
        if value in seen_values:
            errors.append(
                f"{location_file}: VID {vid} - duplicate assignment value {value} "
                f"(hosts: {seen_values[value]}, {host})"
            )
        else:
            seen_values[value] = host

        if value < 1 or value > max_host:
            if max_host == 1:
                errors.append(
                    f"{location_file}: VID {vid} - assignment {host}: {value} invalid. "
                    f"Value 1 required for single IP (referring to {first_ip})"
                )
            else:
                errors.append(
                    f"{location_file}: VID {vid} - assignment {host}: {value} invalid. "
                    f"Value must be 1 to {max_host} (usable: {first_ip}-{last_ip})"
                )

    return errors


def check_location_file(file_path):
    errors = []
    data = load_yaml(file_path)
    if not data:
        return errors

    networks = data.get("networks", [])
    for network in networks:
        vid = network.get("vid")
        if vid and "assignments" in network:
            errs = check_assignments_for_network(file_path, network, vid)
            errors.extend(errs)

    return errors


def main(files):
    all_errors = []

    if not files:
        files = [str(p) for p in Path("locations").glob("*.yml")]

    for file_path in files:
        path = Path(file_path)
        if not path.is_file():
            print(f"File {file_path} does not exist, skipping.")
            continue

        errors = check_location_file(file_path)
        all_errors.extend(errors)

    if all_errors:
        for error in all_errors:
            print(f"Error: {error}")
        print(f"\nFound {len(all_errors)} assignment error(s)")
        sys.exit(1)
    else:
        print("All assignments are valid")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        files_to_check = sys.argv[1:]
    else:
        files_to_check = [str(p) for p in Path("locations").glob("*.yml")]
    main(files_to_check)
