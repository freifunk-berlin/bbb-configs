#!/usr/bin/env python3
import sys
from pathlib import Path

import yaml


def load_yaml(file_path):
    with open(file_path) as f:
        return yaml.safe_load(f)


def check_mgmt_assignments(file_path):
    data = load_yaml(file_path)

    mgmt_networks = [
        net for net in data.get("networks", []) if net.get("role") == "mgmt"
    ]
    if not mgmt_networks:
        print(f"Skipping mgmt check for location without mgmt network: {file_path}")
        return []

    assignments = set()
    for net in mgmt_networks:
        assignments.update(net.get("assignments", {}).keys())

    hosts = [h["hostname"] for h in data.get("hosts", []) if "hostname" in h]
    if not hosts:
        return []

    return [h for h in hosts if h not in assignments]


def main(files):
    error_found = False
    for file_path in files:
        path = Path(file_path)
        if not path.is_file():
            print(f"File {file_path} does not exist, skipping.")
            continue

        missing_hosts = check_mgmt_assignments(file_path)
        if missing_hosts:
            for host in missing_hosts:
                print(
                    f"Error: Host {host} in {file_path} is not present in mgmt assignments"
                )
            error_found = True

    if error_found:
        sys.exit(1)
    else:
        print("All hosts have mgmt assignments")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        files_to_check = sys.argv[1:]
    else:
        files_to_check = [str(p) for p in Path("locations").glob("*.yml")]
    main(files_to_check)
