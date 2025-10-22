#!/usr/bin/env python3
"""
Check for overlapping IPv4/IPv6 prefixes across all location files and
ensure all prefixes are inside the allowed Freifunk Berlin ranges.

Exit codes:
 0 - OK
 1 - any issue found (overlap or out-of-range)
"""
import glob
import ipaddress
import sys

import yaml

# Allowed Freifunk Berlin ip ranges
ALLOWED_IPV4 = [
    ipaddress.ip_network("10.31.0.0/16"),
    ipaddress.ip_network("10.36.0.0/16"),
    ipaddress.ip_network("10.230.0.0/16"),
    ipaddress.ip_network("10.248.0.0/14"),
]

ALLOWED_IPV6 = [
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


def load_prefixes(paths):
    prefixes = []
    for p in paths:
        try:
            with open(p) as f:
                doc = yaml.safe_load(f) or {}
        except Exception:
            continue

        # Collect network prefixes from networks[]
        for n in doc.get("networks") or []:
            pr = n.get("prefix")
            if not pr:
                continue
            try:
                net = ipaddress.ip_network(pr, strict=False)
            except Exception:
                # treat unparsable prefix as error
                prefixes.append((p, pr, None))
                continue
            prefixes.append((p, pr, net))

        # Collect top-level ipv6_prefix if present
        ipv6 = doc.get("ipv6_prefix")
        if ipv6:
            try:
                net = ipaddress.ip_network(ipv6, strict=False)
            except Exception:
                prefixes.append((p, ipv6, None))
            else:
                prefixes.append((p, ipv6, net))

    return prefixes


def is_within_allowed(net: ipaddress._BaseNetwork) -> bool:
    if net.version == 4:
        return any(net.subnet_of(a) for a in ALLOWED_IPV4)
    if net.version == 6:
        return any(net.subnet_of(a) for a in ALLOWED_IPV6)
    return False


def main():
    paths = sys.argv[1:] if len(sys.argv) > 1 else glob.glob("locations/*.yml")
    prefixes = load_prefixes(paths)

    issue_found = False

    # 1) Validate membership in allowed ranges (IPv4 and IPv6)
    for ppath, pstr, net in prefixes:
        if net is None:
            print(f"Unparsable: {ppath}:{pstr} could not be parsed as an IP network")
            issue_found = True
            continue

        if not is_within_allowed(net):
            print(
                f"OutOfRange: {ppath}:{pstr} not inside allowed Freifunk Berlin ranges"
            )
            issue_found = True

    # 2) Detect overlaps within each IP family
    for i in range(len(prefixes)):
        for j in range(i + 1, len(prefixes)):
            a = prefixes[i][2]
            b = prefixes[j][2]
            # skip unparsable entries
            if a is None or b is None:
                continue
            if a.version != b.version:
                continue
            try:
                if a.overlaps(b):
                    print(
                        f"Overlap: {prefixes[i][0]}:{prefixes[i][1]} overlaps with {prefixes[j][0]}:{prefixes[j][1]}"
                    )
                    issue_found = True
            except Exception:
                # defensive: ignore weird comparison errors
                continue

    if issue_found:
        print("One or more issues found (overlaps or out-of-range prefixes)")
        sys.exit(1)

    print("No issues: prefixes are inside allowed ranges and no overlaps detected")
    sys.exit(0)


if __name__ == "__main__":
    main()
