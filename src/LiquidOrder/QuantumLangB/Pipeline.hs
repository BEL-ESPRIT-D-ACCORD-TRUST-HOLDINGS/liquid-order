-- LiquidOrder: Quantum Language B — Full research pipeline
--
-- Four strictly separated layers. None may masquerade as another.
--
--   Layer 1: Quantum execution    Q# -> QIR -> Simulator/Target
--   Layer 2: Classical witness    Witness extraction from Layer 1 output
--   Layer 3: Formal verification  LiquidOrder HOL proofs + STARK
--   Layer 4: Immutable evidence   Tcl control -> MUMPS WORM
--
-- AREA-BLINDNESS invariant (mandatory):
--   No rule in E, C_t, or R may contain A/(4*lP^2)
--   or any equivalent area-counting constant.
--   If the system independently produces log(dim(H_phys)) ~ c*A
--   and c -> 1/(4*lP^2), that is the finding.
--   Inserting the target makes the experiment circular.
--
-- Macrobit definition (precise):
--   M = (L, E, R)
--   L = logical quantum degree of freedom
--   E : H_L -> tensor(H_S1, ..., H_Sn)  encoding into physical shards
--   R = set of shard collections that can reconstruct M
--
-- Cycle stealing (precise):
--   C_t : (S1,...,Sn) -> (S'1,...,S'n)
--   C_t† C_t = I  (unitary, no-cloning preserved)
--   I_L(t+1) = I_L(t)  (logical information conserved)
--   R_t(M, Sa) = 1, R_{t+1}(M, Sa) = 0, R_{t+1}(M, Sb) = 1
--   = recoverability migrates; information does not copy

module LiquidOrder.QuantumLangB.Pipeline
  ( PipelineLayer(..)
  , AreaBlindnessCheck(..)
  , CycleStealEvent(..)
  , MacrobitDef(..)
  , checkAreaBlindness
  , logicalInformationConserved
  , recoverabilityMigrated
  , centralExperimentTarget
  ) where

import LiquidOrder.QuantumLangB.Types

-- ---------------------------------------------------------------------------
-- Four-layer stack (strict separation)
-- ---------------------------------------------------------------------------

data PipelineLayer
  = LayerQuantum        -- Q# execution -> QIR -> Simulator or quantum target
  | LayerWitness        -- Classical witness extraction (NOT a proof)
  | LayerFormalProof    -- LiquidOrder HOL + STARK (proofs of formal properties)
  | LayerWORM           -- Tcl/MUMPS immutable evidence commitment
  deriving (Eq, Ord, Show, Enum, Bounded)

layerLabel :: PipelineLayer -> String
layerLabel LayerQuantum    = "Q# -> QIR -> Quantum Execution"
layerLabel LayerWitness    = "Classical Witness Extraction"
layerLabel LayerFormalProof = "LiquidOrder HOL + STARK Verification"
layerLabel LayerWORM       = "Tcl -> MUMPS WORM Commitment"

-- What each layer CAN and CANNOT claim
layerCanClaim :: PipelineLayer -> [String]
layerCanClaim LayerQuantum     = ["quantum circuit executed", "measurement outcome sampled"]
layerCanClaim LayerWitness     = ["classical trace of execution", "extracted observable value"]
layerCanClaim LayerFormalProof = ["HOL theorem proved via kernel replay", "STARK proof valid"]
layerCanClaim LayerWORM        = ["record committed", "chain integrity verified"]

layerCannotClaim :: PipelineLayer -> [String]
layerCannotClaim LayerQuantum     = ["theorem proved", "physics derived", "H=0 entropy"]
layerCannotClaim LayerWitness     = ["STARK proof", "formal theorem", "physics result"]
layerCannotClaim LayerFormalProof = ["quantum state executed", "physical measurement"]
layerCannotClaim LayerWORM        = ["quantum result", "formal proof"]

-- ---------------------------------------------------------------------------
-- AREA-BLINDNESS invariant
-- ---------------------------------------------------------------------------

data AreaBlindnessCheck = AreaBlindnessCheck
  { abcRuleName    :: String
  , abcContainsArea :: Bool   -- True = VIOLATION
  , abcNote        :: String
  } deriving (Show)

