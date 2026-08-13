-- LiquidOrder: Quantum Language B — HOL propositions
--
-- Every obligation from Obligations.hs as an explicit HOL Term.
-- These are what the solver must certify via ProofCertificate -> KernelReplay.
--
-- Key definitions:
--
--   Macrobit M_i in H_i,  d_i = dim(H_i)  (not assumed binary)
--   Shard = boundary subsystem, boundary region S subset ∂B
--   Encode : BulkState -> HorizonState  (isometry)
--   Scramble : State -> Time -> State   (unitary)
--   Recover : ShardSet -> LogicalQubit -> Maybe Qubit
--   Entropy : State -> Real
--   Area : Horizon -> Real
--
-- Central target (QLB-002):
--
--   log(dim(E(H_physical_bulk))) = A / (4 * lP^2)
--
-- This must be DERIVED. It is not inserted as an axiom.

module LiquidOrder.QuantumLangB.HOLFormalization
  ( -- Types
    qlbTypes
    -- Core constants
  , encodeConst, scrambleConst, recoverConst
  , entropyConst, areaConst, dimConst
  , isometryConst, unitaryConst, recoverableConst
    -- Propositions
  , prop_QLB_001  -- Isometry
  , prop_QLB_002  -- Area law (derived, not inserted)
  , prop_QLB_003  -- Unitarity
  , prop_QLB_004  -- Information conservation
  , prop_QLB_005  -- Shard recoverability
  , prop_QLB_006  -- Macrobit dim constraint (area not volume)
  , prop_QLB_007  -- Decoding complexity (QMA conjecture)
    -- Central open question as HOL
  , centralOpenQuestion
  ) where

import LiquidOrder.Kernel.Kernel (Term(..), Type(..))

-- ---------------------------------------------------------------------------
-- Quantum Language B types
-- ---------------------------------------------------------------------------

qlbTypes :: [(String, Type)]
qlbTypes =
  [ ("BulkState",     TConst "BulkState")
  , ("HorizonState",  TConst "HorizonState")
  , ("RadState",      TConst "RadState")
  , ("Macrobit",      TConst "Macrobit")
  , ("Shard",         TConst "Shard")
  , ("ShardSet",      TConst "ShardSet")
  , ("LogicalQubit",  TConst "LogicalQubit")
  , ("Horizon",       TConst "Horizon")
  , ("Time",          TConst "Time")
  , ("Real",          TConst "Real")
  , ("Nat",           TConst "Nat")
  , ("Bool",          TConst "Bool")
  , ("MaybeQubit",    TConst "MaybeQubit")
  ]

bulkT, horizT, shardT, shardSetT, lqT, horizonT, timeT, realT, natT, boolT :: Type
bulkT    = TConst "BulkState"
horizT   = TConst "HorizonState"
shardT   = TConst "Shard"
shardSetT = TConst "ShardSet"
lqT      = TConst "LogicalQubit"
horizonT = TConst "Horizon"
timeT    = TConst "Time"
realT    = TConst "Real"
natT     = TConst "Nat"
boolT    = TConst "Bool"

stateT :: Type
stateT = TConst "State"   -- unified state type for scrambling

-- ---------------------------------------------------------------------------
-- Typed constants
-- ---------------------------------------------------------------------------

encodeConst :: Term
encodeConst = Const "Encode" (TFun bulkT horizT)

scrambleConst :: Term
scrambleConst = Const "Scramble" (TFun stateT (TFun timeT stateT))

recoverConst :: Term
recoverConst = Const "Recover" (TFun shardSetT (TFun lqT (TConst "MaybeQubit")))

entropyConst :: Term
entropyConst = Const "Entropy" (TFun stateT realT)

areaConst :: Term
areaConst = Const "Area" (TFun horizonT realT)

dimConst :: Term
dimConst = Const "Dim" (TFun (TConst "HilbertSpace") natT)

isometryConst :: Term
isometryConst = Const "Isometry" (TFun (TFun bulkT horizT) boolT)

unitaryConst :: Term
unitaryConst = Const "Unitary" (TFun (TFun stateT stateT) boolT)

recoverableConst :: Term
recoverableConst = Const "Recoverable" (TFun lqT boolT)

logDimConst :: Term
logDimConst = Const "LogDim" (TFun (TConst "HilbertSpace") realT)

planckAreaConst :: Term
planckAreaConst = Const "PlanckArea" realT   -- lP^2

bHEntropyConst :: Term
bHEntropyConst = Const "BHEntropy" (TFun horizonT realT)
  -- S_BH = A / (4 * lP^2)

-- Logic helpers
imp, conj :: Term
imp  = Const "==>" (TFun boolT (TFun boolT boolT))
conj = Const "/\\" (TFun boolT (TFun boolT boolT))

eq :: Type -> Term
eq t = Const "=" (TFun t (TFun t boolT))

forall :: Type -> Term
forall t = Const "!" (TFun (TFun t boolT) boolT)

exists :: Type -> Term
exists t = Const "?" (TFun (TFun t boolT) boolT)

mkForall :: String -> Type -> Term -> Term
mkForall x tau body = App (forall tau) (Lam x tau body)

mkExists :: String -> Type -> Term -> Term
mkExists x tau body = App (exists tau) (Lam x tau body)

mkImp :: Term -> Term -> Term
mkImp a b = App (App imp a) b

mkConj :: Term -> Term -> Term
mkConj a b = App (App conj a) b

mkEq :: Type -> Term -> Term -> Term
mkEq t a b = App (App (eq t) a) b

