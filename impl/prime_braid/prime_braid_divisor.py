"""
Prime Braid Divisor — Digital Twin Runtime
===========================================
Formal Weil divisor on the Fargues-Fontaine curve X_FF encoding
prime numbers as topological braid crossings over W(F₂) ≅ ℤ₂.

D_prime = Σ_p  w(p) · [v_p]

where:
  [v_p]  = prime divisor (closed subscheme) corresponding to prime p
  w(p)   = (log(p) / (2πi)) · σ_b(p)
  σ_b(p) = topological crossing invariant of p in the modular braid tower

KEY OBSERVATION:
  The factor log(p)/(2πi) is EXACTLY the coefficient of prime p
  in the Weil explicit formula:
    Σ_γ h(γ) = ... - Σ_p Σ_m (log p / p^{m/2}) [h̃(m log p) + h̃(-m log p)]

  If σ_b(p) correctly encodes the multiplicity structure, D_prime
  forces the trace formula to give zeta zero ordinates as eigenvalues.

OPEN QUESTION (the mathematical breakthrough):
  What is σ_b(p) exactly?
  Options:
    σ_b(p) = 1 for all p          → D = Σ log(p)/(2πi) · [v_p]
    σ_b(p) = log(p)               → D = Σ (log(p))²/(2πi) · [v_p]
    σ_b(p) = von Mangoldt Λ(p)    → D = Σ Λ(p)log(p)/(2πi) · [v_p]
    σ_b(p) = Braid index of p      → defined via B_k → Aut(H¹_ét)

  The correct choice must make evaluate_global_divisor() converge
  to match the Weil explicit formula exactly.
  That convergence theorem = THE MATHEMATICAL BREAKTHROUGH.
"""

import math
import cmath
import sys
import io
from typing import Optional

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")


# ---------------------------------------------------------------------------
# Prime sieve
# ---------------------------------------------------------------------------

def sieve_primes(n: int) -> list[int]:
    sieve = [True] * (n + 1)
    sieve[0] = sieve[1] = False
    for i in range(2, int(n**0.5) + 1):
        if sieve[i]:
            for j in range(i*i, n+1, i):
                sieve[j] = False
    return [i for i in range(2, n+1) if sieve[i]]


# ---------------------------------------------------------------------------
# Unary index string (encodes prime via position in prime sequence)
# σ_b(p) = crossing invariant = len(unary string for p)
# ---------------------------------------------------------------------------

def unary_index_string(p: int, primes: list[int]) -> str:
    """
    Unary representation of p's position in the prime sequence.
    Prime 2 → "I", Prime 3 → "II", Prime 5 → "III", ...
    σ_b(p) = len(unary_string) = index of p in prime sequence
    """
    if p not in primes:
        return ""
    idx = primes.index(p) + 1
    return "I" * idx


# ---------------------------------------------------------------------------
# Prime Braid Divisor Digital Twin
# ---------------------------------------------------------------------------

