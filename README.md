# LiquidOrder

**LiquidOrder** is an LCF-style higher-order refinement engine in which subtyping is predicate ordering, recursion is fixed-point reasoning, automation is proof-producing, and SMT is an optional subordinate decision procedure.

This repository also contains the **Sovereign-Covenant Preregistered Research Protocol v1** — a three-track formal verification and empirical canonicalization experiment.

---

## Architecture

```
Haskell Program
  ↓
Typed λ-calculus (Term of type Bool = proposition)
  ↓
Higher-order refinements  {x:τ | P(x)}
  ↓
Predicate/order obligations
  ↓
normalize → rewrite → match → decide → induct
  ↓
proof certificates
  ↓
LCF kernel  (Thm — unexported constructor)
  ↓
Thm
```

**Subtyping = predicate ordering:**
```
{x:τ|P} <: {x:τ|Q}  iff  ∀x. P(x) ⇒ Q(x)
```

**Recursion = fixpoint:**
```
fix(F) = ⊔ { F^n(⊥) | n ≥ 0 }
```

**Automation dispatches by logical shape:**
```
Goal
 ├── βη equality ─────────→ Normalize
 ├── rewrite theorem ──────→ Rewrite Engine
 ├── higher-order pattern ─→ Miller Matcher
 ├── arithmetic fragment ──→ Proof-producing arithmetic solver
 ├── lattice/order goal ───→ Order Solver
 ├── recursive goal ───────→ Induction / Fixpoint Rule
 └── otherwise ────────────→ Interactive tactic
```

---

## Repository Structure

```
spec/
  PROTOCOL_v1.md        Frozen three-track preregistered research protocol
  PROOF_JOB_v1.md       Full proof obligations for solver

src/LiquidOrder/
  Kernel/Kernel.hs      LCF trusted kernel (10 rules, unexported Thm constructor)
  IR/Types.hs           Minimal term/refinement IR
  Order/OrderTheory.hs  Predicate ordering, fixpoints, contracts
  Refinement/
    Subtyping.hs        Subtype checking via predicate ordering
    FactorsThrough.hs   Core Track 2 combinator
  Automation/Dispatch.hs  Proof-producing dispatch hierarchy

impl/
  phi3_canonical.py     Corrected canonicalization (no hash(), synchronous, structural)

proofs/
  Lean4/SovereignCovenantSchema.lean    Track 1 theorem schema
  Agda/NormalizationAbsorption.agda     THM-003 + THM-004 + THM-005

corpus/
  corpus_v1_manifest.json   Frozen 137-algorithm corpus manifest

tests/
  test_freeze_gates.py  Nine freeze gate audit + internal/external invariant harness
```

---

## Three-Track Research Protocol

### Track 1 — Formal Conditional Theorem

```
G_{Γ_SC} is acyclic
+ ∀ f_i ∈ FP
+ ∀ P_j ∈ P
+ every source variable supplied or uniquely determined
⟹
  Construct_{Γ_SC} ∈ FP
  Check_{Γ_SC}     ∈ P
```

Status: Schema proved. Concrete Sovereign-Covenant instantiation is a pending audit.

### Track 2 — Quotient Experiment

The central combinator:

```haskell
FactorsThrough N P = ∀ A B. N(A) = N(B) → P(A) = P(B)
```

- **Internal properties** (computed from `F(N(A))`): hold trivially — sanity checks
- **External properties** (independently measured): genuine candidate discoveries

All outcomes are scientifically valid:
- `CONSTANT_ON_CLASS` → positive structural observation
- `NOT_CONSTANT` → quotient too coarse for this property  
- `UNRESOLVED_AUTOMORPHISM` → method-limit result

### Track 3 — Preregistered Numerical Hypothesis

Preregistered: `Ω_H^{impl} = 2462` or `Ω_H^{quot} = 2462`

This is a blind empirical test. It is independent of Tracks 1 and 2.  
**Do not add 2462 anywhere in the canonicalization code.**

---

## Nine Freeze Gates

Run `python tests/test_freeze_gates.py` before tagging `Spec_v1_frozen`.

1. No `hash()` in canonicalization
2. Synchronous refinement (reads from `color_prev` only)
3. Canonical SCC ordering via structural signatures
4. No Tarjan SCC IDs used post-partition
5. `N ∘ T_i = N` proof registered
6. Semantic soundness registered as obligation
7. Concrete Γ_SC audit items in spec
8. `UNRESOLVED_AUTOMORPHISM → HALT` present
9. `2462` absent from canonicalization code

---

## Publication Status

> **Protocol frozen and ready for publication.**  
> Formal proof obligations and concrete Track 1 instantiation remain to be discharged before blind execution.  
> Results are not claimed until execution is complete.

Immutable binding: `(Spec_v1, Corpus_v1, Implementation_v1, commit SHA)`  
Amendment protocol: defects become `Spec_v1.1` with new execution ID.

---

## Epistemic Hierarchy

```
Specification (frozen)
  → Proof obligations (preregistered)
  → Immutable implementation
  → Blind execution
  → Observation (corpus-level)
  → Candidate invariant
  → Conjecture
  → Proof
  → Numerical comparison (2462, independent, last)
```


---

## Sovereign Boundary

This repository operates under the **SnapKitty Method**: public by default, sovereign by construction.

```
CODE        → PUBLIC      (this repository)
PROOF       → PUBLIC      (Lean 4 / formal verification artifacts)
SPEC        → PUBLIC      (interfaces, schemas, invariants)
HISTORY     → PUBLIC      (cryptographic provenance, WORM-sealed)

AUTHORITY   → SOVEREIGN   (Bel Esprit D'Accord Irrevocable Trust)
STATE       → SOVEREIGN   (credentials, private data, operational secrets)
EXECUTION   → AUTHORIZED  (requires sovereign state — not in this repo)
```

> **"Here is the machine. You do not own the state it operates on."**

Reading the source does not grant execution authority. Forking the repo does not grant deployment rights. The code is verifiable. The authority is not transferable.

**[→ Full architecture: SOVEREIGN_METHOD.md](./SOVEREIGN_METHOD.md)**

**[→ License terms: LICENSE](./LICENSE)** · **[→ IP estate: NOTICE](./NOTICE)**

---

*Copyright (C) 2026 Bel Esprit D'Accord Irrevocable Trust (EIN 42-697643) · `Ω = TRUST ∧ CODE`*
