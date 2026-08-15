-- SpectralSummation.lean
-- Thin summation layer: spectral blocks → linear trace functional
--
-- This layer does NOT:
--   materialize the zero list
--   enumerate γₙ
--   assume convergence silently
--
-- It DOES:
--   define Summand, FiniteSum, LimitSum, TraceFunctional
--   make convergence an explicit contract
--   provide linearity as a reusable lemma
--
-- Chain:
--   H → {(λ, m_λ)} → T_H → T_H(f) → Weil(f)

import Mathlib.Topology.Algebra.InfiniteSum.Basic
import Mathlib.Analysis.SpecificLimits.Basic

-- ---------------------------------------------------------------------------
-- Summand: one spectral block contribution
-- ---------------------------------------------------------------------------

structure Summand (F : ℝ → ℝ) where
  eigenvalue   : ℝ
  multiplicity : ℕ          -- algebraic multiplicity (= 1 for self-adjoint H)
  weight       : ℝ := (multiplicity : ℝ) * F eigenvalue

-- ---------------------------------------------------------------------------
-- Finite spectral sum over a list of blocks (fold-based)
-- ---------------------------------------------------------------------------

noncomputable def finiteSpectralSum (F : ℝ → ℝ) (blocks : List (ℝ × ℕ)) : ℝ :=
  blocks.foldl (fun acc ⟨λ, m⟩ => acc + (m : ℝ) * F λ) 0

-- Linearity: Σ m·(f+g) = Σ m·f + Σ m·g
theorem finiteSum_add (F G : ℝ → ℝ) (blocks : List (ℝ × ℕ)) :
    finiteSpectralSum (fun x => F x + G x) blocks =
    finiteSpectralSum F blocks + finiteSpectralSum G blocks := by
  induction blocks with
  | nil        => simp [finiteSpectralSum]
  | cons h t ih =>
    simp [finiteSpectralSum, List.foldl_cons]
    linarith [ih]

-- Linearity: Σ m·(c·f) = c · Σ m·f
theorem finiteSum_smul (c : ℝ) (F : ℝ → ℝ) (blocks : List (ℝ × ℕ)) :
    finiteSpectralSum (fun x => c * F x) blocks =
    c * finiteSpectralSum F blocks := by
  induction blocks with
  | nil        => simp [finiteSpectralSum]
  | cons h t ih =>
    simp [finiteSpectralSum, List.foldl_cons]
    linarith [ih]

-- ---------------------------------------------------------------------------
-- SumSpec: explicit contracts for the summation
-- No silent assumptions
-- ---------------------------------------------------------------------------

