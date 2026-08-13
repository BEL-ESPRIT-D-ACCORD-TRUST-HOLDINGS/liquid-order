-- LiquidOrder: End-to-end verification pipeline
--
-- Full trust chain:
--
--   CovenantSpecification
--       |
--       v
--   HOL Proposition         (HOLFormalization.hs)
--       |
--       v
--   Solver / Tactics        [UNTRUSTED]
--       |
--       v
--   ProofCertificate
--       |
--       v
--   LiquidOrder LCF Kernel  [TRUSTED]
--       |
--       v
--   Thm
--       |
--       v
--   Machine-Checked Manifest
--
-- No Thm exists merely because the solver says "true".
-- ONLY KernelReplay(certificate) = ReplayValid permits status = PROVED.

module LiquidOrder.Pipeline.Pipeline
  ( PipelineInput(..)
  , PipelineOutput(..)
  , PipelineStage(..)
  , runPipeline
  , stageLabel
  ) where

import LiquidOrder.Kernel.Certificate
import LiquidOrder.Epistemic.Types
import LiquidOrder.Manifest.Manifest
import LiquidOrder.SovereignCovenant.Obligations (allObligations, requiredObligations)

-- ---------------------------------------------------------------------------
-- Pipeline stages (ordered; each feeds the next)
-- ---------------------------------------------------------------------------

data PipelineStage
  = StageSpec          -- Sovereign-Covenant specification loaded
  | StageHOL           -- HOL propositions generated from spec
  | StageSolverSearch  -- Solver dispatched per obligation [UNTRUSTED]
  | StageCertificate   -- Proof certificates received from solver
  | StageKernelReplay  -- Kernel replays each certificate [TRUSTED]
  | StageManifest      -- Manifest assembled from replay results
  | StageTrack3        -- Track 3 numerical test (AFTER all prior stages)
  deriving (Eq, Ord, Show, Enum, Bounded)

stageLabel :: PipelineStage -> String
stageLabel StageSpec         = "SPEC_LOADED"
stageLabel StageHOL          = "HOL_PROPOSITIONS_GENERATED"
stageLabel StageSolverSearch = "SOLVER_SEARCH_COMPLETE [UNTRUSTED]"
stageLabel StageCertificate  = "CERTIFICATES_RECEIVED"
stageLabel StageKernelReplay = "KERNEL_REPLAY_COMPLETE [TRUSTED]"
stageLabel StageManifest     = "MANIFEST_ASSEMBLED"
stageLabel StageTrack3       = "TRACK3_NUMERICAL_BLIND"

-- ---------------------------------------------------------------------------
-- Pipeline input: certificates the solver has produced (may be empty)
-- ---------------------------------------------------------------------------

data PipelineInput = PipelineInput
  { piCertificates  :: [(String, ProofCertificate)]
    -- ^ theorem ID -> certificate (solver output, untrusted)
  , piRunTrack3     :: Bool
    -- ^ True only if all prior stages completed and user requests blind test
  } deriving (Show)

-- ---------------------------------------------------------------------------
-- Pipeline output
-- ---------------------------------------------------------------------------

data PipelineOutput = PipelineOutput
  { poStageReached  :: PipelineStage
  , poManifest      :: Maybe Manifest
  , poManifestText  :: String
  , poManifestJSON  :: String
  , poBuildOk       :: Bool
  , poErrors        :: [String]
  , poTrack3Result  :: Maybe String  -- "NOT_RUN", numerical result, or "EMPIRICAL_NUMERICAL_RESULT"
  } deriving (Show)

-- ---------------------------------------------------------------------------
-- Run the full pipeline
-- ---------------------------------------------------------------------------

runPipeline :: PipelineInput -> PipelineOutput
runPipeline input =
  let
    -- Stage 1-4: spec + HOL are always available (static declarations)
    -- Stage 5: kernel replay on all provided certificates
    manifest      = buildManifest (piCertificates input)
    buildResult   = checkBuildConstraints manifest
    buildOk       = case buildResult of { Right () -> True; Left _ -> False }
    errors        = case buildResult of { Right () -> []; Left es -> es }

    -- Stage 6: assemble manifest
    manifestText  = renderManifestText manifest
    manifestJson  = renderManifestJSON manifest

    -- Stage 7: Track 3 — ONLY if all prior stages pass and explicitly requested
    track3Result
      | not (piRunTrack3 input) = Just "NOT_RUN: Track 3 requires explicit invocation after prior stages complete"
      | not buildOk             = Just "NOT_RUN: Track 3 blocked — required theorems unproved"
      | otherwise               = Just "EMPIRICAL_NUMERICAL_RESULT: run impl/omega_extract.py"

  in PipelineOutput
       { poStageReached  = if buildOk then StageTrack3 else StageManifest
       , poManifest      = Just manifest
       , poManifestText  = manifestText
       , poManifestJSON  = manifestJson
       , poBuildOk       = buildOk
       , poErrors        = errors
       , poTrack3Result  = track3Result
       }
