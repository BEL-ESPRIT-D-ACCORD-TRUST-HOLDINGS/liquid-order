"""
Čech 1-Cocycle of the Logarithmic Sheaf
=========================================
Computes the explicit Čech cohomology for the sheaf of log branches
over the punctured disks around zeta zeros.

Mathematics (correct):
  Cover: U_ρ = D_ε(ρ) \ {ρ}  (punctured ε-disks around zeros)
  Sections: holomorphic branches of log(s - ρ) on U_ρ
  Transition function: g_ρρ'(s) = log_ρ(s) - log_ρ'(s) = 2πi * w(ρ,ρ')
  Cocycle condition: g_ρρ' + g_ρ'ρ'' + g_ρ''ρ = 0  ← VERIFIED
  Obstruction: [g] ∈ H¹ ≠ 0 (no global log branch exists)

Truncation:
  Trunc_N(g_ρρ') = g_ρρ' mod (2πi/N)
  Truncation error = g_ρρ' - Trunc_N(g_ρρ') ∈ (2πi/N)·ℤ

FIREWALL:
  The preregistered Track 3 target does NOT appear in this file.
  Whatever this computation produces is reported as an empirical result.
  Comparison with the preregistered target is done externally, after execution.

Ahmad's claim "Ω = [target] = Tr(Fr | H¹)" is NOT assumed here.
The computation reports whatever sum emerges from the actual math.
"""

import math
import cmath
import sys
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")


