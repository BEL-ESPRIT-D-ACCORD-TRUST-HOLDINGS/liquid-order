-- LiquidOrder: Proof certificates + kernel replay
--
-- The solver is UNTRUSTED. A ProofCertificate carries a derivation tree
-- expressed entirely in kernel primitive rules. KernelReplay walks that
-- tree and constructs a Thm using only the trusted kernel.
--
-- No Thm may be constructed by any path other than:
--
--   PrimitiveRules -> DerivedRules -> CertificateReplay -> Thm

module LiquidOrder.Kernel.Certificate
  ( -- Certificate structure
    RuleApp(..)
  , ProofCertificate(..)
  , CertificateDigest(..)
    -- Replay
  , ReplayResult(..)
  , kernelReplay
  , digestCertificate
    -- Solver output (untrusted)
  , SolverOutput(..)
  , rejectIfUncertified
  ) where

import LiquidOrder.Kernel.Kernel (Thm, Term, Type, Name, conclusion, hypotheses)
import qualified LiquidOrder.Kernel.Kernel as K
import Data.List (foldl')
import Data.Maybe (fromMaybe)
import Numeric (showHex)

-- ---------------------------------------------------------------------------
-- Primitive rule application nodes
-- These names MUST correspond 1-to-1 with Kernel.hs exports.
-- ---------------------------------------------------------------------------

data RuleApp
  -- Axiom / assumption
  = RAssume Term

  -- Reflexivity
  | RRefl Term

  -- Beta reduction
  | RBeta Name Type Term Term

  -- Congruence
  | RAbsCong Name Type RuleApp
  | RAppCong RuleApp RuleApp

  -- Modus ponens on equality
  | REqMp RuleApp RuleApp

  -- Deduction antisymmetry (produces propositional equality)
  | RDeduct RuleApp RuleApp

  -- Substitution
  | RInst  [(Name, Term)] RuleApp
  | RTypeInst [(Name, Type)] RuleApp

  -- Derived rule: sequence of apps (fold)
  | RSeq [RuleApp]

  deriving (Show)

-- ---------------------------------------------------------------------------
-- A complete certified derivation
-- ---------------------------------------------------------------------------

data ProofCertificate = ProofCertificate
  { certTheoremId   :: String       -- e.g. "LO-SC-001"
  , certProposition :: Term         -- the proposition being proved
  , certAssumptions :: [Term]       -- hypotheses used
  , certDerivation  :: RuleApp      -- root of derivation tree
  , certDependencies :: [String]    -- IDs of lemmas this relies on
  } deriving (Show)

-- ---------------------------------------------------------------------------
-- A content-addressed digest of a certificate (simple, not cryptographic)
-- ---------------------------------------------------------------------------

newtype CertificateDigest = CertificateDigest String
  deriving (Eq, Show)

digestCertificate :: ProofCertificate -> CertificateDigest
digestCertificate cert =
  -- Simple structural digest: hash of theorem ID + proposition show
  -- Replace with BLAKE3 in production.
  CertificateDigest $
    showHex (simpleHash (certTheoremId cert ++ show (certProposition cert))) ""

simpleHash :: String -> Int
simpleHash = foldl' (\acc c -> acc * 31 + fromEnum c) 5381

-- ---------------------------------------------------------------------------
-- Kernel replay
-- ---------------------------------------------------------------------------

data ReplayResult
  = ReplayValid   Thm             -- kernel accepted; Thm constructed
  | ReplayInvalid String          -- kernel rejected; reason given
  | ReplayUnresolved String       -- rule could not be applied (open obligation)
  deriving (Show)

-- Walk the derivation tree using only kernel primitive rules.
-- Returns ReplayInvalid on any mismatch; never silently succeeds.
kernelReplay :: ProofCertificate -> ReplayResult
kernelReplay cert =
  case applyRule (certDerivation cert) of
    Left err  -> ReplayInvalid err
    Right thm ->
      -- Verify the conclusion matches the stated proposition
      if conclusion thm == certProposition cert
        then ReplayValid thm
        else ReplayInvalid $
               "Conclusion mismatch: certificate claims "
               ++ show (certProposition cert)
               ++ " but kernel produced "
               ++ show (conclusion thm)

applyRule :: RuleApp -> Either String Thm
applyRule (RAssume t)          = Right (K.assume t)
applyRule (RRefl t)            = Right (K.refl t)
applyRule (RBeta x tau body s) = Right (K.beta x tau body s)

applyRule (RAbsCong x tau sub) = do
  thm <- applyRule sub
  Right (K.absCong x tau thm)

applyRule (RAppCong f x) = do
  ft <- applyRule f
  xt <- applyRule x
  Right (K.appCong ft xt)

applyRule (REqMp eq phi) = do
  eqt  <- applyRule eq
  phit <- applyRule phi
  Right (K.eqMp eqt phit)

applyRule (RDeduct t1 t2) = do
  th1 <- applyRule t1
  th2 <- applyRule t2
  Right (K.deduct th1 th2)

applyRule (RInst theta sub) = do
  thm <- applyRule sub
  Right (K.inst theta thm)

applyRule (RTypeInst sigma sub) = do
  thm <- applyRule sub
  Right (K.typeInst sigma thm)

applyRule (RSeq [])    = Left "RSeq: empty derivation"
applyRule (RSeq [r])   = applyRule r
applyRule (RSeq (r:rs)) = do
  _ <- applyRule r     -- validate prefix; final thm comes from last
  applyRule (RSeq rs)

-- ---------------------------------------------------------------------------
-- Solver output wrapper
-- Solvers return SolverOutput. Nothing becomes a Thm until kernel replay.
-- ---------------------------------------------------------------------------

data SolverOutput
  = SolverCertificate ProofCertificate
  | SolverCounterexample String String    -- property, witness
  | SolverUnresolved String               -- why search did not complete
  deriving (Show)

-- Attempt kernel replay on solver output.
-- Returns Nothing for non-certificate outputs (they can't produce Thm).
rejectIfUncertified :: SolverOutput -> Maybe ReplayResult
rejectIfUncertified (SolverCertificate cert) = Just (kernelReplay cert)
rejectIfUncertified _                        = Nothing
