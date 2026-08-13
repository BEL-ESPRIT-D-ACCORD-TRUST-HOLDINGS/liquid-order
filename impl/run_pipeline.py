"""
LiquidOrder end-to-end pipeline runner.

Trust chain:
  Sovereign-Covenant Spec
    -> HOL propositions  (static, from Obligations registry)
    -> Solver            [UNTRUSTED — produces certificates]
    -> ProofCertificate
    -> Kernel replay     [TRUSTED — only path to PROVED]
    -> Manifest JSON
    -> (optional) Track 3 numerical test

Usage:
  python run_pipeline.py [--certs DIR] [--track3]

--certs DIR   : directory of JSON certificate files (solver output)
--track3      : run Track 3 numerical test (only if all REQUIRED theorems PROVED)
"""

import argparse
import json
import os
import sys
from dataclasses import dataclass, field, asdict
from enum import Enum
from typing import Optional

# ---------------------------------------------------------------------------
# Epistemic status enumeration (mirrors Haskell EpistemicStatus)
# ---------------------------------------------------------------------------

class EpistemicStatus(str, Enum):
    PROVED                   = "PROVED"
    REFUTED                  = "REFUTED"
    UNRESOLVED               = "UNRESOLVED"
    CORPUS_OBSERVATION       = "CORPUS_OBSERVATION"
    CANDIDATE_INVARIANT      = "CANDIDATE_INVARIANT"
    CONJECTURE               = "CONJECTURE"
    METHOD_LIMIT             = "METHOD_LIMIT"
    EMPIRICAL_NUMERICAL_RESULT = "EMPIRICAL_NUMERICAL_RESULT"

# ---------------------------------------------------------------------------
# Obligation registry (Python mirror of Obligations.hs)
# These are the 10 required theorems; status starts UNRESOLVED.
# ---------------------------------------------------------------------------

OBLIGATIONS = [
    {"id": "LO-SC-001", "proposition": "Derive_{Gamma_SC} in FP",
     "assumptions": ["H1-Acyclic", "H2-AllFP", "H4-RootsFixed"],
     "dependencies": [], "required": True},
    {"id": "LO-SC-002", "proposition": "Check_{Gamma_SC} in P",
     "assumptions": ["H1-Acyclic", "H2-AllFP", "H3-AllP", "H4-RootsFixed"],
     "dependencies": ["LO-SC-001"], "required": True},
    {"id": "LO-SC-003", "proposition": "forall A B. RewriteStar(A,B) -> N(A)=N(B)",
     "assumptions": ["NormalizationAbsorption-PerRule"],
     "dependencies": [], "required": True},
    {"id": "LO-SC-004", "proposition": "EquivalenceRelation(EquivalentN)",
     "assumptions": [], "dependencies": ["LO-SC-003"], "required": True},
    {"id": "LO-SC-005", "proposition": "N(A)=N(B) -> F(N(A))=F(N(B))",
     "assumptions": [], "dependencies": ["LO-SC-004"], "required": True},
    {"id": "LO-SC-006", "proposition": "Serialize injective",
     "assumptions": ["FixedWidthEncoding", "RationalsNormalized"],
     "dependencies": [], "required": True},
    {"id": "LO-SC-007", "proposition": "EquivalentN(A,B) -> ClassHash(A)=ClassHash(B)",
     "assumptions": [], "dependencies": ["LO-SC-005", "LO-SC-006"], "required": True},
    {"id": "LO-SC-008", "proposition": "SemanticSoundness(AllNormalizationPhases)",
     "assumptions": ["SemanticPreservation-PerPhase"],
     "dependencies": [], "required": True},
    {"id": "LO-SC-009", "proposition": "ValidRenaming(rho) /\\ Resolved(R) -> N(Rename(rho,R))=N(R)",
     "assumptions": ["StructuralSignatureIndependence"],
     "dependencies": ["LO-SC-003"], "required": True},
    {"id": "LO-SC-010", "proposition": "UnresolvedAutomorphism(R) -> HALT",
     "assumptions": [], "dependencies": [], "required": True},
    {"id": "LO-SC-P",   "proposition": "FactorsThrough N P_external (Track 2 discovery)",
     "assumptions": ["ExternalPropertyIndependence", "CorpusObservation"],
     "dependencies": ["LO-SC-005"], "required": False},
]

