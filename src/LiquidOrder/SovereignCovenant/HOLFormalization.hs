-- LiquidOrder: Sovereign-Covenant HOL formalization
--
-- Every frozen mathematical definition from PROTOCOL_v1.md mapped to
-- explicit HOL declarations in the LiquidOrder term language.
--
-- Complexity note:
--   P    = complexity class of DECISION problems
--   FP   = complexity class of deterministic FUNCTION problems
--   NP   = existential decision problems with poly-verifiable witnesses
--   HOL  = logical expressivity framework — NOT a complexity class
--
-- These are DISTINCT. Never conflate them.

module LiquidOrder.SovereignCovenant.HOLFormalization
  ( -- Types
    scTypes
    -- Constants (typed vocabulary)
  , acyclicConst
  , polyFuncConst
  , polyPredConst
  , suppliedConst
  , uniqueConst
  , rootConst
  , deriveConst
  , checkConst
  , deriveInFPConst
  , checkInPConst
    -- HOL propositions (the 10 required theorems)
  , prop_LO_SC_001
  , prop_LO_SC_002
  , prop_LO_SC_003
  , prop_LO_SC_004
  , prop_LO_SC_005
  , prop_LO_SC_006
  , prop_LO_SC_007
  , prop_LO_SC_008
  , prop_LO_SC_009
  , prop_LO_SC_010
    -- DeterministicEvaluator conjunction (HOL compression)
  , deterministicEvaluatorDef
  , sovereignCovenantTheoremHOL
  , factorsThroughHOL
  ) where

import LiquidOrder.Kernel.Kernel (Term(..), Type(..))

-- ---------------------------------------------------------------------------
-- SC-specific types
-- ---------------------------------------------------------------------------

scTypes :: [(String, Type)]
scTypes =
  [ ("State",          TConst "State")
  , ("Algorithm",      TConst "Algorithm")
  , ("Representation", TConst "Representation")
  , ("NormalForm",     TConst "NormalForm")
  , ("Features",       TConst "Features")
  , ("Trace",          TConst "Trace")
  , ("Input",          TConst "Input")
  , ("Bytes",          TConst "Bytes")
  , ("UInt64",         TConst "UInt64")
  , ("Property",       TConst "Property")
  ]

stateT, algT, reprT, nfT, featT, traceT, inputT, bytesT, uint64T, propT :: Type
stateT  = TConst "State"
algT    = TConst "Algorithm"
reprT   = TConst "Representation"
nfT     = TConst "NormalForm"
featT   = TConst "Features"
traceT  = TConst "Trace"
inputT  = TConst "Input"
bytesT  = TConst "Bytes"
uint64T = TConst "UInt64"
propT   = TConst "Property"
boolT :: Type
boolT   = TConst "Bool"

-- ---------------------------------------------------------------------------
-- Typed logical constants (complete vocabulary)
-- ---------------------------------------------------------------------------

imp, conj, forallB :: Term
imp    = Const "==>"   (TFun boolT (TFun boolT boolT))
conj   = Const "/\\"   (TFun boolT (TFun boolT boolT))
forallB = Const "!"    (TFun (TFun boolT boolT) boolT)

eq :: Type -> Term
eq t = Const "=" (TFun t (TFun t boolT))

forall :: Type -> Term
forall t = Const "!" (TFun (TFun t boolT) boolT)

-- SC predicates
acyclicConst, polyFuncConst, polyPredConst :: Term
acyclicConst  = Const "Acyclic"     (TFun reprT boolT)
polyFuncConst = Const "PolyFunc"    (TFun (TFun stateT stateT) boolT)
polyPredConst = Const "PolyPred"    (TFun (TFun stateT boolT) boolT)

suppliedConst, uniqueConst, rootConst :: Term
suppliedConst = Const "Supplied"    (TFun stateT boolT)
uniqueConst   = Const "Unique"      (TFun stateT boolT)
rootConst     = Const "Root"        (TFun reprT (TFun stateT boolT))

deriveConst, checkConst :: Term
deriveConst = Const "Derive" (TFun stateT stateT)
checkConst  = Const "Check"  (TFun stateT boolT)

deriveInFPConst, checkInPConst :: Term
deriveInFPConst = Const "DeriveInFP" (TFun (TFun stateT stateT) boolT)
checkInPConst   = Const "CheckInP"   (TFun (TFun stateT boolT) boolT)

-- Canonicalization constants
normalFormConst, featuresConst :: Term
normalFormConst = Const "N" (TFun reprT nfT)
featuresConst   = Const "F" (TFun nfT featT)

serializeConst :: Term
serializeConst = Const "Serialize" (TFun featT bytesT)