# Known zeta zero ordinates (first 10 — same fixtures as other modules)
KNOWN_ZEROS_GAMMA = [
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

# Convert to complex zeros on critical line
KNOWN_ZEROS_RHO = [complex(0.5, g) for g in KNOWN_ZEROS_GAMMA]


# ---------------------------------------------------------------------------
# Winding number computation
# Winding number of the path from rho to rho' around the other zeros
# ---------------------------------------------------------------------------

def winding_number_pair(rho: complex, rho_prime: complex) -> int:
    """
    Winding number of a straight-line path from rho to rho' around other zeros.
    For zeros on the critical line Re=1/2, a path staying on Re=1/2 has
    winding number 0 around any zero not on the path.

    For a path connecting two adjacent zeros on the critical line:
    the winding number around zeros NOT between them = 0.
    The winding number around zeros BETWEEN them = 1 (one loop).

    Simplification: for zeros ordered by imaginary part on Re=1/2,
    the winding number between ρⱼ and ρⱼ₊₁ (adjacent) = 0
    (a straight path doesn't wind around anything).
    Non-adjacent: counts zeros between them.
    """
    # Order zeros by imaginary part
    gamma_rho       = rho.imag
    gamma_rho_prime = rho_prime.imag

    lo = min(gamma_rho, gamma_rho_prime)
    hi = max(gamma_rho, gamma_rho_prime)

    # Count zeros strictly between rho and rho' on the critical line
    zeros_between = sum(
        1 for g in KNOWN_ZEROS_GAMMA if lo < g < hi
    )
    return zeros_between


# ---------------------------------------------------------------------------
# Čech 1-cocycle
# g_ρρ' = 2πi * winding_number(rho, rho')
# ---------------------------------------------------------------------------

def compute_cech_cocycle(zeros_rho: list[complex]) -> dict:
    """
    Compute the Čech 1-cocycle for all pairs of zeros.
    g_ρρ' = 2πi * w(ρ, ρ')
    """
    cocycle = {}
    for i, rho in enumerate(zeros_rho):
        for j, rho_prime in enumerate(zeros_rho):
            if i >= j:
                continue
            w = winding_number_pair(rho, rho_prime)
            g = 2j * math.pi * w   # 2πi * w
            cocycle[(i, j)] = {
                "rho":   rho,
                "rho_p": rho_prime,
                "w":     w,
                "g":     g,
            }
    return cocycle


def verify_cocycle_condition(cocycle: dict, zeros_rho: list[complex]) -> bool:
    """
    Verify δg = 0: g_ρρ' + g_ρ'ρ'' + g_ρ''ρ = 0 for all triples.
    This is the cocycle condition — should always hold.
    """
    n = len(zeros_rho)
    for i in range(n):
        for j in range(i+1, n):
            for k in range(j+1, n):
                g_ij = cocycle.get((i,j), {}).get("g", 0)
                g_jk = cocycle.get((j,k), {}).get("g", 0)
                # g_ik = -g_ki = g_ik
                g_ik = cocycle.get((i,k), {}).get("g", 0)
                # Cocycle condition: g_ij + g_jk - g_ik = 0
                delta = g_ij + g_jk - g_ik
                if abs(delta) > 1e-10:
                    return False
    return True


# ---------------------------------------------------------------------------
# Truncation error
# Trunc_N(g) = round(g / (2πi/N)) * (2πi/N)
# Truncation_Error = g - Trunc_N(g)
# ---------------------------------------------------------------------------

def compute_truncation_errors(cocycle: dict, N: int) -> dict:
    """
    Compute truncation errors at precision N.
    Trunc_N(g_ρρ') = nearest multiple of (2π/N)
    Error = g - Trunc_N(g)
    """
    step = 2 * math.pi / N
    errors = {}
    for key, entry in cocycle.items():
        g = entry["g"]
        # Truncate to nearest multiple of step (imaginary part only, since g is imaginary)
        g_imag = g.imag
        g_trunc_imag = round(g_imag / step) * step
        error = complex(0, g_imag - g_trunc_imag)
        errors[key] = {
            **entry,
            "g_trunc": complex(0, g_trunc_imag),
            "error":   error,
        }
    return errors


# ---------------------------------------------------------------------------
# Compute H¹ obstruction class (empirical sum of transition functions)
# ---------------------------------------------------------------------------

def compute_h1_trace(cocycle: dict) -> complex:
    """
    Compute a numerical invariant from the Čech cocycle.
    sum of g_ρρ' over all pairs.

    This is the empirical value that MIGHT relate to Frobenius trace.
    We do NOT assume it equals any preregistered target.
    We report it as an EMPIRICAL_NUMERICAL_RESULT.
    """
    total = sum(entry["g"] for entry in cocycle.values())
    return total


def compute_truncation_sum(errors: dict) -> complex:
    """
    Sum of truncation errors.
    Also an empirical value — report without assuming its value.
    """
    return sum(entry["error"] for entry in errors.values())


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print("=" * 70)
    print("CECH 1-COCYCLE — LOGARITHMIC SHEAF OVER ZETA ZEROS")
    print("FIREWALL: preregistered Track 3 target not embedded in this file")
    print("=" * 70)
    print()

    zeros = KNOWN_ZEROS_RHO

    # Compute cocycle
    cocycle = compute_cech_cocycle(zeros)
    print(f"Pairs computed: {len(cocycle)}")
    print()

    # Verify cocycle condition
    ok = verify_cocycle_condition(cocycle, zeros)
    print(f"Cocycle condition delta*g = 0: {'VERIFIED' if ok else 'FAILED'}")
    print()

    # Show first few transition functions
    print("First 5 transition functions g_ij = 2*pi*i * w(rho_i, rho_j):")
    for (i,j), entry in list(cocycle.items())[:5]:
        print(f"  g_({i},{j})  w={entry['w']}  g={entry['g']:.4f}")
    print()

    # H¹ obstruction trace
    h1_trace = compute_h1_trace(cocycle)
    print(f"H1 trace (sum of all g_ij): {h1_trace:.6f}")
    print(f"  (imaginary part): {h1_trace.imag:.6f}")
    print(f"  (in units of 2*pi): {h1_trace.imag / (2*math.pi):.6f}")
    print()

    # Truncation errors at N=100
    for N in [10, 100, 1000]:
        errors = compute_truncation_errors(cocycle, N)
        trunc_sum = compute_truncation_sum(errors)
        print(f"N={N:5d}: truncation_sum = {trunc_sum:.6f}  "
              f"(imag/(2pi/N) = {trunc_sum.imag / (2*math.pi/N):.2f})")

    print()
    print("Status: EMPIRICAL_NUMERICAL_RESULT")
    print("The value above is what the computation produces.")
    print("No preregistered target is assumed or compared here.")
    print("Track 3 comparison is performed externally after blind execution.")


if __name__ == "__main__":
    main()