# ---------------------------------------------------------------------------
# Certificate schema (what the solver produces)
# ---------------------------------------------------------------------------

@dataclass
class ProofCertificate:
    theorem_id:    str
    proposition:   str
    assumptions:   list
    derivation:    dict          # rule tree (validated by kernel replay)
    dependencies:  list

# ---------------------------------------------------------------------------
# Kernel replay (trusted layer)
# Validates derivation structure. ONLY this function may produce PROVED status.
# ---------------------------------------------------------------------------

KERNEL_PRIMITIVE_RULES = {
    "ASSUME", "REFL", "BETA", "ABS_CONG", "APP_CONG",
    "EQ_MP", "DEDUCT", "INST", "TYPE_INST", "SEQ",
}

def kernel_replay(cert: dict) -> tuple:
    """
    Returns (status: EpistemicStatus, reason: str).
    PROVED only if derivation tree uses only primitive kernel rules.
    """
    derivation = cert.get("derivation", {})
    if not derivation:
        return EpistemicStatus.UNRESOLVED, "No derivation provided"

    errors = _validate_derivation(derivation)
    if errors:
        return EpistemicStatus.REFUTED, f"Kernel rejection: {errors[0]}"

    # Verify conclusion matches stated proposition
    conclusion = derivation.get("conclusion")
    if conclusion != cert.get("proposition"):
        return (EpistemicStatus.REFUTED,
                f"Conclusion mismatch: derivation concludes '{conclusion}' "
                f"but certificate states '{cert.get('proposition')}'")

    return EpistemicStatus.PROVED, "KernelReplay: VALID"

def _validate_derivation(node: dict) -> list:
    """Walk derivation tree; return list of errors (empty = valid)."""
    rule = node.get("rule")
    if rule not in KERNEL_PRIMITIVE_RULES:
        return [f"Unknown rule '{rule}' — not a kernel primitive"]

    errors = []
    for child in node.get("premises", []):
        errors.extend(_validate_derivation(child))
    return errors

# ---------------------------------------------------------------------------
# Certificate digest (content-addressed, not cryptographic)
# ---------------------------------------------------------------------------

def cert_digest(cert: dict) -> str:
    import hashlib
    blob = json.dumps(cert, sort_keys=True).encode()
    return hashlib.sha256(blob).hexdigest()[:16]

# ---------------------------------------------------------------------------
# Load certificates from directory
# Each file: {theorem_id}.cert.json
# ---------------------------------------------------------------------------

def load_certificates(cert_dir: str) -> dict:
    certs = {}
    if not cert_dir or not os.path.isdir(cert_dir):
        return certs
    for fname in os.listdir(cert_dir):
        if fname.endswith(".cert.json"):
            fpath = os.path.join(cert_dir, fname)
            with open(fpath) as f:
                cert = json.load(f)
            tid = cert.get("theorem_id")
            if tid:
                certs[tid] = cert
    return certs

# ---------------------------------------------------------------------------
# Build manifest
# ---------------------------------------------------------------------------

def build_manifest(certs: dict) -> dict:
    entries = []
    errors  = []

    for ob in OBLIGATIONS:
        tid    = ob["id"]
        cert   = certs.get(tid)
        status = EpistemicStatus.UNRESOLVED
        digest = "NONE"
        reason = ""

        if cert is not None:
            status, reason = kernel_replay(cert)
            digest = cert_digest(cert)

        entry = {
            "id":            tid,
            "proposition":   ob["proposition"],
            "assumptions":   ob["assumptions"],
            "dependencies":  ob["dependencies"],
            "cert_digest":   digest,
            "kernel_status": status.value,
            "required":      ob["required"],
            "reason":        reason,
        }
        entries.append(entry)

        if ob["required"] and status != EpistemicStatus.PROVED:
            errors.append(
                f"BUILD FAILURE: required theorem {tid} "
                f"has kernel status {status.value} — "
                "kernel-checked certificate required"
            )

    return {
        "version":  "v2",
        "build_ok": len(errors) == 0,
        "theorems": entries,
        "errors":   errors,
    }

