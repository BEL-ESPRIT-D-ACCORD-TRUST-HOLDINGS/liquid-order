# Sovereign-Covenant Preregistered Research Protocol v1

**Status:** FROZEN — All identified architecture-level corrections incorporated.  
**Commit binding:** Spec_v1_frozen (see tag)  
**Date frozen:** 2026-08-13  

---

## Freeze Boundary Declaration

This document is the immutable specification object `Spec_v1`.  
Any subsequent correction becomes an explicit amendment (`v1.1`, `v1.2`, …) with its own execution ID.

> Protocol frozen ≠ proof obligations discharged ≠ experiment executed ≠ results established.

---

## Definitions

| Symbol | Meaning |
|--------|---------|
| `R` | Algorithm representation graph |
| `N` | Normalization function `R → R` |
| `F` | Feature extraction `N(R) → FeatureVector` |
| `S` | Signature function (structural tuple, no hashing) |
| `H` | Hashing function for numerical test (BLAKE3, first 8 bytes, big-endian) |
| `Q` | Quotient under normal form equality |
| `Ω_H` | Numerical observable from frozen corpus |
| `C` | Frozen corpus of 137 algorithms |
| `K` | Candidate generalization family for conjectures |

---

## Three Independent Tracks

Each track can succeed or fail independently. No track result alters another.

---

### Track 1 — Formal Conditional Theorem

**Theorem Schema (proved):**

```
If:
  (1) G_{Γ_SC} is acyclic (DAG)
  (2) ∀ f_i ∈ Γ_SC,  f_i ∈ FP
  (3) ∀ P_j ∈ Γ_SC,  P_j ∈ P
  (4) every source variable is supplied or uniquely determined

Then:
  Derive_{Γ_SC} ∈ FP
  Check_{Γ_SC}  ∈ P
```

**Concrete instantiation (pending audit):**

The Sovereign-Covenant instance must be audited against all four hypotheses.  
Status until audit completes: **Theorem conditionally instantiated.**

Evaluation pipeline:
```
InputState --[Derive]--> DerivedState --[Check]--> {0,1}
```

No SAT/NP comparison needed. The system performs deterministic evaluation, not existential search.

**Proof obligations (preregistered, not yet discharged):**
- [ ] Prove normalization absorption: `N ∘ T_i = N` for all structural transforms `T_i`
- [ ] Prove observable-trace preservation for `Φ_{2a}`
- [ ] Verify all nine freeze gates on implementation
- [ ] Audit `G_{Γ_SC}` is acyclic
- [ ] Verify all `f_i ∈ FP`
- [ ] Verify all `P_j ∈ P`
- [ ] Verify all roots supplied or uniquely determined

---

### Track 2 — Empirical Quotient Experiment

**Setup:**
```
Algorithm A  →  N(A)  →  [A]_N  (equivalence class)
```

**Internal Invariants (sanity checks — must pass):**

Properties computed directly from `F(N(A))`. These hold trivially if canonicalization is correct.  
They validate the machinery, not structural discovery.

```python
def test_internal_invariants():
    for A in CORPUS:
        N_A = canonicalize(A)
        F_A = extract_features(N_A)
        assert F_A.cyclomatic_complexity == compute_cyclomatic(N_A)
        assert F_A.vertex_count == len(N_A.vertices)
        assert F_A.algebra_degree == compute_algebra_degree(N_A)
        B = find_equivalent_algorithm(A, CORPUS)
        if B:
            assert extract_features(canonicalize(B)) == F_A
```

**External Properties (candidate discoveries):**

Properties *not* encoded in `F(N(A))` — independently measured.

| Property | Measurement Method | Status |
|----------|-------------------|--------|
| Runtime complexity class | Empirical benchmark | Pending |
| Proof-theoretic property | Formal analysis | Pending |
| Cryptanalytic weakness class | Attack surface assessment | Pending |
| Hardware cost | Physical measurement | Pending |

If `N(A) = N(B) ⇒ P_ext(A) = P_ext(B)` holds across corpus: **positive structural observation**.

```python
def test_external_invariants():
    for equiv_class in quotient:
        for prop_name, measure_fn in EXTERNAL_PROPERTIES.items():
            values = [measure_fn(A) for A in equiv_class]
            if len(set(values)) > 1:
                observations[prop_name] = "NOT_CONSTANT"
            else:
                observations[prop_name] = "CONSTANT_ON_CLASS"
    return observations
```

**All three outcomes are valid results:**

| Outcome | Meaning |
|---------|---------|
| `P_ext` constant on classes | Positive structural observation → candidate invariant |
| `P_ext` varies within classes | Quotient too coarse for `P_ext` — structural limit found |
| Canonicalization unresolved | Method-limit result — refinement insufficient |

**Epistemic progression:**
```
corpus regularity → candidate invariant → conjecture → proof
```

---

### Track 3 — Preregistered Numerical Hypothesis

**Preregistered:** `Ω_H^{impl} = 2462` or `Ω_H^{quot} = 2462`

This is a blind numerical test. It is independent of Tracks 1 and 2.  
Track 1 and 2 validity is unaffected by the Track 3 result.

---

## Epistemic Ordering (Final)

1. Specification (frozen) — `Spec_v1`, commit SHA
2. Proof obligations (preregistered) — to be discharged
3. Immutable implementation — code, versioned amendments if needed
4. Blind execution — no modifications to code
5. Observation — corpus-level result on finite `C`
6. Candidate invariant — pattern identified in observations
7. Conjecture — formalized generalization to `K`
8. Proof — theorem established
9. Numerical comparison — `2462`, independent

---

## Nine Freeze Gates

- [ ] No runtime `hash()` in canonicalization
- [ ] Synchronous refinement: all reads from previous iteration only
- [ ] Canonical SCC ordering via structural signatures, not IDs
- [ ] No Tarjan SCC IDs used post-partition
- [ ] `N ∘ T_i = N` proved (normalization absorption)
- [ ] Observable-trace preservation proved for structural transforms
- [ ] Concrete `Γ_SC` verifies all four theorem hypotheses
- [ ] Unresolved structural symmetry ⇒ HALT (not ID-break)
- [ ] `2462` absent from all precomparison canonicalization stages

---

## Amendment Protocol

```
Spec_v1  --[defect discovered]-->  Spec_v1.1  --[new execution]-->  execution-id-002
```

- Original spec remains immutable reference
- Defect is transparent and documented  
- Failed executions remain reproducible
- Amendments are versioned and dated

---

## Immutable Binding Objects

All of the following are bound to the `Spec_v1_frozen` tag:

- `spec/PROTOCOL_v1.md` — this document
- `impl/phi3_canonical.py` — corrected canonicalization
- `corpus/corpus_v1.json` — 137 frozen algorithms
- `proofs/` — formal proof files
- `src/LiquidOrder/` — LCF kernel and IR
- `tests/` — internal + external invariant harness

> **Publication status:** Protocol frozen and ready for publication.  
> Results are claimed only after blind execution completes.
