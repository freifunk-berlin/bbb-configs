#!/usr/bin/env python
"""
Validate YAML files against a Yamale schema.

Exit codes:
 0 - all files are valid
 1 - at least one file failed to validate
 2 - schema file not found
"""

import argparse
import sys

import yamale
from yamale.validators import DefaultValidators

parser = argparse.ArgumentParser(
    description="Validate YAML files against a Yamale schema"
)
parser.add_argument("schema", help="path to the Yamale schema file")
parser.add_argument("files", nargs="+", help="YAML files to validate")
args = parser.parse_args()

validators = DefaultValidators.copy()

try:
    schema = yamale.make_schema(args.schema, validators=validators)
except FileNotFoundError:
    print(f"Schema file {args.schema} not found, can't verify")
    sys.exit(2)

HAVE_FAILED = False

for fname in args.files:
    print(f"Validating {fname}")
    data = yamale.make_data(fname)
    try:
        yamale.validate(schema, data)
    except yamale.YamaleError as e:
        print(f"{fname} failed to validate")
        HAVE_FAILED = True
        for result in e.results:
            print(result)


sys.exit(1 if HAVE_FAILED else 0)
