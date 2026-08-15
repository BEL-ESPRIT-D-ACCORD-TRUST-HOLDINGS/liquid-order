"""
Zero Boolean Verification Layer
================================
The hardcoded γₙ values are FIXTURES for testing the Shadow Spectrum candidate.
They are NOT the definition of the zero set.

Pipeline:
  numeric γ list (fixtures)
       ↓
  complex zeros ρ = 1/2 + iγ
       ↓
  zero-membership predicates
       ↓
  EQUAL / OR / AND / NOT
       ↓
  NAND-only normal form
       ↓
  verify ShadowSpectrum(γ) ∈ spectrum(H_shadow)

The actual theorem remains:
  Spectrum(H_shadow) = {γ : ζ(1/2+iγ) = 0}

This layer can only certify the entries supplied.
It cannot establish that those are ALL zeros.
That requires the mathematical theorem (O4a + O4b in IOM.lean).
"""

import math
import sys
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")


# ---------------------------------------------------------------------------
# NAND Boolean kernel (from ConstraintGraph BooleanKernel)
# ---------------------------------------------------------------------------

def NAND(a: float, b: float) -> float:
    """NAND(a,b) = 1 - ab"""
    return 1.0 - a * b

def NOT(x: float) -> float:
    return NAND(x, x)

def AND(a: float, b: float) -> float:
    return NAND(NAND(a, b), NAND(a, b))

def OR(a: float, b: float) -> float:
    return NAND(NAND(a, a), NAND(b, b))

def IMPLIES(a: float, b: float) -> float:
    return OR(NOT(a), b)

def EQUAL(a: float, b: float) -> float:
    return AND(IMPLIES(a, b), IMPLIES(b, a))


# ---------------------------------------------------------------------------
# Fuzzy EQUAL for real-valued γ (with tolerance)
# Classical EQUAL is for {0,1}; for real γₙ we need approximate equality
# ---------------------------------------------------------------------------

def NEAR(x: float, y: float, tol: float = 1e-6) -> float:
    """Returns 1.0 if |x - y| < tol, 0.0 otherwise.
    Bridges between real values and Boolean {0,1}."""
    return 1.0 if abs(x - y) < tol else 0.0


# ---------------------------------------------------------------------------
# Zero-membership predicate in NAND normal form
# ZeroBool(γ, [γ₁,...,γₙ]) = OR(NEAR(γ,γ₁), OR(NEAR(γ,γ₂), ...))
# ---------------------------------------------------------------------------

def ZeroBool(gamma: float, known_zeros: list[float], tol: float = 1e-4) -> float:
    """
    Boolean membership predicate in NAND normal form.
    Returns 1.0 if γ matches any known zero (within tolerance).
    Returns 0.0 otherwise.

    Expansion:
      ZeroBool(γ, [γ₁]) = NEAR(γ, γ₁)
      ZeroBool(γ, [γ₁,γ₂,...]) = OR(NEAR(γ,γ₁), ZeroBool(γ, [γ₂,...]))

    In NAND-only form:
      OR(a,b) = NAND(NAND(a,a), NAND(b,b))
      so ZeroBool reduces to nested NAND calls.
    """
    if not known_zeros:
        return 0.0
    head = NEAR(gamma, known_zeros[0], tol)
    if len(known_zeros) == 1:
        return head
    tail = ZeroBool(gamma, known_zeros[1:], tol)
    return OR(head, tail)  # OR in NAND normal form


def ZeroBoolNAND(gamma: float, known_zeros: list[float], tol: float = 1e-4) -> float:
    """Explicit NAND-only expansion (same result, shows the primitive)."""
    if not known_zeros:
        return 0.0
    head = NEAR(gamma, known_zeros[0], tol)
    if len(known_zeros) == 1:
        return head
    tail = ZeroBoolNAND(gamma, known_zeros[1:], tol)
    # OR(head, tail) = NAND(NAND(head,head), NAND(tail,tail))
    return NAND(NAND(head, head), NAND(tail, tail))


# ---------------------------------------------------------------------------
# Complex zero representation: ρ = 1/2 + iγ
# ---------------------------------------------------------------------------

def to_rho(gamma: float) -> complex:
    """γ → ρ = 1/2 + iγ"""
    return complex(0.5, gamma)

def from_rho(rho: complex) -> tuple[float, float]:
    """ρ → (Re(ρ), Im(ρ))"""
    return rho.real, rho.imag


# ---------------------------------------------------------------------------
# Shadow Spectrum candidate (from ShadowLaplacianConstruction.lean)
# In the diagonal construction, eigenvalues are candidate_eigenvalues(n)
# This is the placeholder — Ahmad replaces with the actual formula
# ---------------------------------------------------------------------------

def candidate_eigenvalue(n: int) -> float:
    """
    Placeholder candidate eigenvalue sequence.
    Ahmad replaces this with the Monsky-Washnitzer trace formula output.
    Currently: log(n+2) * n / (2π) — diverges, will not match.
    """
    return math.log(n + 2) * n / (2 * math.pi)

def shadow_spectrum_candidates(N: int) -> list[float]:
    """First N candidate eigenvalues of H_shadow."""
    return [candidate_eigenvalue(n) for n in range(N)]


# ---------------------------------------------------------------------------
# Verification: check known zeros against shadow spectrum candidates
# This is the constraint layer — FIXTURES only
# ---------------------------------------------------------------------------

KNOWN_ZEROS = [
    14.134725141734693790,
    21.022039638771554993,
    25.010857580145688763,
    30.424876125859513210,
    32.935061587739189691,
    37.586178158825671257,
    40.918719012147495187,
    43.327073280914999519,
    48.005150881167159727,
    49.773832477672302181,
]

