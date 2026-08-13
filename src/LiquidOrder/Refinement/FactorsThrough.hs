-- LiquidOrder: FactorsThrough combinator
-- The core Track 2 mathematical question, encoded as a HOL term.
--
-- FactorsThrough N P = True
--   iff  ∀ A B. N(A) = N(B) → P(A) = P(B)
--
-- This is the central combinator for the quotient experiment.
-- Internal properties (computed from F(N(A))) satisfy this trivially.
-- External properties (independently measured) are genuine discoveries.

module LiquidOrder.Refinement.FactorsThrough
  ( factorsThrough
  , quotientInvariant
  , isInternalProperty
  , externalPropertyGoal
  ) where

import LiquidOrder.IR.Types
import LiquidOrder.Kernel.Kernel (Thm)

-- ---------------------------------------------------------------------------
-- FactorsThrough N P
-- HOL term encoding: ∀ A B. N(A) = N(B) → P(A) = P(B)
-- where A B : AlgType, N : AlgType → NF, P : AlgType → PropType
-- ---------------------------------------------------------------------------

factorsThrough :: Type -> Type -> Type -> Term -> Term -> Term
factorsThrough algType nfType propType nFun pFun =
  let a    = Var "A" algType
      b    = Var "B" algType
      nA   = App nFun a
      nB   = App nFun b
      pA   = App pFun a
      pB   = App pFun b
      hyp  = App (App (eqTerm nfType) nA) nB
      conc = App (App (eqTerm propType) pA) pB
      body = App (App imp hyp) conc
      inner = App (forall algType) (Lam "B" algType body)
  in App (forall algType) (Lam "A" algType inner)

-- Alias: QuotientInvariant = FactorsThrough
quotientInvariant :: Type -> Type -> Type -> Term -> Term -> Term
quotientInvariant = factorsThrough

-- ---------------------------------------------------------------------------
-- Classify a property
--
-- Internal property: computed directly from F(N(A))
--   → FactorsThrough holds trivially by congruence of F
--   → Validates canonicalization machinery
--
-- External property: NOT directly computed from F(N(A))
--   → FactorsThrough is a genuine discovery if proved
-- ---------------------------------------------------------------------------

data PropertyKind
  = InternalProperty String  -- feature name it derives from
  | ExternalProperty String  -- must be independently measured
  deriving (Show, Eq)

isInternalProperty :: PropertyKind -> Bool
isInternalProperty (InternalProperty _) = True
isInternalProperty _                    = False

-- ---------------------------------------------------------------------------
-- Build a proof Goal for FactorsThrough N P_external
-- This is the interesting case — not a tautology.
-- ---------------------------------------------------------------------------

externalPropertyGoal :: Type -> Type -> Type -> Term -> Term -> Context -> Goal
externalPropertyGoal algType nfType propType nFun pFun ctx =
  let obligation = factorsThrough algType nfType propType nFun pFun
      rtype = RefinedType
        { baseType   = TConst "Bool"
        , binder     = "_"
        , refinePred = Refinement (Const "True" (TConst "Bool"))
        }
  in Goal { context = ctx, subject = obligation, goalType = rtype }

-- ---------------------------------------------------------------------------
-- Standard property kinds (classify before attempting proof)
-- ---------------------------------------------------------------------------

cyclomaticComplexity :: PropertyKind
cyclomaticComplexity = InternalProperty "cyclomatic_complexity"
  -- Computed from |E| - |V| + 2P where P = weakly-connected components.
  -- If N(A) = N(B) then F(N(A)) = F(N(B)) → this holds trivially.

vertexCount :: PropertyKind
vertexCount = InternalProperty "vertex_count"

algebraDegree :: PropertyKind
algebraDegree = InternalProperty "algebra_degree"

securityBitLength :: PropertyKind
securityBitLength = ExternalProperty "security_bit_length"
  -- Threat-model-dependent. Must be independently measured.
  -- Corpus observation first; conjecture later; proof required for theorem.

runtimeComplexityClass :: PropertyKind
runtimeComplexityClass = ExternalProperty "runtime_complexity_class"

cryptanalyticWeaknessClass :: PropertyKind
cryptanalyticWeaknessClass = ExternalProperty "cryptanalytic_weakness_class"

hardwareCost :: PropertyKind
hardwareCost = ExternalProperty "hardware_cost"

-- ---------------------------------------------------------------------------
-- Typed logic helpers
-- ---------------------------------------------------------------------------

boolT :: Type
boolT = TConst "Bool"

imp :: Term
imp = Const "==>" (TFun boolT (TFun boolT boolT))

eqTerm :: Type -> Term
eqTerm t = Const "=" (TFun t (TFun t boolT))

forall :: Type -> Term
forall t = Const "!" (TFun (TFun t boolT) boolT)