structure SumSpec (blocks : ℝ → ℕ) where
  -- Contract 1: domain of summation
  domain       : Set ℝ               -- which λ have blocks(λ) > 0
  -- Contract 2: multiplicity specification
  multiplicity : ∀ λ ∈ domain, blocks λ ≥ 1
  -- Contract 3: cutoff sequence
  cutoff       : ℕ → ℝ               -- cutoff_n = max |λ| included at step n
  cutoff_mono  : Monotone cutoff      -- cutoffs increase
  cutoff_tends : Filter.Tendsto cutoff Filter.atTop Filter.atTop   -- → ∞
  -- Contract 4: convergence (explicit, not assumed)
  convergent   : ∀ (F : ℝ → ℝ),
    Summable (fun λ : {x : ℝ // x ∈ domain} => (blocks λ.val : ℝ) * F λ.val)
  -- Contract 5: linearity
  linear       : ∀ (F G : ℝ → ℝ),
    (∑' λ : {x // x ∈ domain}, (blocks λ.val : ℝ) * (F + G) λ.val) =
    (∑' λ : {x // x ∈ domain}, (blocks λ.val : ℝ) * F λ.val) +
    (∑' λ : {x // x ∈ domain}, (blocks λ.val : ℝ) * G λ.val)

-- ---------------------------------------------------------------------------
-- Cutoff sum S_R(f) — truncated spectral sum
-- S_R(f) = fold (λ → m_λ f(λ)) over blocks with |λ| ≤ R
-- ---------------------------------------------------------------------------

noncomputable def cutoffSum (spec : SumSpec blocks) (R : ℝ) (F : ℝ → ℝ) : ℝ :=
  ∑' λ : {x : ℝ // x ∈ spec.domain ∧ |x| ≤ R},
    (blocks λ.val : ℝ) * F λ.val

-- Cutoff sum increases monotonically in R (for non-negative F)
theorem cutoffSum_mono (spec : SumSpec blocks) (R₁ R₂ : ℝ) (hR : R₁ ≤ R₂)
    (F : ℝ → ℝ) (hF : ∀ x, 0 ≤ F x) :
    cutoffSum spec R₁ F ≤ cutoffSum spec R₂ F := by
  apply tsum_le_tsum_of_injOn
  · intro ⟨λ, hλ_dom, hλ_R₁⟩
    exact ⟨hλ_dom, le_trans hλ_R₁ (by linarith)⟩
  · intro ⟨λ, _⟩; positivity
  · exact (limitSum_exists spec F).mono (fun ⟨λ, hλ_dom, _⟩ => hλ_dom)

-- ---------------------------------------------------------------------------
-- LimitSum: the infinite spectral sum (only when convergence is proved)
-- ---------------------------------------------------------------------------

noncomputable def limitSum (spec : SumSpec blocks) (F : ℝ → ℝ) : ℝ :=
  ∑' λ : {x : ℝ // x ∈ spec.domain},
    (blocks λ.val : ℝ) * F λ.val

-- The limit sum exists (by spec.convergent)
theorem limitSum_exists (spec : SumSpec blocks) (F : ℝ → ℝ) :
    Summable (fun λ : {x : ℝ // x ∈ spec.domain} => (blocks λ.val : ℝ) * F λ.val) :=
  spec.convergent F

-- Linearity of limitSum (from spec.linear)
theorem limitSum_add (spec : SumSpec blocks) (F G : ℝ → ℝ) :
    limitSum spec (F + G) = limitSum spec F + limitSum spec G :=
  spec.linear F G

-- ---------------------------------------------------------------------------
-- TraceFunctional T_H: the linear trace functional
-- T_H(f) = Σ_λ m_H(λ) · f(λ)
-- This IS the trace of f(H) when H is trace-class or admits the spectral theorem
-- ---------------------------------------------------------------------------

/-- The trace functional as a linear map ℝ^ℝ → ℝ.
    Defined by the spectral sum; requires SumSpec for convergence. -/
noncomputable def traceFunctionalSpec (spec : SumSpec blocks) : (ℝ → ℝ) →ₗ[ℝ] ℝ :=
  { toFun    := limitSum spec
    map_add' := fun F G => limitSum_add spec F G
    map_smul' := by
      intro c F
      simp [limitSum, tsum_const_smul]
      congr 1; ext λ; ring }

-- ---------------------------------------------------------------------------
-- The trace chain (O5): T_H(f) → WeilExplicitFormula(f)
-- ---------------------------------------------------------------------------

/-- Bridge: the trace functional equals the Weil functional.
    This is O5c + O5d combined.
    Proof requires: spectral correspondence (O4) + analytic identity. -/
theorem trace_equals_weil
    (spec : SumSpec spectralMultiplicity)
    (h_spectral_match : O4c_MultiplicityMatch)
    (F : ℝ → ℝ) :
    limitSum spec F = WeilExplicitFormula F := by
  sorry
  -- O5: the sum over spectral blocks = Weil explicit formula.
  -- Requires:
  --   1. spec.domain = ZeroImaginaryPartOfZeta (from O4a+O4b)
  --   2. multiplicities match (O4c)
  --   3. the Weil identity itself (classical — Weil 1952)

-- ---------------------------------------------------------------------------
-- Summary: what the summation layer provides
-- ---------------------------------------------------------------------------

-- Summand          : algebraic block contribution
-- finiteSpectralSum: fold-based finite sum, with linearity proved
-- SumSpec          : explicit contracts (domain, mult, cutoff, convergence, linear)
-- cutoffSum        : S_R(f) = truncated spectral sum, monotone in R
-- limitSum         : infinite spectral sum, exists by spec.convergent
-- traceFunctionalSpec: linear functional T_H : (ℝ→ℝ) →ₗ[ℝ] ℝ
-- trace_equals_weil: the bridge — conditional on O4 + Weil identity

-- What remains MISSING:
--   SumSpec.convergent for the Shadow Laplacian spec
--   trace_equals_weil (O5d — the Weil identity)
--   O4a, O4b, O4c — the spectral correspondence
