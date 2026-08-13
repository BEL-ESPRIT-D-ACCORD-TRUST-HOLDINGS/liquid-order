-- LiquidOrder: Track 3 — Omega isolation module
--
-- The numerical target is NEVER embedded here.
-- This module computes Omega from the corpus/quotient and returns a UInt64.
-- The comparison with the preregistered target happens EXTERNALLY, after
-- all prior stages complete.
--
-- CLASSIFICATION: EMPIRICAL_NUMERICAL_RESULT
-- NOT: theorem, axiom, invariant, proof obligation.
--
-- Firewall: 2462 does not appear in this module.

module LiquidOrder.Track3.Omega
  ( OmegaSource(..)
  , OmegaResult(..)
  , computeOmegaImpl
  , computeOmegaQuot
  , omegaIsReady
  ) where

import LiquidOrder.Epistemic.Types (EpistemicStatus(..))
import LiquidOrder.Manifest.Manifest (Manifest, checkBuildConstraints)
import Data.List (foldl')
import Data.Bits ((.&.))
import Data.Word (Word64)

-- ---------------------------------------------------------------------------
-- Source selection
-- ---------------------------------------------------------------------------

data OmegaSource
  = OmegaFromImpl   -- compute from per-algorithm implementation hashes
  | OmegaFromQuot   -- compute from per-equivalence-class hashes
  deriving (Eq, Show)

-- ---------------------------------------------------------------------------
-- Omega result
-- ---------------------------------------------------------------------------

data OmegaResult = OmegaResult
  { orSource :: OmegaSource
  , orValue  :: Word64
  , orStatus :: EpistemicStatus  -- always EmpiricalNumericalResult when computed
  , orNote   :: String
  } deriving (Show)

-- ---------------------------------------------------------------------------
-- Firewall: Track 3 may only run after manifest confirms all required proofs
-- ---------------------------------------------------------------------------

omegaIsReady :: Manifest -> Bool
omegaIsReady m = case checkBuildConstraints m of
  Right () -> True
  Left _   -> False

-- ---------------------------------------------------------------------------
-- Compute Omega from a list of 64-bit class hashes
-- Omega = sum of all hashes mod 2^64
-- ---------------------------------------------------------------------------

computeOmegaImpl :: [Word64] -> OmegaResult
computeOmegaImpl hashes = OmegaResult
  { orSource = OmegaFromImpl
  , orValue  = sumMod64 hashes
  , orStatus = EmpiricalNumericalResult
  , orNote   = "Omega_impl: sum of per-algorithm hashes mod 2^64"
  }

computeOmegaQuot :: [Word64] -> OmegaResult
computeOmegaQuot hashes = OmegaResult
  { orSource = OmegaFromQuot
  , orValue  = sumMod64 hashes
  , orStatus = EmpiricalNumericalResult
  , orNote   = "Omega_quot: sum of per-equivalence-class hashes mod 2^64"
  }

sumMod64 :: [Word64] -> Word64
sumMod64 = foldl' (+) 0   -- Word64 arithmetic wraps mod 2^64 automatically
