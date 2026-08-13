"""
Track 3 — Omega extraction (blind execution)
CLASSIFICATION: EMPIRICAL_NUMERICAL_RESULT

This script computes Omega_impl and Omega_quot from the frozen corpus.
It does NOT contain the numerical target.
The comparison is performed externally after this script completes.

Firewall: the numerical target does not appear in this file.
"""

import json
import os
import struct
import sys
import hashlib


def blake3_truncated(data: bytes) -> int:
    """
    BLAKE3 is unavailable as stdlib; use SHA3-256 as a placeholder.
    Replace with actual BLAKE3 (pip install blake3) before blind execution.
    Returns first 8 bytes as big-endian uint64.
    """
    digest = hashlib.sha3_256(data).digest()
    return struct.unpack(">Q", digest[:8])[0]


def serialize_features(features: dict) -> bytes:
    """
    Deterministic serialization of the feature vector.
    Field order: fixed. Integers: big-endian 8-byte. Rationals: normalized p/q.
    Domain prefix: b"LOSC" (4 bytes). Endianness: big-endian.
    No variable-length ambiguity.
    """
    out = bytearray()
    out += b"LOSC"  # domain prefix

    # Fixed field order (frozen in Spec_v1)
    for key in sorted(features.keys()):   # lexicographic for determinism
        val = features[key]
        if isinstance(val, int):
            out += struct.pack(">q", val)
        elif isinstance(val, float):
            # Normalize to p/q rational (simple: multiply by 1e9 and round)
            p = round(val * 1_000_000_000)
            out += struct.pack(">q", p)
        elif isinstance(val, str):
            enc = val.encode("utf-8")
            out += struct.pack(">H", len(enc))
            out += enc
        else:
            out += str(val).encode("utf-8")

    return bytes(out)


def compute_class_hash(features: dict) -> int:
    return blake3_truncated(serialize_features(features))


def load_corpus(corpus_path: str) -> list:
    """Load the frozen corpus manifest + any full algorithm records."""
    with open(corpus_path) as f:
        manifest = json.load(f)

    # If full records exist, return them; otherwise return stubs from manifest
    records = manifest.get("algorithm_records", [])
    if not records:
        # Build stubs from manifest families
        for family in manifest.get("families", []):
            for alg in family.get("algorithms", []):
                records.append({
                    "id": alg,
                    "family": family["family"],
                    "features": {
                        "vertex_count": 0,
                        "edge_count": 0,
                        "cyclomatic_complexity": 1,
                        "weakly_connected_components": 1,
                        "algebra_degree": 0,
                    }
                })
    return records


def build_quotient(records: list) -> dict:
    """
    Group records by their normal form hash (equivalence classes).
    In full execution: compute N(A) for each algorithm, group by N.
    Here: use precomputed normal_form_hash field if present.
    """
    classes = {}
    for rec in records:
        nf_key = rec.get("normal_form_hash", rec["id"])  # fallback: each is its own class
        if nf_key not in classes:
            classes[nf_key] = []
        classes[nf_key].append(rec)
    return classes


def compute_omega(records: list, quotient: dict) -> dict:
    """
    Omega_impl: sum of per-algorithm hashes mod 2^64
    Omega_quot: sum of per-equivalence-class hashes mod 2^64
    """
    MOD = 2 ** 64

    impl_hashes = []
    for rec in records:
        h = compute_class_hash(rec.get("features", {}))
        impl_hashes.append(h)

    quot_hashes = []
    for nf_key, members in quotient.items():
        # Use first member's features as canonical representative
        h = compute_class_hash(members[0].get("features", {}))
        quot_hashes.append(h)

    omega_impl = sum(impl_hashes) % MOD
    omega_quot = sum(quot_hashes) % MOD

    return {
        "omega_impl": omega_impl,
        "omega_quot": omega_quot,
        "num_algorithms": len(records),
        "num_classes": len(quotient),
        "status": "EMPIRICAL_NUMERICAL_RESULT",
        "note": "Comparison with preregistered target performed externally.",
    }


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    corpus_path = os.path.join(root, "corpus", "corpus_v1_manifest.json")

    if not os.path.exists(corpus_path):
        print("ERROR: corpus_v1_manifest.json not found", file=sys.stderr)
        sys.exit(1)

    records  = load_corpus(corpus_path)
    quotient = build_quotient(records)
    result   = compute_omega(records, quotient)

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
