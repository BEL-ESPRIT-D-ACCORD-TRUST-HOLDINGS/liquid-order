# LiquidOrder Proof Job v1
# Sovereign-Covenant / Omega Extraction

**MODE:** HIGHER_ORDER_PROOF_CERTIFY  
**TRUST MODEL:** Solver is untrusted. Only LiquidOrder.Kernel may construct Thm.  
Every automated result MUST return a replayable proof certificate.

---

## Pipeline

```
ProtocolSpec
  → LiquidOrder obligations
  → your solver
  → proof certificate
  → LCF kernel
  → Thm
```

---

## I. Track 1 — Deterministic Evaluation Theorem

**Hypotheses:**

- H1: `Acyclic Depends`
- H2: `∀ f. ConstraintFunction f → PolyFun f`
- H3: `∀ p. VerificationPredicate p → PolyPred p`
- H4: `∀ r. Root r → Supplied InputState r ∨ Unique InputState r`
- H5: `∀ x. ¬Root x → ∃ parent. Depends parent x`
- H6: `∀ x. DerivedVariable x → value_of x = apply_constraint_function x (values_of_predecessors x)`

**Goals:**

```
THM-001: ⊢ Derive_Gamma_SC ∈ FP
THM-002: ⊢ Check_Gamma_SC ∈ P
```

**Proof strategy:**
1. From H1 derive topological ordering
2. Induction over topological order
3. Root case: supplied → lookup; unique → deterministic derivation
4. Derived-node case: all predecessors evaluated, function ∈ FP by H2
5. Sum costs: O(|V| + |E|) + Σ T_{f_i} remains polynomial
6. Check: predicates after Derive, each ∈ P by H3, conjunction ∈ P

---

## II. Normalization Absorption

For every rewrite T_i:

```
ABSORB_i: ⊢ ∀ R. N(T_i R) = N R
```

Then:

```
THM-003: ⊢ ∀ A B. A →*_T B → N(A) = N(B)
```

Proof: induction on →*. Base: refl. Step: N A = N C by ABSORB_i, = N B by IH.

---

## III. Normal-Form Equivalence

```
EquivalentN A B := N A = N B

THM-004: ⊢ EquivalenceRelation EquivalentN
  (reflexive, symmetric, transitive — by congruence of N)
```

---

## IV. Feature Determinism

```
THM-005: ⊢ ∀ A B. N A = N B → F(N A) = F(N B)
```

Proof: congruence of F. This establishes all internal invariants automatically.

---

## V. Serialization Injectivity

```
THM-006: ⊢ ∀ f1 f2. Serialize f1 = Serialize f2 → f1 = f2
```

Prove field-wise: fixed-width encoding, rationals normalized, field positions fixed, no variable-length ambiguity.  
BLAKE3 is NOT used for this proof. Hashing occurs after injective serialization.

---

## VI. Quotient Hash Well-Definedness

```
ClassHash A := Truncate64(BLAKE3(Serialize(F(N A))))

THM-007: ⊢ ∀ A B. EquivalentN A B → ClassHash A = ClassHash B
```

Proof: N A = N B → F equal → Serialize equal → BLAKE3 inputs identical → outputs identical.  
No collision-resistance assumption needed. Inputs are equal.

---

## VII. Semantic Soundness of Normalization

For every normalization phase Φ_i:

```
THM-008: ⊢ ∀ Φ_i ∈ Normalizers. ∀ R x. π(Sem(Φ_i R, x)) = Sem(R, x)
```

Especially Φ_{2a}/split. No testing may substitute for this theorem.

---

## VIII. Canonical Label Independence

```
THM-009: ⊢ ∀ ρ R. ValidRenaming ρ → RESOLVED R → N(Rename ρ R) = N R

THM-010: UNRESOLVED_AUTOMORPHISM → HALT
```

Never prove equality by original node identifiers.

---

## IX. External Property Factorization — FactorsThrough

```haskell
-- The core LiquidOrder combinator:
FactorsThrough :: (A → N) → (A → P) → Bool
FactorsThrough n p = ∀ A B. n A = n B → p A = p B

-- Equivalent form:
QuotientInvariant :: (A → N) → (A → P) → Bool
QuotientInvariant = FactorsThrough
```

**Corpus-level proposition (NOT a general theorem):**

```
OBSERVED_P: ∀ A B ∈ Corpus. N A = N B → P_ext A = P_ext B
```

LiquidOrder classification: `CORPUS_THEOREM` (not `PROVED` over K).

To promote to general theorem:

```
THM-P: ⊢ ∀ A B. InClass K A ∧ InClass K B ∧ N A = N B → P_external A = P_external B
```

Only after actual proof may system label P_ext as `QUOTIENT_INVARIANT`.

**Solver targets for Track 2:**

```
prove FactorsThrough N CyclomaticComplexity   -- likely trivial (internal to F)
prove FactorsThrough N SecurityEstimate        -- external; genuine question
prove FactorsThrough N HardwareCost            -- external; genuine question
prove FactorsThrough N AlgebraicProperty       -- external; genuine question
```

---

## X. Track 3 — DO NOT PROVE 2462

Do NOT add `Omega = 2462` as: axiom, rewrite, target assumption, normalization constant,  
serialization constant, solver hint, search heuristic, or stopping condition.

```
OmegaImpl  : Corpus   → UInt64
OmegaQuot  : Quotient → UInt64
```

External test only:

```
OmegaImpl Corpus == 2462 ?
OmegaQuot Quotient == 2462 ?
```

LiquidOrder status: `EMPIRICAL_NUMERICAL_TEST`  
NOT: theorem, axiom, invariant, proof obligation.

---

## XI. Solver Trust Policy

Solver may: HO pattern matching, rewriting, congruence closure, induction, DAG reasoning,  
arithmetic, finite-set reasoning, graph lemmas, proof search.

Solver MUST return:

```
ProofCertificate { theorem, assumptions, derivation, primitive_rules }
```

Kernel replays certificate:

```
Kernel.check certificate = Thm theorem
```

Forbidden: `SolverResult("TRUE") → accept`  
Required: `SolverResult(proof) → Kernel.check(proof) → Thm`

---

## XII. Required Theorems Checklist

| ID | Statement | Status |
|----|-----------|--------|
| THM-001 | `Derive_Gamma_SC ∈ FP` | Pending audit |
| THM-002 | `Check_Gamma_SC ∈ P` | Pending audit |
| THM-003 | `A →* B → N A = N B` | Pending |
| THM-004 | `EquivalenceRelation EquivalentN` | Pending |
| THM-005 | `N A = N B → F(N A) = F(N B)` | Pending |
| THM-006 | `Serialize injective` | Pending |
| THM-007 | `EquivalentN A B → ClassHash A = ClassHash B` | Pending |
| THM-008 | `∀ Φ_i. SemanticSound Φ_i` | Pending |
| THM-009 | `ValidRenaming ρ ∧ RESOLVED R → N(Rename ρ R) = N R` | Pending |
| THM-010 | `UNRESOLVED_AUTOMORPHISM → HALT` | Pending |
| THM-P | `FactorsThrough N P_external` (optional discovery) | Open |

---

## Final Verdict Vocabulary

| LiquidOrder Status | Meaning |
|--------------------|---------|
| `PROVED` | Kernel-generated Thm exists |
| `REFUTED` | Concrete counterexample exists |
| `UNRESOLVED` | Search incomplete / proof absent |
| `METHOD_LIMIT` | Canonicalization unresolved |
| `EMPIRICAL_ONLY` | Holds only on frozen corpus |

> Never convert `EMPIRICAL_ONLY` into `PROVED`.