class PrimeBraidDivisorTwin:
    """
    Digital twin of D_prime = Σ_p w(p) · [v_p]
    Sparse index array mapping divisors to Fargues-Fontaine strands.

    w(p) = (log(p) / (2πi)) · σ_b(p)
    σ_b(p) = topological crossing invariant (currently: prime index)
    """

    def __init__(self, max_primes: int = 50):
        self.max_primes    = max_primes
        self.primes        = sieve_primes(max_primes * 12)[:max_primes]
        self.divisor_cache: dict = {}
        self.frobenius_bound = math.sqrt(2)   # Deligne: |α_p| = √2

    def sigma_b(self, p: int) -> int:
        """
        Topological crossing invariant σ_b(p).
        Currently: index of p in prime sequence.
        This is what Ahmad needs to define precisely.

        CANDIDATE DEFINITIONS:
          Option A: σ_b(p) = index(p)           (current)
          Option B: σ_b(p) = 1 for all p        (simplest)
          Option C: σ_b(p) = log(p)             (log-squared weight)
          Option D: σ_b(p) = Artin braid invariant of p
        """
        return len(unary_index_string(p, self.primes))

    def construct_divisor_element(self, p: int) -> dict:
        """
        Maps prime p to a formal divisor term on X_FF.

        w(p) = (log(p) / (2πi)) · σ_b(p)

        KEY: log(p)/(2πi) is exactly the Weil explicit formula weight.
        """
        sigma  = self.sigma_b(p)
        weight = (math.log(p) / (2 * math.pi * 1j)) * sigma

        record = {
            "prime":                p,
            "valuation_ring":       f"Z_2[v_{p}]",
            "sigma_b":              sigma,
            "unary_string":         unary_index_string(p, self.primes),
            "braid_weight":         weight,
            "weil_factor":          math.log(p) / (2 * math.pi),
            "frobenius_eigenvalue_bound": self.frobenius_bound,
            "status": "ESTABLISHED: |alpha_p| = sqrt(2) by Deligne",
        }
        self.divisor_cache[p] = record
        return record

    def build_divisor(self) -> None:
        """Populate the full divisor for all primes."""
        for p in self.primes:
            self.construct_divisor_element(p)

    def evaluate_global_divisor(self) -> complex:
        """
        Σ_p w(p)  — total trace of D_prime.

        For the Weil explicit formula to work, this sum must
        converge to reproduce Σ_γ h(γ) for test functions h.

        CONVERGENCE OF THIS SUM = THE MATHEMATICAL BREAKTHROUGH.
        """
        return sum(rec["braid_weight"] for rec in self.divisor_cache.values())

    def evaluate_explicit_formula_lhs(self, gamma_candidates: list[float]) -> complex:
        """
        Left side of Weil explicit formula: Σ_γ h(γ)
        using h(γ) = 1/(1 + γ²) as test function.
        """
        def h(g): return 1.0 / (1.0 + g**2)
        return sum(h(g) for g in gamma_candidates)

    def evaluate_explicit_formula_rhs(self, primes_rhs: list[int]) -> complex:
        """
        Right side of Weil explicit formula (geometric terms):
        -Σ_p Σ_m (log p / p^{m/2}) [h̃(m log p) + h̃(-m log p)]
        using h̃(x) = 1/(1 + x²) (Fourier transform of h).
        """
        def h_tilde(x): return 1.0 / (1.0 + x**2)
        total = 0.0
        for p in primes_rhs:
            for m in range(1, 8):
                contrib = (math.log(p) / p**(m/2))
                total -= contrib * (h_tilde(m * math.log(p)) +
                                    h_tilde(-m * math.log(p)))
        return total

    def check_weil_consistency(self, gamma_candidates: list[float]) -> dict:
        """
        Check whether the prime braid divisor is consistent with the
        Weil explicit formula at the given gamma candidates.
        """
        lhs = self.evaluate_explicit_formula_lhs(gamma_candidates)
        rhs = self.evaluate_explicit_formula_rhs(self.primes[:20])
        div = self.evaluate_global_divisor()
        return {
            "weil_lhs":      lhs,
            "weil_rhs":      rhs,
            "divisor_trace": div,
            "lhs_rhs_diff":  abs(lhs - rhs),
            "note": "Convergence of divisor_trace to weil formulas = breakthrough",
        }

    def summary(self) -> dict:
        return {
            "num_primes":       len(self.divisor_cache),
            "global_trace":     self.evaluate_global_divisor(),
            "frobenius_bound":  self.frobenius_bound,
            "sigma_b_formula":  "len(unary_index_string(p)) — OPEN: Ahmad defines this",
            "weight_formula":   "w(p) = log(p)/(2*pi*i) * sigma_b(p)",
            "key_observation":  "log(p)/(2*pi) IS the Weil explicit formula weight",
            "status":           "CONJECTURAL: convergence theorem = breakthrough",
        }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import json

    print("=== Prime Braid Divisor Digital Twin ===")
    print("D_prime = sum_p  w(p) * [v_p]")
    print("w(p) = (log(p) / (2*pi*i)) * sigma_b(p)")
    print()

    twin = PrimeBraidDivisorTwin(max_primes=20)
    twin.build_divisor()

    print("First 10 divisor terms:")
    for p, rec in list(twin.divisor_cache.items())[:10]:
        print(f"  p={p:3d}  sigma_b={rec['sigma_b']:3d}  "
              f"weil_factor={rec['weil_factor']:.4f}  "
              f"|w(p)| = {abs(rec['braid_weight']):.4f}")

    print()
    print(f"Global trace: {twin.evaluate_global_divisor():.6f}")
    print()

    # Known zeta zeros (first few, truncated)
    known_zeros = [14.1347, 21.0220, 25.0109, 30.4249, 32.9351]
    check = twin.check_weil_consistency(known_zeros)
    print("Weil consistency check (5 known zeros):")
    for k, v in check.items():
        print(f"  {k}: {v}")

    print()
    s = twin.summary()
    for k, v in s.items():
        print(f"  {k}: {v}")
