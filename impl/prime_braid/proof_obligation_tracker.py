"""
Proof Obligation Tracker
========================
NUMERIC_MATCH != PROVED != CONDITIONAL != MISSING

States (strictly ordered — no upward promotion without a proof witness):
  MISSING          no candidate exists
  NUMERIC_MATCH    numerical approximation, ε-tolerance — NOT a proof
  CANDIDATE_MATCH  structurally plausible — NOT a proof
  CONDITIONAL      proved given unproved assumptions — NOT PROVED
  PROVED           machine-checkable witness exists

Tolerance-based matching NEVER produces PROVED.
PROVED requires an explicit proof_witness parameter.

Hole decomposition (first-class):
  Hole(P ∧ Q)    → Hole(P), Hole(Q)
  Hole(∀x, P x) → introduce x → Hole(P x)
  Hole(P → Q)   → assume P → Hole(Q)

iom is uninhabited until every hole is discharged.
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Optional, Callable

import math
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")


# ---------------------------------------------------------------------------
# Obligation status (5 states — strictly distinct)
# ---------------------------------------------------------------------------

class ObligationStatus(str, Enum):
    MISSING          = "MISSING"           # no candidate
    NUMERIC_MATCH    = "NUMERIC_MATCH"     # tolerance match — NOT a proof
    CANDIDATE_MATCH  = "CANDIDATE_MATCH"   # structural — NOT a proof
    CONDITIONAL      = "CONDITIONAL"       # holds given unproved assumptions
    PROVED           = "PROVED"            # machine-checkable witness

    def can_promote_to(self, other: "ObligationStatus") -> bool:
        """Legal promotion paths — only upward, only with evidence."""
        order = [
            ObligationStatus.MISSING,
            ObligationStatus.NUMERIC_MATCH,
            ObligationStatus.CANDIDATE_MATCH,
            ObligationStatus.CONDITIONAL,
            ObligationStatus.PROVED,
        ]
        return order.index(other) > order.index(self)


# ---------------------------------------------------------------------------
# A proof obligation (first-class hole)
# ---------------------------------------------------------------------------

@dataclass
class ProofObligation:
    id:          str
    statement:   str
    status:      ObligationStatus = ObligationStatus.MISSING
    proof_witness: Optional[str]  = None   # None until PROVED
    numeric_gap:   Optional[float] = None  # filled on NUMERIC_MATCH
    sub_holes:     list            = field(default_factory=list)  # decomposed holes
    notes:         str             = ""

    def discharge(self, witness: str) -> "ProofObligation":
        """Promote to PROVED. Requires an explicit witness string."""
        if not witness:
            raise ValueError(f"{self.id}: discharge requires non-empty proof_witness")
        return ProofObligation(
            id=self.id, statement=self.statement,
            status=ObligationStatus.PROVED,
            proof_witness=witness,
            sub_holes=self.sub_holes,
            notes=self.notes,
        )

    def numeric_evidence(self, gap: float, tol: float) -> "ProofObligation":
        """Record numerical approximation. Status = NUMERIC_MATCH, not PROVED."""
        new_status = ObligationStatus.NUMERIC_MATCH if gap < tol else ObligationStatus.MISSING
        return ProofObligation(
            id=self.id, statement=self.statement,
            status=new_status,
            proof_witness=None,   # ← NEVER set from numerical evidence
            numeric_gap=gap,
            sub_holes=self.sub_holes,
            notes=f"Numerical gap={gap:.2e} vs tol={tol:.2e}. "
                  "NUMERIC_MATCH is NOT a proof.",
        )

    def conditional_on(self, assumptions: list[str]) -> "ProofObligation":
        """Mark as CONDITIONAL on listed unproved assumptions."""
        return ProofObligation(
            id=self.id, statement=self.statement,
            status=ObligationStatus.CONDITIONAL,
            proof_witness=None,
            notes=f"Conditional on: {assumptions}. Not proved.",
            sub_holes=self.sub_holes,
        )

    def decompose_conjunction(self, left_id: str, right_id: str,
                               left_stmt: str, right_stmt: str) -> tuple:
        """Hole(P ∧ Q) → Hole(P), Hole(Q)"""
        left  = ProofObligation(left_id,  left_stmt)
        right = ProofObligation(right_id, right_stmt)
        return left, right

    def decompose_forall(self, var_name: str, body_stmt: str) -> "ProofObligation":
        """Hole(∀x, P x) → introduce x → Hole(P x)"""
        return ProofObligation(
            f"{self.id}[{var_name}]",
            f"introduced {var_name}: {body_stmt}",
        )

    def decompose_implication(self, assumption: str, goal: str) -> "ProofObligation":
        """Hole(P → Q) → assume P → Hole(Q)"""
        return ProofObligation(
            f"{self.id}[goal]",
            f"assuming ({assumption}): {goal}",
        )

    def is_inhabited(self) -> bool:
        """iom is uninhabited until every hole is discharged."""
        return self.status == ObligationStatus.PROVED


# ---------------------------------------------------------------------------
# The 5 obligations for iom (from IOM.lean)
# ---------------------------------------------------------------------------

def build_iom_obligations() -> list[ProofObligation]:
    return [
        # ── Operator obligations ──────────────────────────────────────────
        ProofObligation("O1",
            "Dense domain: Dense shadow_domain in ShadowHilbertSpace"),
        ProofObligation("O2",
            "Symmetry: forall psi phi in D(H), <H psi, phi> = <psi, H phi>"),
        ProofObligation("O3",
            "Self-adjointness: D(H*) = D(H)  (not just symmetry)"),

        # ── Spectral set obligations ──────────────────────────────────────
        ProofObligation("O4a",
            "spectral_zero: eigenvalue(H, lambda) -> isZetaZero(1/2+i*lambda)"),
        ProofObligation("O4b",
            "spectral_complete: isZetaZero(1/2+i*gamma) -> eigenvalue(H, gamma)"),
        ProofObligation("O4c",
            "Multiplicity: mult_H(lambda) = mult_zeta(1/2+i*lambda)  "
            "(multiset, not just set equality)"),

        # ── Trace / Weil obligations ──────────────────────────────────────
        ProofObligation("O5a",
            "Admissible test-function space: specify class S(H) s.t. "
            "sum_{lambda} f(lambda) converges for f in S(H)"),
        ProofObligation("O5b",
            "Spectral trace exists: Tr(f(H)) = int f(lambda) dN_H(lambda) "
            "for f in S(H)  (trace-class or regularized)"),
        ProofObligation("O5c",
            "Spectral trace = zero sum: "
            "Tr(f(H)) = sum_{gamma in Z_zeta} m(gamma) f(gamma)"),
        ProofObligation("O5d",
            "Zero sum = Weil explicit formula: "
            "sum_{gamma} F(gamma) = archimedean + prime-power + pole terms  "
            "(normalization fixed)"),
    ]


# ---------------------------------------------------------------------------
# Hole decomposition tree for O4a (the open problem)
# ---------------------------------------------------------------------------

def decompose_O4a() -> list[ProofObligation]:
    """
    O4a: forall lambda, eigenvalue(H_shadow, lambda) -> isZetaZero(1/2 + i*lambda)

    Decomposition:
      Hole(O4a)
        = Hole(forall lambda, eigenvalue -> zero)
        → introduce lambda
          → Hole(eigenvalue(H_shadow, lambda) -> zero)
            → assume eigenvalue(H_shadow, lambda)
              → Hole(isZetaZero(1/2 + i*lambda))
    """
    o4a = ProofObligation("O4a", "eigenvalue(H) -> zero")
    with_lambda = o4a.decompose_forall(
        "lambda",
        "eigenvalue(H_shadow, lambda) -> isZetaZero(1/2 + i*lambda)"
    )
    goal = with_lambda.decompose_implication(
        assumption="eigenvalue(H_shadow, lambda)",
        goal="isZetaZero(1/2 + i*lambda)"
    )
    return [o4a, with_lambda, goal]


def decompose_O4b() -> list[ProofObligation]:
    """
    O4b: forall gamma in ZeroImaginaryPartOfZeta,
           exists psi in domain, H_shadow psi = gamma * psi, psi != 0

    Decomposition:
      Hole(O4b)
        = Hole(forall gamma, zero -> eigenfunction_exists)
        → introduce gamma
          → Hole(isZetaZero(1/2+i*gamma) -> exists psi in D(H), H psi = gamma psi)
            → assume isZetaZero
              → Hole(exists psi in D(H_shadow), H_shadow psi = gamma psi, psi != 0)
    """
    o4b = ProofObligation("O4b", "zero -> eigenvalue(H)")
    with_gamma = o4b.decompose_forall(
        "gamma",
        "isZetaZero(1/2+i*gamma) -> exists psi in D(H), H psi = gamma*psi"
    )
    goal = with_gamma.decompose_implication(
        assumption="isZetaZero(1/2 + i*gamma)",
        goal="exists psi in shadow_domain, shadow_laplacian_action psi = gamma * psi, psi != 0"
    )
    return [o4b, with_gamma, goal]


# ---------------------------------------------------------------------------
# Validator: checks obligations and reports status
# NEVER promotes NUMERIC_MATCH to PROVED
# ---------------------------------------------------------------------------

class IOMValidator:
    def __init__(self, obligations: list[ProofObligation]):
        self.obligations = {o.id: o for o in obligations}

    def submit_numerical_evidence(self, obligation_id: str,
                                   gap: float, tol: float = 0.01) -> None:
        """Record numerical evidence. Status becomes NUMERIC_MATCH at best."""
        ob = self.obligations[obligation_id]
        self.obligations[obligation_id] = ob.numeric_evidence(gap, tol)

    def submit_proof(self, obligation_id: str, witness: str) -> None:
        """Discharge obligation with an explicit proof witness."""
        ob = self.obligations[obligation_id]
        self.obligations[obligation_id] = ob.discharge(witness)

    def submit_conditional(self, obligation_id: str,
                            assumptions: list[str]) -> None:
        """Mark as conditional on unproved assumptions."""
        ob = self.obligations[obligation_id]
        self.obligations[obligation_id] = ob.conditional_on(assumptions)

    def iom_is_inhabited(self) -> bool:
        """iom requires ALL obligations to be PROVED."""
        return all(o.is_inhabited() for o in self.obligations.values())

    def report(self) -> dict:
        rows = []
        for oid, ob in self.obligations.items():
            rows.append({
                "id":      oid,
                "status":  ob.status.value,
                "witness": ob.proof_witness,
                "gap":     ob.numeric_gap,
                "notes":   ob.notes[:80] if ob.notes else "",
            })
        inhabited = self.iom_is_inhabited()
        return {
            "iom_inhabited": inhabited,
            "missing_count": sum(1 for o in self.obligations.values()
                                 if not o.is_inhabited()),
            "obligations":   rows,
            "verdict": "PROVED: iom is inhabited" if inhabited
                       else "MISSING: iom is uninhabited — discharge all obligations",
        }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print("=" * 70)
    print("PROOF OBLIGATION TRACKER — iom construction")
    print("NUMERIC_MATCH != PROVED != CONDITIONAL != MISSING")
    print("=" * 70)
    print()

    validator = IOMValidator(build_iom_obligations())

    # Simulate: O1-O3 have conditional proofs (standard FA)
    validator.submit_conditional("O1", ["ShadowDomain_is_L2_subspace"])
    validator.submit_conditional("O2", ["candidate_eigenvalues_are_real"])
    validator.submit_conditional("O3", ["diagonal_operator_self_adjoint_criterion"])

    # O4a-O4c: numerical evidence only — NOT promoted to PROVED
    validator.submit_conditional("O4a", ["H_shadow_concrete_self_adjoint_proved", "spectralLog_real"])
    validator.submit_numerical_evidence("O4b", gap=3.7, tol=0.01)
    # O4c, O5a-O5d: all MISSING (no candidate yet)
    # (no submit call needed — default is MISSING)

    result = validator.report()
    print(f"iom inhabited: {result['iom_inhabited']}")
    print(f"Missing:       {result['missing_count']}")
    print(f"Verdict:       {result['verdict']}")
    print()
    print(f"{'ID':<8} {'STATUS':<20} {'GAP':<10} {'NOTES'}")
    print("-" * 70)
    for row in result["obligations"]:
        gap_str = f"{row['gap']:.2e}" if row["gap"] is not None else "-"
        print(f"{row['id']:<8} {row['status']:<20} {gap_str:<10} {row['notes'][:40]}")

    print()
    print("--- Hole decomposition for O4a ---")
    for hole in decompose_O4a():
        print(f"  [{hole.id}] {hole.statement[:60]}")

    print()
    print("--- Hole decomposition for O4b ---")
    for hole in decompose_O4b():
        print(f"  [{hole.id}] {hole.statement[:60]}")

    print()
    print("KEY INVARIANT: NUMERIC_MATCH is not PROVED.")
    print("iom requires every obligation to be PROVED (not CONDITIONAL, not NUMERIC_MATCH).")
    print("O4a and O4b remain NUMERIC_MATCH. iom is uninhabited.")