def verify_zero_in_spectrum(gamma: float,
                             candidates: list[float],
                             tol: float = 1.0) -> dict:
    """
    Verify that γ (a known zero ordinate) appears in the candidate spectrum.
    Uses ZeroBool predicate in NAND normal form.

    This can only verify the SUPPLIED fixtures — not all zeros.
    Returns:
      in_spectrum: True if γ matches a candidate eigenvalue
      closest: nearest candidate eigenvalue
      gap: |γ - closest|
    """
    in_spectrum_bool = ZeroBool(gamma, candidates, tol=tol)
    closest = min(candidates, key=lambda c: abs(c - gamma))
    gap = abs(gamma - closest)
    return {
        "gamma":        gamma,
        "rho":          to_rho(gamma),
        "in_spectrum":  bool(in_spectrum_bool > 0.5),
        "ZeroBool":     in_spectrum_bool,
        "closest_candidate": closest,
        "gap":          gap,
        "status":       "FIXTURE_VERIFIED" if in_spectrum_bool > 0.5 else "NOT_IN_CANDIDATES",
    }


def run_verification(N_candidates: int = 100, tol: float = 1.0) -> dict:
    """
    Full verification pass:
      1. Generate N candidate eigenvalues from shadow spectrum
      2. For each known zero, check ZeroBool membership
      3. Report: how many fixtures are in the candidate spectrum?

    Expected result with placeholder candidates: NONE match (construction pending).
    Expected result with correct H_shadow: ALL match.
    """
    candidates = shadow_spectrum_candidates(N_candidates)
    results = []
    for gamma in KNOWN_ZEROS:
        r = verify_zero_in_spectrum(gamma, candidates, tol=tol)
        results.append(r)

    matches = sum(1 for r in results if r["in_spectrum"])
    return {
        "N_candidates":   N_candidates,
        "N_fixtures":     len(KNOWN_ZEROS),
        "N_matches":      matches,
        "match_rate":     matches / len(KNOWN_ZEROS),
        "results":        results,
        "construction_status": (
            "VERIFIED" if matches == len(KNOWN_ZEROS)
            else "MISSING_CONSTRUCTION: candidate eigenvalues do not match known zeros"
        ),
        "note": (
            "This layer verifies FIXTURES only. "
            "The full theorem Spectrum(H)={gamma:zeta(1/2+i*gamma)=0} "
            "requires O4a+O4b in IOM.lean."
        ),
    }


# ---------------------------------------------------------------------------
# NAND reduction walkthrough for one zero
# ---------------------------------------------------------------------------

def nand_walkthrough(gamma: float, known_zeros: list[float]) -> None:
    print(f"  gamma = {gamma}")
    print(f"  Expanding ZeroBool({gamma:.4f}, [{', '.join(f'{g:.4f}' for g in known_zeros[:3])}...])")
    print()
    for i, z in enumerate(known_zeros[:5]):
        near = NEAR(gamma, z)
        print(f"    NEAR({gamma:.4f}, {z:.4f}) = {near}")
    print()
    result = ZeroBoolNAND(gamma, known_zeros[:5])
    print(f"  ZeroBoolNAND = NAND(NAND(h,h), NAND(t,t)) = {result:.4f}")
    # Expand first step
    h = NEAR(gamma, known_zeros[0])
    h2 = NAND(h, h)
    t = ZeroBoolNAND(gamma, known_zeros[1:5])
    t2 = NAND(t, t)
    final = NAND(h2, t2)
    print(f"  Expanded: NAND({h2:.4f}, {t2:.4f}) = {final:.4f}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print("=" * 70)
    print("ZERO BOOLEAN VERIFICATION LAYER")
    print("Fixtures -> NAND predicates -> verify ShadowSpectrum")
    print("=" * 70)
    print()
    print("This layer verifies KNOWN FIXTURES against the shadow spectrum.")
    print("It does NOT define the zero set.")
    print("The actual theorem: Spectrum(H_shadow) = {gamma : zeta(1/2+i*gamma)=0}")
    print()

    print("--- NAND Boolean kernel (from ConstraintGraph) ---")
    print(f"  NAND(1,1) = {NAND(1,1):.1f}")
    print(f"  NOT(1)    = {NOT(1):.1f}")
    print(f"  NOT(0)    = {NOT(0):.1f}")
    print(f"  OR(0,1)   = {OR(0,1):.1f}")
    print(f"  AND(1,1)  = {AND(1,1):.1f}")
    print()

    print("--- NAND walkthrough for first known zero ---")
    nand_walkthrough(KNOWN_ZEROS[0], KNOWN_ZEROS)
    print()

    print("--- Complex zeros (fixtures): rho = 1/2 + i*gamma ---")
    for g in KNOWN_ZEROS[:5]:
        print(f"  gamma={g:.6f}  rho={to_rho(g)}")
    print()

    print("--- Verification against placeholder candidates (should fail) ---")
    print("  (tight tolerance tol=0.01 — placeholder candidates diverge, expect 0 matches)")
    result = run_verification(N_candidates=100, tol=0.01)
    print(f"  Fixtures:           {result['N_fixtures']}")
    print(f"  Candidates:         {result['N_candidates']}")
    print(f"  Matches:            {result['N_matches']}")
    print(f"  Match rate:         {result['match_rate']:.0%}")
    print(f"  Construction:       {result['construction_status']}")
    print(f"  Note:               {result['note']}")