classHashConst :: Term
classHashConst = Const "ClassHash" (TFun reprT uint64T)

semConst :: Term
semConst = Const "Sem" (TFun reprT (TFun inputT traceT))

piConst :: Term
piConst = Const "pi" (TFun traceT traceT)

rewriteStarConst :: Term
rewriteStarConst = Const "RewriteStar" (TFun reprT (TFun reprT boolT))

validRenamingConst, renameConst, resolvedConst :: Term
validRenamingConst = Const "ValidRenaming" (TFun reprT boolT)
renameConst        = Const "Rename" (TFun reprT (TFun reprT reprT))
resolvedConst      = Const "Resolved" (TFun reprT boolT)

unresolvedConst :: Term
unresolvedConst = Const "UnresolvedAutomorphism" (TFun reprT boolT)

haltConst :: Term
haltConst = Const "HALT" boolT

-- ---------------------------------------------------------------------------
-- Helper: build ∀x:τ. body(x)
-- ---------------------------------------------------------------------------

mkForall :: String -> Type -> Term -> Term
mkForall x tau body = App (forall tau) (Lam x tau body)

-- Helper: A → B
mkImp :: Term -> Term -> Term
mkImp a b = App (App imp a) b

-- Helper: A ∧ B
mkConj :: Term -> Term -> Term
mkConj a b = App (App conj a) b

-- Helper: a = b at type τ
mkEq :: Type -> Term -> Term -> Term
mkEq t a b = App (App (eq t) a) b

-- ---------------------------------------------------------------------------
-- DeterministicEvaluator HOL definition (compressed form per §6)
--
--   DeterministicEvaluator(G, F, P, R) :=
--     Acyclic(G)
--     ∧ (∀ f. Member(f,F) → PolyFunc(f))
--     ∧ (∀ p. Member(p,P) → PolyPred(p))
--     ∧ (∀ r. Root(G,r) → Supplied(r) ∨ Unique(r))
-- ---------------------------------------------------------------------------

deterministicEvaluatorDef :: Term
deterministicEvaluatorDef =
  let g = Var "G" reprT
      f = Var "f" (TFun stateT stateT)
      p = Var "p" (TFun stateT boolT)
      r = Var "r" stateT
      memberF = Const "MemberF" (TFun (TFun stateT stateT) boolT)
      memberP = Const "MemberP" (TFun (TFun stateT boolT) boolT)
      orC     = Const "\\/" (TFun boolT (TFun boolT boolT))

      h1 = App acyclicConst g
      h2 = mkForall "f" (TFun stateT stateT)
             (mkImp (App memberF f) (App polyFuncConst f))
      h3 = mkForall "p" (TFun stateT boolT)
             (mkImp (App memberP p) (App polyPredConst p))
      h4 = mkForall "r" stateT
             (mkImp (App (App rootConst g) r)
               (App (App orC (App suppliedConst r)) (App uniqueConst r)))
  in mkConj h1 (mkConj h2 (mkConj h3 h4))

-- ---------------------------------------------------------------------------
-- The central Track 1 theorem in HOL (§6 theorem schema)
--
--   ∀ G. DeterministicEvaluator(G)
--     → DeriveInFP(Derive) ∧ CheckInP(Check)
-- ---------------------------------------------------------------------------

sovereignCovenantTheoremHOL :: Term
sovereignCovenantTheoremHOL =
  mkForall "G" reprT
    (mkImp deterministicEvaluatorDef
      (mkConj
        (App deriveInFPConst deriveConst)
        (App checkInPConst   checkConst)))

-- ---------------------------------------------------------------------------
-- FactorsThrough (§10): central Track 2 combinator
--
--   FactorsThrough(N, P) := ∀ A B. N(A) = N(B) → P(A) = P(B)
-- ---------------------------------------------------------------------------

factorsThroughHOL :: Type -> Type -> Term -> Term -> Term
factorsThroughHOL srcT tgtT nFun pFun =
  let a   = Var "A" srcT
      b   = Var "B" srcT
      nA  = App nFun a
      nB  = App nFun b
      pA  = App pFun a
      pB  = App pFun b
      nfEq = mkEq nfT nA nB   -- assumes nFun maps to nfT; parameterize if needed
      pEq  = mkEq tgtT pA pB
  in mkForall "A" srcT
       (mkForall "B" srcT
         (mkImp nfEq pEq))

-- ---------------------------------------------------------------------------
-- 10 required theorem propositions
-- Each is the HOL term the solver must certify.
-- ---------------------------------------------------------------------------

