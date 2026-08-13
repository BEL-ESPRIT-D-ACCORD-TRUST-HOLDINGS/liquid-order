-- LiquidOrder: Bridge between Verification a and EpistemicStatus
--
-- Ahmad's Verification type is the runtime invariant-check layer.
-- EpistemicStatus is the formal proof layer.
-- These are complementary, not equivalent:
--
--   Verification a   — checks a specific invariant at a concrete value
--   EpistemicStatus  — classifies the formal proof state of a proposition
--
-- Connections:
--
--   Verified _ InvariantPreserved  -> evidence toward CorpusObservation
--   Verified _ SemanticEquivalent  -> evidence toward SemanticSoundness (LO-SC-008)
--   Refuted  _ _                   -> Refuted (counterexample found)
--   Unverified _                   -> Unresolved (proof deferred)
--
-- A Verified result is NOT the same as EpistemicStatus.Proved.
-- Proved requires KernelReplay(certificate) = ReplayValid.
-- Verified is empirical runtime evidence.
--
-- Connection to FactorsThrough:
--
--   If for all A, B in Corpus:
--     preservesInvariant inv transform inv A = Verified ...
--   THEN this is a CorpusObservation of:
--     FactorsThrough N inv
--
--   It is NOT yet a theorem. It is a candidate invariant.
--
-- Connection to LO-SC-008 (SemanticSoundness):
--
--   preservesInvariantMetric semBefore phi semAfter R metric tol
--   is the runtime check for:
--     pi(Sem(Phi(R), x)) = Sem(R, x)
--
--   Evidence toward LO-SC-008, but not a substitute for the proof.

module LiquidOrder.Quantum.VerificationBridge
  ( verificationToEpistemic
  , liftVerification
  , collectCorpusObservations
  , VerificationEvidence(..)
  ) where

import Data.Complex (Complex(..), magnitude)

-- Import Verification type (re-export from DreamcyclesInvariant is not
-- available at library build time due to Main module conflict; we redeclare
-- the public types here with the same semantics).

data Proof = InvariantPreserved | SemanticEquivalent
  deriving (Show, Eq)

data Verification a
  = Verified a Proof
  | Unverified String
  | Refuted a String
  deriving (Show)

-- ---------------------------------------------------------------------------
-- EpistemicStatus (minimal redeclaration to avoid circular import)
-- The canonical definition lives in Epistemic.Types.
-- ---------------------------------------------------------------------------

data EpistemicStatusBridge
  = BridgeProved           -- only via kernel replay; Verification cannot produce this
  | BridgeRefuted String   -- counterexample found
  | BridgeUnresolved String
  | BridgeCorpusObservation String  -- runtime evidence; candidate invariant
  deriving (Show)

-- ---------------------------------------------------------------------------
-- Lift a Verification result to an epistemic status
--
-- INVARIANT: Verified -> CorpusObservation (NOT Proved)
-- A runtime check is evidence, not a kernel-checked proof.
-- ---------------------------------------------------------------------------

verificationToEpistemic :: Show a => String -> Verification a -> EpistemicStatusBridge
verificationToEpistemic propName (Verified _ InvariantPreserved) =
  BridgeCorpusObservation $
    propName ++ ": runtime invariant held at this input — corpus evidence only"
verificationToEpistemic propName (Verified _ SemanticEquivalent) =
  BridgeCorpusObservation $
    propName ++ ": semantic equivalence at this input — evidence toward LO-SC-008"
verificationToEpistemic propName (Unverified reason) =
  BridgeUnresolved $ propName ++ ": " ++ reason
verificationToEpistemic propName (Refuted val reason) =
  BridgeRefuted $ propName ++ ": counterexample found (" ++ reason ++ ")"

-- ---------------------------------------------------------------------------
-- Lift a function a -> Verification b to a -> EpistemicStatusBridge
-- ---------------------------------------------------------------------------

liftVerification :: Show b => String -> (a -> Verification b) -> a -> EpistemicStatusBridge
liftVerification propName checker x = verificationToEpistemic propName (checker x)

-- ---------------------------------------------------------------------------
-- VerificationEvidence: accumulated corpus-level results
-- Used to feed Track 2 (quotient experiment, FactorsThrough testing)
-- ---------------------------------------------------------------------------

data VerificationEvidence = VerificationEvidence
  { evPropertyName   :: String
  , evInputCount     :: Int
  , evVerifiedCount  :: Int
  , evRefutedCount   :: Int
  , evUnresolvedCount :: Int
  , evStatus         :: EpistemicStatusBridge
  } deriving (Show)

-- Run a Verification check over a corpus and collect evidence.
-- The result status follows the weakest outcome:
--   any Refuted  -> BridgeRefuted
--   all Verified -> BridgeCorpusObservation (FactorsThrough candidate)
--   otherwise    -> BridgeUnresolved
collectCorpusObservations
  :: Show b
  => String              -- property name
  -> (a -> Verification b)  -- checker
  -> [a]                 -- corpus
  -> VerificationEvidence
collectCorpusObservations propName checker corpus =
  let results   = map checker corpus
      nTotal    = length results
      nVerified = length [ () | Verified _ _ <- results ]
      nRefuted  = length [ () | Refuted _ _  <- results ]
      nDeferred = nTotal - nVerified - nRefuted

      refutedExamples = [ reason | Refuted _ reason <- results ]

      status
        | nRefuted > 0 =
            BridgeRefuted $
              propName ++ ": refuted on "
              ++ show nRefuted ++ "/" ++ show nTotal
              ++ " inputs. First: " ++ head refutedExamples
        | nVerified == nTotal =
            BridgeCorpusObservation $
              propName ++ ": held on all " ++ show nTotal
              ++ " corpus inputs — candidate invariant (NOT proved)"
        | otherwise =
            BridgeUnresolved $
              propName ++ ": " ++ show nDeferred ++ " inputs unresolved"

  in VerificationEvidence
       { evPropertyName    = propName
       , evInputCount      = nTotal
       , evVerifiedCount   = nVerified
       , evRefutedCount    = nRefuted
       , evUnresolvedCount = nDeferred
       , evStatus          = status
       }
