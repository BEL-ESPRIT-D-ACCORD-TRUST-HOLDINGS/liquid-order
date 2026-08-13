-- LiquidOrder: Epistemic type system
--
-- Every result in the system carries an EpistemicStatus.
-- The build fails if any REQUIRED theorem lacks a PROVED certificate.
-- Status transitions are one-directional and explicit.
-- Silent promotion from one state to another is forbidden.

module LiquidOrder.Epistemic.Types
  ( EpistemicStatus(..)
  , TheoremRecord(..)
  , ManifestEntry(..)
  , statusLabel
  , isProved
  , canPromoteTo
  , requireProved
  ) where

import LiquidOrder.Kernel.Certificate (CertificateDigest, ReplayResult(..))

-- ---------------------------------------------------------------------------
-- Epistemic status — complete closed enumeration
-- NEVER add a wildcard promotion path between these.
-- ---------------------------------------------------------------------------

data EpistemicStatus
  = Proved           -- kernel-checked theorem (KernelReplay returned ReplayValid)
  | Refuted          -- machine-checkable counterexample exists
  | Unresolved       -- neither proof nor refutation obtained; search incomplete
  | CorpusObservation  -- holds over frozen finite corpus only; no claim beyond C
  | CandidateInvariant -- corpus regularity selected for generalization attempt
  | Conjecture       -- explicit universally-quantified proposition awaiting proof
  | MethodLimit      -- proof/canonicalization method could not resolve the case
  | EmpiricalNumericalResult  -- numerical experiment result (Track 3)
  deriving (Eq, Ord, Show)

statusLabel :: EpistemicStatus -> String
statusLabel Proved                  = "PROVED"
statusLabel Refuted                 = "REFUTED"
statusLabel Unresolved              = "UNRESOLVED"
statusLabel CorpusObservation       = "CORPUS_OBSERVATION"
statusLabel CandidateInvariant      = "CANDIDATE_INVARIANT"
statusLabel Conjecture              = "CONJECTURE"
statusLabel MethodLimit             = "METHOD_LIMIT"
statusLabel EmpiricalNumericalResult = "EMPIRICAL_NUMERICAL_RESULT"

isProved :: EpistemicStatus -> Bool
isProved Proved = True
isProved _      = False

-- ---------------------------------------------------------------------------
-- Legal promotion paths
-- Only explicit upward moves; no silent skipping.
-- ---------------------------------------------------------------------------

canPromoteTo :: EpistemicStatus -> EpistemicStatus -> Bool
canPromoteTo CorpusObservation CandidateInvariant = True
canPromoteTo CandidateInvariant Conjecture        = True
canPromoteTo Conjecture         Proved            = True
canPromoteTo Unresolved         Proved            = True   -- if certificate arrives
canPromoteTo Unresolved         Refuted           = True   -- if counterexample arrives
canPromoteTo _                  _                 = False

-- ---------------------------------------------------------------------------
-- Build-time assertion: fail if a required theorem is not Proved
-- ---------------------------------------------------------------------------

requireProved :: TheoremRecord -> Either String ()
requireProved tr
  | isProved (trStatus tr) = Right ()
  | otherwise = Left $
      "BUILD FAILURE: required theorem "
      ++ trId tr
      ++ " has status "
      ++ statusLabel (trStatus tr)
      ++ " — kernel-checked certificate required"

-- ---------------------------------------------------------------------------
-- Theorem record: one entry per proof obligation
-- ---------------------------------------------------------------------------

data TheoremRecord = TheoremRecord
  { trId           :: String            -- e.g. "LO-SC-001"
  , trProposition  :: String            -- human-readable proposition
  , trAssumptions  :: [String]          -- assumption IDs
  , trDependencies :: [String]          -- theorem IDs this depends on
  , trStatus       :: EpistemicStatus
  , trCertDigest   :: Maybe CertificateDigest  -- Nothing if not yet certified
  , trRequired     :: Bool              -- build fails if True and not Proved
  } deriving (Show)

-- ---------------------------------------------------------------------------
-- Manifest entry (serialization-facing)
-- ---------------------------------------------------------------------------

data ManifestEntry = ManifestEntry
  { meId           :: String
  , meProposition  :: String
  , meAssumptions  :: [String]
  , meDependencies :: [String]
  , meCertDigest   :: String           -- hex digest or "NONE"
  , meKernelStatus :: String           -- statusLabel
  , meRequired     :: Bool
  } deriving (Show)

fromRecord :: TheoremRecord -> ManifestEntry
fromRecord tr = ManifestEntry
  { meId           = trId tr
  , meProposition  = trProposition tr
  , meAssumptions  = trAssumptions tr
  , meDependencies = trDependencies tr
  , meCertDigest   = maybe "NONE" (\(d) -> show d) (trCertDigest tr)
  , meKernelStatus = statusLabel (trStatus tr)
  , meRequired     = trRequired tr
  }
