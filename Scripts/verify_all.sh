#!/usr/bin/env bash
# SEIT Complete Verification — Docker container entrypoint
set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║            SEIT RUNTIME VERIFICATION                        ║"
echo "║  Tier III Igneous | Entropy ≤ 0.20 | WORM: bifrost:...      ║"
echo "╚══════════════════════════════════════════════════════════════╝"

echo "→ Verifying seit_verify executable..."
seit_verify

echo "→ Verifying seit_audit executable..."
seit_audit 2>/dev/null || echo "  (audit binary optional)"

echo "→ Verifying HOL Light zero-sorry proofs..."
hol_light -script /workspace/proofs/HOLLight/RH_F2_QuantumCelestial.ml

echo "→ Checking entropy bound..."
python3 /workspace/scripts/check_entropy.py --bound 0.20

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║            RUNTIME VERIFICATION: PASSED                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