# ---------------------------------------------------------------------------
# Track 3 — isolated, runs ONLY after all required theorems PROVED
# The numerical target is NOT embedded in this file.
# ---------------------------------------------------------------------------

def run_track3(manifest: dict) -> dict:
    if not manifest["build_ok"]:
        return {
            "status":  "NOT_RUN",
            "reason":  "Track 3 blocked: required theorems unproved",
            "result":  None,
        }

    # The actual computation is in omega_extract.py (separate, blind)
    omega_script = os.path.join(os.path.dirname(__file__), "omega_extract.py")
    if not os.path.exists(omega_script):
        return {
            "status": "NOT_RUN",
            "reason": "omega_extract.py not found — create it before blind execution",
            "result": None,
        }

    import subprocess
    try:
        result = subprocess.run(
            [sys.executable, omega_script],
            capture_output=True, text=True, timeout=300
        )
        return {
            "status":  EpistemicStatus.EMPIRICAL_NUMERICAL_RESULT.value,
            "reason":  "Blind numerical test executed",
            "result":  result.stdout.strip(),
            "stderr":  result.stderr.strip(),
        }
    except subprocess.TimeoutExpired:
        return {
            "status": "METHOD_LIMIT",
            "reason": "Track 3 execution timed out",
            "result": None,
        }

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="LiquidOrder pipeline runner")
    parser.add_argument("--certs", default=None,
                        help="Directory containing .cert.json files (solver output)")
    parser.add_argument("--track3", action="store_true",
                        help="Run Track 3 numerical test after verification")
    parser.add_argument("--out", default=None,
                        help="Write manifest JSON to this file")
    args = parser.parse_args()

    print("=== LiquidOrder Pipeline v2 ===\n")
    print(f"Stage 1-4: Spec + HOL propositions loaded ({len(OBLIGATIONS)} obligations)")

    certs = load_certificates(args.certs)
    print(f"Stage 5: Certificates loaded: {len(certs)} / {len(OBLIGATIONS)}")

    manifest = build_manifest(certs)
    print(f"Stage 6: Kernel replay complete")

    # Print manifest table
    print()
    print(f"{'ID':<14} {'STATUS':<26} {'REQ':<5} {'DIGEST'}")
    print("-" * 70)
    for entry in manifest["theorems"]:
        req = "YES" if entry["required"] else "no"
        print(f"{entry['id']:<14} {entry['kernel_status']:<26} {req:<5} {entry['cert_digest'][:16]}")

    print()
    print(f"Build: {'OK' if manifest['build_ok'] else 'FAILED'}")
    for err in manifest["errors"]:
        print(f"  {err}")

    # Track 3
    if args.track3:
        print("\nStage 7: Track 3 (blind numerical test)")
        t3 = run_track3(manifest)
        print(f"  Status: {t3['status']}")
        print(f"  Reason: {t3['reason']}")
        if t3.get("result"):
            print(f"  Result: {t3['result']}")
        manifest["track3"] = t3
    else:
        manifest["track3"] = {"status": "NOT_RUN", "reason": "Pass --track3 to run"}

    # Write output
    out_path = args.out or os.path.join(
        os.path.dirname(__file__), "..", "manifest_v2.json"
    )
    with open(out_path, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"\nManifest written to: {os.path.abspath(out_path)}")

    sys.exit(0 if manifest["build_ok"] else 1)

if __name__ == "__main__":
    main()
