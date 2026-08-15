#!/usr/bin/env python3
"""Bifrost WORM Chain Verification — verify commit integrity and provenance."""

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path


class BifrostVerify:
    def __init__(self, chain_id: str):
        self.chain_id = chain_id
        self.endpoint = os.environ.get("BIFROST_ENDPOINT", "https://bifrost.snapkitty.io")

    def verify(self, expected_hash: str) -> dict:
        # Load most recent receipt if present
        receipts = sorted(Path(".").glob("worm_commit_*.json"), key=lambda p: p.stat().st_mtime)
        if receipts:
            with open(receipts[-1]) as f:
                receipt = json.load(f)
            actual_hash = receipt.get("payload", {}).get("artifact_hash", "")
            match = actual_hash == expected_hash
            return {
                "verified":      match,
                "chain_id":      self.chain_id,
                "commit_id":     receipt.get("commit_id"),
                "expected_hash": expected_hash,
                "actual_hash":   actual_hash,
                "match":         match,
            }
        # No receipt: report as unverified (not failed)
        return {
            "verified":      False,
            "chain_id":      self.chain_id,
            "commit_id":     None,
            "expected_hash": expected_hash,
            "actual_hash":   None,
            "match":         False,
            "note":          "No WORM receipt found — commit step may not have run",
        }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--chain",         required=True)
    parser.add_argument("--expected-hash", required=True)
    args = parser.parse_args()

    result = BifrostVerify(args.chain).verify(args.expected_hash)
    print(json.dumps(result, indent=2))

    if not result["verified"] or not result["match"]:
        print("VERIFICATION FAILED", file=sys.stderr)
        sys.exit(1)

    print("VERIFICATION PASSED")


if __name__ == "__main__":
    main()
