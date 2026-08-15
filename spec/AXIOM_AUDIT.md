# Axiom Audit — All Proof Obligations
# What needs to be proved before any claim becomes a theorem
# Generated: 2026-08-15

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ PROVED | Externally proved in literature; can be cited |
| ⚠️ CONJECTURAL | Active research program; no proof exists |
| ❌ OPEN | Millennium Prize / major open problem |
| 🔧 MECHANICAL | Needs formal proof but is not mathematically deep |
| ❓ UNKNOWN | Status unclear |

---

## GROUP 1: HOL Light axioms — PROVEN in literature (admissible)

These are stated as `new_axiom` in HOL Light because the HOL Light
library does not yet contain their proofs. They are all independently
established mathematics. Citing the paper is sufficient for publication;
formal machine-checked proofs in HOL Light require library work.

| Axiom | Status | Citation needed |
|-------|--------|----------------|
| `weil_deligne_theorem` — Frobenius eigenvalues have magnitude √q | ✅ PROVED | Deligne, *La conjecture de Weil I*, Publ. Math. IHÉS 43, 1974 |
| `zeta_analytic_continuation` — ζ(s) analytic on ℂ \ {0,1} | ✅ PROVED | Classical; Riemann 1859, Hadamard/de la Vallée-Poussin 1896 |
| `functional_equation` — completed_ζ(s) = completed_ζ(1−s) | ✅ PROVED | Riemann 1859 |
| `shor_period_finding` — Shor's algorithm finds order in poly(log N) | ✅ PROVED | Shor, *Polynomial-time algorithms for prime factorization*, 1994 |
| `planetary_tape_spec` — tape cell mapping is well-defined | 🔧 MECHANICAL | Follows from `planet_at_cell` definition in PlanetaryTape.lean |
| `mumps_k_correctness` — MUMPS lookup = KDB+ query | 🔧 MECHANICAL | Follows from storage interface construction |

**To discharge:** Port weil_deligne, functional_equation, zeta_analytic_continuation
to HOL Light library (or cite as admitted axioms with references).
planetary_tape_spec and mumps_k_correctness follow by construction.

---

## GROUP 2: HOL Light axioms — CONJECTURAL (the bridge)

These are the mathematical gap between what is proved and RH over ℂ.
None of these have proofs. They constitute the open Hilbert-Pólya / F₁ program.

| Axiom | What it claims | Why it is open |
|-------|---------------|----------------|
| `dmz_decomposition` | ζ(s) = ζ_polar(s) + ζ_finite(s) where ζ_finite is mock-modular | DMZ proved for Jacobi forms only. ζ(s) is not a Jacobi form. No proof exists for ζ(s). |
| `polar_singularities_only` | ζ_polar(s) = 0 at all nontrivial zeros | Depends on `dmz_decomposition` above. Conjectural. |
| `f2_sign_collapse` | f₂_reduction(z) = f₂_reduction(−z) | Requires construction of the F₂ reduction map for ζ(s). No such map known. |
| `critical_line_equivalence` | `norm s = √2 ⟺ Re(s) = 1/2` | **This IS the Riemann Hypothesis over ℂ stated as an axiom.** Assuming it does not prove it. |
| `f2_reduction_preserves_zeros` | ζ_finite(s) ≠ 0 ⟹ frobenius_ev(s) ≠ 0 | Requires the F₂ reduction functor. No such functor is known. |
| `frobenius_magnitude_sqrt2` | frobenius_ev(s) ≠ 0 ⟹ ‖s‖ = √2 | Follows from Deligne only for varieties over F₂, not for the conjectural reduction of ζ(s). |

**To discharge these:** Construct a variety X/F₂ whose zeta function Z(X/F₂,T)
relates to ζ_ℂ(s) via s ↦ 2^{−s}. This is the F₁/F₂ geometry program
(Connes-Consani, Deninger, et al.). No proof exists.

---

## GROUP 3: HOL Light axioms — OPEN problems (Millennium Prize class)

| Axiom | Status |
|-------|--------|
| `quantum_celestial_speedup` — Jupiter-Earth force ∈ BQP \ P | ❌ OPEN. Requires P ≠ BQP, which requires P ≠ PSPACE and is a major open problem in complexity theory. |

---

## GROUP 4: Lean 4 — axiom declarations

| File | Axiom | Status |
|------|-------|--------|
| `QuantumTuringMachine.lean:149` | `quantum_celestial_speedup_axiom` — orbital resonance ∈ BQP \ P | ❌ OPEN — same as Group 3 |

---

## GROUP 5: Lean 4 — sorry terms