-- ---------------------------------------------------------------------------
-- QLB-001: Isometry(Encode)
-- E† E = I  <=>  dim(H_horizon) >= dim(H_bulk)
-- ---------------------------------------------------------------------------

prop_QLB_001 :: Term
prop_QLB_001 = App isometryConst encodeConst

-- ---------------------------------------------------------------------------
-- QLB-002: Area law — MUST BE DERIVED, not inserted
--
--   log(dim(E(H_bulk_physical))) = A / (4 * lP^2)
--
-- HOL form:
--   LogDim(Image(Encode, H_bulk_physical))
--   = Area(horizon) / (4 * PlanckArea)
-- ---------------------------------------------------------------------------

prop_QLB_002 :: Term
prop_QLB_002 =
  let imageHS  = App (Const "Image" (TFun (TFun bulkT horizT) (TConst "HilbertSpace")))
                     encodeConst
      logDimImg = App logDimConst imageHS
      bhEntropy = App bHEntropyConst (Var "horizon" horizonT)
  in mkForall "horizon" horizonT
       (mkEq realT logDimImg bhEntropy)

-- ---------------------------------------------------------------------------
-- QLB-003: Unitarity of all scrambling maps
--
--   forall t. Unitary(Scramble(-, t))
-- ---------------------------------------------------------------------------

prop_QLB_003 :: Term
prop_QLB_003 =
  mkForall "t" timeT
    (App unitaryConst
      (Lam "s" stateT (App (App scrambleConst (Var "s" stateT)) (Var "t" timeT))))

-- ---------------------------------------------------------------------------
-- QLB-004: Information conservation under unitary evolution
--
--   forall t. Entropy(State_t) = Entropy(State_0)
--
-- (For pure states under unitary: entropy is constant)
-- ---------------------------------------------------------------------------

prop_QLB_004 :: Term
prop_QLB_004 =
  let s0 = Var "s0" stateT
      st = Var "st" stateT
      tVar = Var "t" timeT
      stAtT = App (App scrambleConst s0) tVar
  in mkForall "s0" stateT
       (mkForall "t" timeT
         (mkEq realT
           (App entropyConst (App (App scrambleConst s0) tVar))
           (App entropyConst s0)))

-- ---------------------------------------------------------------------------
-- QLB-005: Shard recoverability
--
--   forall B : LogicalQubit.
--     Recoverable(B)
--     => exists S : ShardSet. Recover(S, B) = Recovered(B)
-- ---------------------------------------------------------------------------

prop_QLB_005 :: Term
prop_QLB_005 =
  let b = Var "B" lqT
      s = Var "S" shardSetT
      recResult = App (App recoverConst s) b
      recovered = App (Const "Recovered" (TFun lqT (TConst "MaybeQubit"))) b
  in mkForall "B" lqT
       (mkImp
         (App recoverableConst b)
         (mkExists "S" shardSetT
           (mkEq (TConst "MaybeQubit") recResult recovered)))

-- ---------------------------------------------------------------------------
-- QLB-006: Macrobit dimension constraint
-- The central open question as a falsifiable proposition:
--
--   There exist constraints C on (E, {U_t}, H_shard) such that
--   log(dim(H_code)) is proportional to Area(horizon), not Volume(bulk).
--
--   Binary case (special): if all d_i = 2, then N = A / (4 * lP^2 * ln 2)
--   This is what a binary model must reproduce. It is not an axiom.
-- ---------------------------------------------------------------------------

prop_QLB_006 :: Term
prop_QLB_006 =
  let constraintT = TConst "PhysicalConstraints"
      c = Var "C" constraintT
      logDimCode = Const "LogDimCode" realT
      areaH = App areaConst (Var "H" horizonT)
      proportionalConst = Const "ProportionalTo"
                            (TFun realT (TFun realT boolT))
  in mkExists "C" constraintT
       (mkForall "H" horizonT
         (App (App proportionalConst logDimCode) areaH))

-- ---------------------------------------------------------------------------
-- QLB-007: Decoding complexity (QMA conjecture — separate from entropy)
--
--   The computational hardness of Recover(S, B) for arbitrary S.
--   This is independent of QLB-001 through QLB-006.
--   Entropy-area does NOT resolve P vs NP.
-- ---------------------------------------------------------------------------

prop_QLB_007 :: Term
prop_QLB_007 =
  let qmaHardConst = Const "QMAHard" (TFun (TFun shardSetT (TFun lqT (TConst "MaybeQubit"))) boolT)
  in App qmaHardConst recoverConst

-- ---------------------------------------------------------------------------
-- Central open question as a single HOL term
--
--   What constraints on (E, {U_t}, H_shard) force
--   log(dim(H_code)) ∝ A rather than V?
-- ---------------------------------------------------------------------------

centralOpenQuestion :: Term
centralOpenQuestion =
  -- "Find the constraints": existential over constraint families
  mkExists "C" (TConst "PhysicalConstraints")
    (mkConj
      -- Condition 1: area law holds under C
      (mkForall "H" horizonT
        (App (App (Const "ProportionalTo" (TFun realT (TFun realT boolT)))
                  (Const "LogDimCode" realT))
             (App areaConst (Var "H" horizonT))))
      -- Condition 2: volume law does NOT hold under C
      (App (Const "Not" (TFun boolT boolT))
        (mkForall "H" horizonT
          (App (App (Const "ProportionalTo" (TFun realT (TFun realT boolT)))
                    (Const "LogDimCode" realT))
               (App (Const "Volume" (TFun horizonT realT))
                    (Var "H" horizonT))))))