-- LO-SC-001: Derive_{Γ_SC} ∈ FP
prop_LO_SC_001 :: Term
prop_LO_SC_001 = App deriveInFPConst deriveConst

-- LO-SC-002: Check_{Γ_SC} ∈ P
prop_LO_SC_002 :: Term
prop_LO_SC_002 = App checkInPConst checkConst

-- LO-SC-003: ∀ A B. RewriteStar(A,B) → N(A) = N(B)
prop_LO_SC_003 :: Term
prop_LO_SC_003 =
  mkForall "A" reprT
    (mkForall "B" reprT
      (mkImp
        (App (App rewriteStarConst (Var "A" reprT)) (Var "B" reprT))
        (mkEq nfT
          (App normalFormConst (Var "A" reprT))
          (App normalFormConst (Var "B" reprT)))))

-- LO-SC-004: EquivalenceRelation(EquivalentN)
-- Encoded as: reflexive ∧ symmetric ∧ transitive
prop_LO_SC_004 :: Term
prop_LO_SC_004 =
  let equivN a b = mkEq nfT (App normalFormConst a) (App normalFormConst b)
      a = Var "A" reprT; b = Var "B" reprT; c = Var "C" reprT
      refl'  = mkForall "A" reprT (equivN a a)
      sym'   = mkForall "A" reprT (mkForall "B" reprT
                 (mkImp (equivN a b) (equivN b a)))
      trans' = mkForall "A" reprT (mkForall "B" reprT (mkForall "C" reprT
                 (mkImp (equivN a b) (mkImp (equivN b c) (equivN a c)))))
  in mkConj refl' (mkConj sym' trans')

-- LO-SC-005: ∀ A B. N(A) = N(B) → F(N(A)) = F(N(B))
prop_LO_SC_005 :: Term
prop_LO_SC_005 =
  let a = Var "A" reprT; b = Var "B" reprT
  in mkForall "A" reprT
       (mkForall "B" reprT
         (mkImp
           (mkEq nfT (App normalFormConst a) (App normalFormConst b))
           (mkEq featT
             (App featuresConst (App normalFormConst a))
             (App featuresConst (App normalFormConst b)))))

-- LO-SC-006: ∀ f1 f2. Serialize(f1) = Serialize(f2) → f1 = f2
prop_LO_SC_006 :: Term
prop_LO_SC_006 =
  let f1 = Var "f1" featT; f2 = Var "f2" featT
  in mkForall "f1" featT
       (mkForall "f2" featT
         (mkImp
           (mkEq bytesT (App serializeConst f1) (App serializeConst f2))
           (mkEq featT f1 f2)))

-- LO-SC-007: ∀ A B. EquivalentN(A,B) → ClassHash(A) = ClassHash(B)
prop_LO_SC_007 :: Term
prop_LO_SC_007 =
  let a = Var "A" reprT; b = Var "B" reprT
  in mkForall "A" reprT
       (mkForall "B" reprT
         (mkImp
           (mkEq nfT (App normalFormConst a) (App normalFormConst b))
           (mkEq uint64T (App classHashConst a) (App classHashConst b))))

-- LO-SC-008: ∀ Φ R x. NormalizationPhase(Φ) → π(Sem(Φ(R),x)) = Sem(R,x)
-- Semantic soundness of all normalization phases.
prop_LO_SC_008 :: Term
prop_LO_SC_008 =
  let phiT = TFun reprT reprT
      normPhaseConst = Const "NormalizationPhase" (TFun phiT boolT)
      phi = Var "Phi" phiT; r = Var "R" reprT; x = Var "x" inputT
  in mkForall "Phi" phiT
       (mkForall "R" reprT
         (mkForall "x" inputT
           (mkImp
             (App normPhaseConst phi)
             (mkEq traceT
               (App piConst (App (App semConst (App phi r)) x))
               (App (App semConst r) x)))))

-- LO-SC-009: ∀ ρ R. ValidRenaming(ρ) ∧ Resolved(R) → N(Rename(ρ,R)) = N(R)
prop_LO_SC_009 :: Term
prop_LO_SC_009 =
  let rho = Var "rho" reprT; r = Var "R" reprT
  in mkForall "rho" reprT
       (mkForall "R" reprT
         (mkImp
           (mkConj (App validRenamingConst rho) (App resolvedConst r))
           (mkEq nfT
             (App normalFormConst (App (App renameConst rho) r))
             (App normalFormConst r))))

-- LO-SC-010: ∀ R. UnresolvedAutomorphism(R) → HALT
prop_LO_SC_010 :: Term
prop_LO_SC_010 =
  mkForall "R" reprT
    (mkImp (App unresolvedConst (Var "R" reprT)) haltConst)
