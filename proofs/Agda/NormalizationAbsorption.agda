-- LiquidOrder: THM-003 — Normalization Absorption
-- N ∘ T_i = N  →  A →* B  →  N(A) = N(B)
--
-- This is the CORE lemma. Determinism alone is insufficient.
-- Must prove for EVERY rewrite rule T_i in T.

module NormalizationAbsorption where

open import Relation.Binary.PropositionalEquality using (_≡_; refl; trans; cong)
open import Data.List using (List; []; _∷_)

-- ---------------------------------------------------------------------------
-- Abstract types
-- ---------------------------------------------------------------------------

postulate
  Representation : Set
  NormalForm     : Set
  N              : Representation → NormalForm

-- ---------------------------------------------------------------------------
-- Rewrite rules (abstract)
-- ---------------------------------------------------------------------------

data Rewrite : Representation → Representation → Set where
  step : (T_i : Representation → Representation)
       → (absorption : ∀ R → N (T_i R) ≡ N R)
       → (R : Representation)
       → Rewrite R (T_i R)

-- Reflexive-transitive closure
data _→*_ : Representation → Representation → Set where
  refl* : ∀ {A} → A →* A
  step* : ∀ {A B C} → Rewrite A B → B →* C → A →* C

-- ---------------------------------------------------------------------------
-- THM-003: Rewrite closure preserves normal form
-- N(A) = N(B) whenever A →* B
-- ---------------------------------------------------------------------------

normalizationAbsorption : ∀ {A B} → A →* B → N A ≡ N B
normalizationAbsorption refl* = refl
normalizationAbsorption (step* (step T_i absorption R) rest) =
  trans (absorption R) (normalizationAbsorption rest)

-- ---------------------------------------------------------------------------
-- Corollary: EquivalentN is an equivalence relation (THM-004)
-- ---------------------------------------------------------------------------

EquivalentN : Representation → Representation → Set
EquivalentN A B = N A ≡ N B

reflexive-N : ∀ A → EquivalentN A A
reflexive-N A = refl

symmetric-N : ∀ {A B} → EquivalentN A B → EquivalentN B A
symmetric-N p = Relation.Binary.PropositionalEquality.sym p

transitive-N : ∀ {A B C} → EquivalentN A B → EquivalentN B C → EquivalentN A C
transitive-N = trans

-- ---------------------------------------------------------------------------
-- THM-005: Feature determinism follows from function congruence
-- ---------------------------------------------------------------------------

postulate
  Features : Set
  F        : NormalForm → Features

featureDeterminism : ∀ {A B} → N A ≡ N B → F (N A) ≡ F (N B)
featureDeterminism p = cong F p