checkAreaBlindness :: [(String, Bool)] -> [AreaBlindnessCheck]
checkAreaBlindness rules =
  [ AreaBlindnessCheck
      { abcRuleName     = name
      , abcContainsArea = hasArea
      , abcNote = if hasArea
                  then "AREA-BLINDNESS VIOLATION: remove A/(4*lP^2) from this rule"
                  else "OK"
      }
  | (name, hasArea) <- rules
  ]

areaBlindnessPasses :: [AreaBlindnessCheck] -> Bool
areaBlindnessPasses = all (not . abcContainsArea)

-- ---------------------------------------------------------------------------
-- Macrobit: precise three-component definition
-- ---------------------------------------------------------------------------

data MacrobitDef = MacrobitDef
  { mdbLogical    :: LogicalQubit        -- L: logical degree of freedom
  , mdbEncoding   :: EncodingMap         -- E: H_L -> tensor(H_S1..H_Sn)
  , mdbRecovery   :: [(ShardSet, Bool)]  -- R: which shard sets can reconstruct
  } deriving (Show)

-- Verify E is an isometry (necessary condition)
macrobitValid :: MacrobitDef -> Bool
macrobitValid m = isIsometry (mdbEncoding m)

-- ---------------------------------------------------------------------------
-- Cycle stealing: precise definition
-- Recoverability migrates; information is not copied.
-- ---------------------------------------------------------------------------

data CycleStealEvent = CycleStealEvent
  { cseMacrobit     :: MacrobitDef
  , cseFromShard    :: ShardSet       -- Sa: had recoverability at t
  , cseToShard      :: ShardSet       -- Sb: has recoverability at t+1
  , cseTimeStep     :: Time
  , cseUnitary      :: Bool           -- C_t† C_t = I confirmed
  , cseInfoConserved :: Bool          -- I_L(t+1) = I_L(t) confirmed
  } deriving (Show)

-- Verify the migration event is valid
cycleStealValid :: CycleStealEvent -> Bool
cycleStealValid e = cseUnitary e && cseInfoConserved e

-- Machine-checkable recoverability migration:
-- R_t(M, Sa) = 1, R_{t+1}(M, Sa) = 0, R_{t+1}(M, Sb) = 1
recoverabilityMigrated :: MacrobitDef -> ShardSet -> ShardSet -> Bool -> Bool -> Bool -> Bool
recoverabilityMigrated _m _sa _sb rAtSa rAtSaNext rAtSbNext =
  rAtSa          -- before: Sa can recover M
  && not rAtSaNext  -- after: Sa cannot recover M
  && rAtSbNext   -- after: Sb can recover M

-- ---------------------------------------------------------------------------
-- Logical information conservation invariant
-- ---------------------------------------------------------------------------

logicalInformationConserved :: [Recoverability] -> Bool
logicalInformationConserved = all recoverabilityConserved

-- ---------------------------------------------------------------------------
-- Physical Hilbert space after constraints
-- H_phys = { |psi> in H_bulk : C_j |psi> = 0 for all j }
-- ---------------------------------------------------------------------------

data PhysicalHilbertSpace = PhysicalHilbertSpace
  { phsBulkDim       :: Integer    -- dim(H_bulk) before constraints
  , phsConstraintCount :: Int      -- number of constraint equations C_j
  , phsPhysDim       :: Integer    -- dim(H_phys) after constraints (to be computed)
  , phsAreaBlind     :: Bool       -- True if no area constant used in derivation
  } deriving (Show)

-- The counting: S_model = log(dim(H_phys))
-- Target (not assumption): S_model -> A / (4 * lP^2)
modelEntropy :: PhysicalHilbertSpace -> Double
modelEntropy phs = log (fromIntegral (phsPhysDim phs))

-- ---------------------------------------------------------------------------
-- Central experiment target
-- Stated as a check function, not as an axiom.
-- Returns True if the model's entropy matches BH to given tolerance.
-- area is in Planck units (A / lP^2).
-- ---------------------------------------------------------------------------

centralExperimentTarget :: PhysicalHilbertSpace -> Double -> Double -> Bool
centralExperimentTarget phs area tolerance =
  let sModel  = modelEntropy phs
      sBH     = area / 4.0   -- S_BH = A / (4 * lP^2) in natural units
      matches = abs (sModel - sBH) <= tolerance
  in phsAreaBlind phs && matches
     -- phsAreaBlind MUST be True; a match without it is circular