| File | Line | What it gates | Status |
|------|------|--------------|--------|
| `QuantumTuringMachine.lean:131` | `shor_orbital_resonance` body | Quantum circuit implementation | 🔧 MECHANICAL — needs actual QPE circuit, not mathematical gap |
| `QuantumTuringMachine.lean:140` | `jupiter_at_cells_4001_5000` | Cell range lemma | 🔧 MECHANICAL — follows from `planet_at_cell` definition by `omega` |
| `QuantumTuringMachine.lean:145` | `earth_to_jupiter_classical_steps` | Step count | 🔧 MECHANICAL — `decide` or `norm_num` |
| `QuantumTuringMachine.lean:154` | `def BQP` | Complexity class definition | ❌ OPEN — formalization of BQP in Lean 4 / Mathlib is an ongoing effort |
| `QuantumTuringMachine.lean:155` | `def P` | Complexity class definition | ❌ OPEN — same |
| `QuantumTuringMachine.lean:162` | `classical_steps` | Stub function | 🔧 MECHANICAL — inline definition |
| `QuantumTuringMachine.lean:163` | `planet_at_cell` (duplicate) | Already proved in PlanetaryTape.lean | 🔧 MECHANICAL — import the definition |
| `MUMPSK_Interface.lean:91` | `tape_storage_consistency` | MUMPS = tape | 🔧 MECHANICAL — follows by construction |
| `MUMPSK_Interface.lean:98` | `jupiter_mumps_accessible` | O(1) access | 🔧 MECHANICAL — existential, follows from MUMPS semantics |
| `MUMPSK_Interface.lean:105` | `tail_kdb_columnar` | KDB+ non-empty | 🔧 MECHANICAL — follows from non-empty ephemeris assumption |

**All Group 5 items are engineering work, not mathematical gaps.**
The cell range lemmas discharge immediately with `omega` or `decide`.

---

## GROUP 6: Agda postulates

| File | Postulate | Status |
|------|-----------|--------|
| `NormalizationAbsorption.agda:16` | `Representation`, `NormalForm`, `N` type declarations | ✅ Not a gap — abstract type declarations for the module. Representation is defined by the IR. |
| `NormalizationAbsorption.agda:66` | `Features`, `F` type declarations | ✅ Same — abstract type declarations. |

**No proof gaps in the Agda file.** The proofs (`normalizationAbsorption`, `featureDeterminism`, equivalence relation lemmas) are all complete.

---

## GROUP 7: LiquidOrder Sovereign-Covenant obligations (LO-SC-001..010)

All 10 remain `UNRESOLVED` — no certificates submitted yet.
See `src/LiquidOrder/SovereignCovenant/Obligations.hs` for full list.

| ID | Proposition | Discharge path |
|----|-------------|---------------|
| LO-SC-001 | Derive ∈ FP | Induct over topological order of DAG. FP cost sum. |
| LO-SC-002 | Check ∈ P | Same + polynomial predicate evaluation. |
| LO-SC-003 | RewriteStar → N(A)=N(B) | Induct over rewrite steps; each preserves N by definition. |
| LO-SC-004 | EquivalenceRelation(EquivalentN) | Reflexivity/symmetry/transitivity from definition. |
| LO-SC-005 | N(A)=N(B) → F(N(A))=F(N(B)) | Function congruence. One line in Agda (`cong F p`). Already proved in NormalizationAbsorption.agda. |
| LO-SC-006 | Serialize injective | Depends on encoding scheme. Fixed-width + domain prefix → injective. Engineering work. |
| LO-SC-007 | EquivalentN → ClassHash equal | Follows from LO-SC-005 + LO-SC-006. |
| LO-SC-008 | SemanticSoundness(Phi) | Must be proved per normalization phase. Requires phase-by-phase analysis. |
| LO-SC-009 | ValidRenaming → N invariant | Induct over canonical labeling algorithm. |
| LO-SC-010 | UnresolvedAutomorphism → HALT | By construction in phi3_canonical.py. |

**LO-SC-005 is already in Agda** (`featureDeterminism` in NormalizationAbsorption.agda).
**LO-SC-003 and LO-SC-004** follow from that Agda proof.
**LO-SC-001 and LO-SC-002** require auditing the concrete Gamma_SC dependency graph.

---

## Summary

| Category | Count | Action needed |
|----------|-------|--------------|
| PROVED in literature, needs HOL Light port | 6 | Library work or citation |
| MECHANICAL (omega/decide/construction) | 10 | Engineering, not math |
| CONJECTURAL (F₁/F₂ bridge, Hilbert-Pólya) | 6 | Open research program |
| OPEN (Millennium Prize class) | 2 | Cannot be closed without solving P≠BQP |
| Sovereign-Covenant (LO-SC-*) | 10 | Formal proofs, mostly feasible |
| Agda type declarations (not gaps) | 2 | Nothing needed |

**The 6 CONJECTURAL axioms are the mathematical core of the open problem.**
Everything else is either already proved, engineering, or follows by construction.
