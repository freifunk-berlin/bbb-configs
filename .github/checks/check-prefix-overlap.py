#!/usr/bin/env python3
"""
Check for overlapping IPv4/IPv6 prefixes across all location files and
ensure all prefixes are inside the allowed Freifunk Berlin ranges.

Networks with nat: true may use non-Freifunk IPv4 (e.g. RFC1918) and are
exempt from the Freifunk-range check. Overlaps between two nat prefixes are
ignored across locations (RFC1918 reuse); overlaps within one location or
involving a non-nat prefix are still reported.

If location files are passed as arguments, all locations are still loaded
to find overlaps with them, but only issues involving the passed files are
reported.

Exit codes:
 0 - OK
 1 - any issue found (overlap or out-of-range)
"""

# pylint: disable=invalid-name,missing-function-docstring,broad-exception-caught
import glob
import ipaddress
import itertools
import os
import sys

import yaml

# Allowed Freifunk ip ranges of Berlin and Fürstenwalde as defined in
# the icvpn meta repo https://github.com/freifunk/icvpn-meta/
ALLOWED_IPV4 = [
    # Berlin
    ipaddress.ip_network("10.31.0.0/16"),
    ipaddress.ip_network("10.36.0.0/16"),
    ipaddress.ip_network("10.230.0.0/16"),
    ipaddress.ip_network("10.248.0.0/14"),
    # Fürstenwalde
    ipaddress.ip_network("10.30.96.0/19"),
]

ALLOWED_IPV6 = [
    # Berlin
    ipaddress.ip_network("2001:bf7:750::/44"),
    ipaddress.ip_network("2001:bf7:760::/44"),
    ipaddress.ip_network("2001:bf7:770::/44"),
    ipaddress.ip_network("2001:bf7:780::/44"),
    ipaddress.ip_network("2001:bf7:790::/44"),
    ipaddress.ip_network("2001:bf7:800::/44"),
    ipaddress.ip_network("2001:bf7:810::/44"),
    ipaddress.ip_network("2001:bf7:820::/44"),
    ipaddress.ip_network("2001:bf7:830::/44"),
    ipaddress.ip_network("2001:bf7:840::/44"),
    ipaddress.ip_network("2001:bf7:850::/44"),
    ipaddress.ip_network("2001:bf7:860::/44"),
]


def load_prefixes(paths, unreadable):
    # entries: (path, prefix_str, network_or_None, is_nat)
    prefixes = []
    for p in paths:
        try:
            with open(p, encoding="utf-8") as f:
                doc = yaml.safe_load(f) or {}
        except Exception as e:
            print(f"Unreadable: {p} could not be loaded: {e}")
            unreadable.append(p)
            continue

        # Collect network prefixes from networks[]
        for n in doc.get("networks") or []:
            pr = n.get("prefix")
            if not pr:
                continue
            is_nat = bool(n.get("nat"))
            try:
                net = ipaddress.ip_network(pr, strict=False)
            except Exception:
                # treat unparsable prefix as error
                prefixes.append((p, pr, None, is_nat))
                continue
            prefixes.append((p, pr, net, is_nat))

        # Collect top-level ipv6_prefix if present (never nat)
        ipv6 = doc.get("ipv6_prefix")
        if ipv6:
            try:
                net = ipaddress.ip_network(ipv6, strict=False)
            except Exception:
                prefixes.append((p, ipv6, None, False))
            else:
                prefixes.append((p, ipv6, net, False))

    return prefixes


def is_within_allowed(net: ipaddress._BaseNetwork) -> bool:
    if net.version == 4:
        return any(net.subnet_of(a) for a in ALLOWED_IPV4)
    if net.version == 6:
        return any(net.subnet_of(a) for a in ALLOWED_IPV6)
    return False


def find_overlaps(prefixes, checked) -> bool:
    found = False
    for (path_a, str_a, a, nat_a), (path_b, str_b, b, nat_b) in itertools.combinations(
        prefixes, 2
    ):
        # skip unparsable entries
        if a is None or b is None:
            continue
        if a.version != b.version:
            continue
        if path_a not in checked and path_b not in checked:
            continue
        # Allow the same RFC1918 NAT prefix at different locations
        if nat_a and nat_b and path_a != path_b:
            continue
        try:
            if a.overlaps(b):
                print(f"Overlap: {path_a}:{str_a} overlaps with {path_b}:{str_b}")
                found = True
        except Exception:
            # defensive: ignore weird comparison errors
            continue
    return found


def main():
    all_paths = [os.path.normpath(p) for p in glob.glob("locations/*.yml")]
    if len(sys.argv) > 1:
        checked = {os.path.normpath(p) for p in sys.argv[1:]}
    else:
        checked = set(all_paths)
    paths = sorted(set(all_paths) | checked)

    unreadable = []
    prefixes = load_prefixes(paths, unreadable)

    issue_found = any(p in checked for p in unreadable)

    # 1) Validate membership in allowed ranges (IPv4 and IPv6)
    for ppath, pstr, net, is_nat in prefixes:
        if ppath not in checked:
            continue
        if net is None:
            print(f"Unparsable: {ppath}:{pstr} could not be parsed as an IP network")
            issue_found = True
            continue

        # nat IPv4 may be RFC1918 (or other non-Freifunk); still check IPv6
        if is_nat and net.version == 4:
            continue

        if not is_within_allowed(net):
            print(
                f"OutOfRange: {ppath}:{pstr} not inside allowed Freifunk Berlin ranges"
            )
            issue_found = True

    # 2) Detect overlaps within each IP family
    if find_overlaps(prefixes, checked):
        issue_found = True

    if issue_found:
        print("One or more issues found (overlaps or out-of-range prefixes)")
        sys.exit(1)

    print("No issues: prefixes are inside allowed ranges and no overlaps detected")
    sys.exit(0)


if __name__ == "__main__":
    main()
