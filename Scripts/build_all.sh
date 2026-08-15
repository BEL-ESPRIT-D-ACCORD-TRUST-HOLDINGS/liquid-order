#!/usr/bin/env bash
# SEIT Certified Build Script
# Tier III Igneous | WORM: bifrost:4b565498-9afc-4782-af4a-c6b11a5d0058
# Entropy bound: 0.20

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

SEIT_TIER="Tier III Igneous"
WORM_CHAIN="bifrost:4b565498-9afc-4782-af4a-c6b11a5d0058"
ENTROPY_BOUND=0.20

log()     { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC} $*"; }
error()   { echo -e "${RED}✗${NC} $*"; exit 1; }

verify_env() {
    log "Verifying build environment..."
    command -v lean      >/dev/null 2>&1 || error "Lean 4 not found"
    command -v lake      >/dev/null 2>&1 || error "Lake not found"
    command -v hol_light >/dev/null 2>&1 || error "HOL Light not found"
    command -v q         >/dev/null 2>&1 || warn  "KDB+ not found (optional)"
    lean --version | grep -q "4.8.0"     || error "Lean 4.8.0 required"
    success "Environment verified"
}

build_lean4() {
    log "Building Lean 4 workspace..."
    lake update
    lake build +SnapKitty
    lake build seit_verify seit_audit
    success "Lean 4 build complete"
}

verify_hol_light() {
    log "Verifying HOL Light zero-sorry proofs..."
    hol_light -script proofs/HOLLight/RH_F2_QuantumCelestial.ml
    success "HOL Light verification complete"
}

run_seit_verification() {
    log "Running SEIT certification verification..."
    ./build/bin/seit_verify
    success "SEIT verification complete"
}

check_entropy() {
    log "Checking entropy bound (≤ $ENTROPY_BOUND)..."
    python3 scripts/check_entropy.py --bound "$ENTROPY_BOUND"
    success "Entropy bound verified"
}

ARTIFACT_HASH=""

worm_commit() {
    log "Computing artifact hashes..."
    find build -name "*.olean" -type f 2>/dev/null | sort | xargs sha256sum > hashes.txt
    sha256sum proofs/HOLLight/RH_F2_QuantumCelestial.ml >> hashes.txt
    ARTIFACT_HASH=$(sha256sum hashes.txt | cut -d' ' -f1)
    log "Artifact hash: $ARTIFACT_HASH"

    log "Committing to Bifrost WORM chain: $WORM_CHAIN"
    python3 scripts/worm_commit.py \
        --chain    "$WORM_CHAIN" \
        --artifacts hashes.txt \
        --tier     "$SEIT_TIER" \
        --entropy  "$ENTROPY_BOUND" \
        --hash     "$ARTIFACT_HASH"
    success "WORM commit complete"
}

verify_worm() {
    log "Verifying WORM commit..."
    python3 scripts/worm_verify.py \
        --chain         "$WORM_CHAIN" \
        --expected-hash "$ARTIFACT_HASH"
    success "WORM verification complete"
}

generate_audit() {
    log "Generating SEIT audit report..."
    python3 scripts/generate_audit.py \
        --worm-chain "$WORM_CHAIN" \
        --tier       "$SEIT_TIER" \
        --entropy    "$ENTROPY_BOUND" \
        --output     "audit_report_$(date +%s).json"
    success "Audit report generated"
}

main() {
    log "SEIT Certified Build Pipeline"
    log "Tier: $SEIT_TIER | WORM: $WORM_CHAIN | Entropy: $ENTROPY_BOUND"

    verify_env
    build_lean4
    verify_hol_light
    run_seit_verification
    check_entropy

    if [[ "${GITHUB_REF:-}" == "refs/heads/main" ]] || [[ "${BUILD_TRIGGER:-}" == "schedule" ]]; then
        worm_commit
        verify_worm
        generate_audit
    else
        log "Skipping WORM commit (not main branch)"
    fi

    success "SEIT Certified Build Pipeline COMPLETE"
}

main "$@"
