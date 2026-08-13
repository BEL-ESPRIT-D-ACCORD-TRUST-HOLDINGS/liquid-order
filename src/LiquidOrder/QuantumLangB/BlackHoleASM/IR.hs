-- LiquidOrder: QBH-IR — Quantum Black Hole Intermediate Representation
--
-- Source: OpenQASM 3 programs (public, reproducible)
-- NOT: IBM hardware internals, proprietary control stacks
--
-- The IR strips vendor-specific naming and retains only structural semantics.
-- Every node carries only what is needed for:
--   dependency DAG construction
--   entanglement graph construction
--   classical-control graph construction
--   resource lifetime graph
--   invariant extraction
--
-- Cycle types are distinguished:
--   QuantumCycle      — qubit gate execution
--   ClassicalCycle    — classical feed-forward control
--   WaitCycle         — idle (compressible gap)

module LiquidOrder.QuantumLangB.BlackHoleASM.IR
  ( -- Qubit / classical bit identifiers
    QubitId(..)
  , CbitId(..)
  , OpId(..)
    -- Gate types (structural only, no vendor names)
  , GateType(..)
  , CycleType(..)
    -- Operations
  , Op(..)
  , Duration(..)
    -- IR program
  , QBH_IR(..)
  , emptyIR
    -- Dependency edge
  , DepEdge(..)
  , EntangleEdge(..)
    -- Invariant vector I(C)
  , InvariantVector(..)
  , extractInvariants
    -- Cycle compression
  , Schedule(..)
  , CycleStealResult(..)
  ) where

import Data.List (nub, maximumBy)
import Data.Ord (comparing)

-- ---------------------------------------------------------------------------
-- Identifiers (abstract — no vendor-specific naming)
-- ---------------------------------------------------------------------------

newtype QubitId = QubitId Int deriving (Eq, Ord, Show)
newtype CbitId  = CbitId  Int deriving (Eq, Ord, Show)
newtype OpId    = OpId    Int deriving (Eq, Ord, Show)

-- ---------------------------------------------------------------------------
-- Gate types: structural, not named
-- ---------------------------------------------------------------------------

data GateType
  = SingleQubit    -- any 1-qubit unitary (H, X, Z, Rz, etc.)
  | TwoQubit       -- any 2-qubit entangling gate (CNOT, CZ, iSWAP, etc.)
  | NQubit Int     -- n-qubit gate (n >= 3)
  | Barrier        -- synchronization barrier
  | Reset          -- qubit reset to |0>
  | Measure        -- measurement -> classical bit
  | Branch         -- classical conditional control
  | Loop           -- classical loop
  deriving (Eq, Show)

gateArity :: GateType -> Int
gateArity SingleQubit  = 1
gateArity TwoQubit     = 2
gateArity (NQubit n)   = n
gateArity Barrier      = 0  -- affects all qubits in scope
gateArity Reset        = 1
gateArity Measure      = 1
gateArity Branch       = 0  -- classical
gateArity Loop         = 0  -- classical

-- ---------------------------------------------------------------------------
-- Cycle type: distinguishes quantum from classical execution
-- ---------------------------------------------------------------------------

data CycleType
  = QuantumCycle    -- qubit gate execution within coherence window
  | ClassicalCycle  -- classical feed-forward / control
  | WaitCycle       -- idle — potentially compressible
  deriving (Eq, Show)

-- ---------------------------------------------------------------------------
-- Duration: abstract time unit (hardware-independent)
-- ---------------------------------------------------------------------------

newtype Duration = Duration { durationUnits :: Int } deriving (Eq, Ord, Show)

-- ---------------------------------------------------------------------------
-- Single operation in QBH-IR
-- ---------------------------------------------------------------------------

data Op = Op
  { opId        :: OpId
  , opGate      :: GateType
  , opQubits    :: [QubitId]     -- target qubits
  , opCbits     :: [CbitId]      -- classical bits involved (measurements, branches)
  , opDuration  :: Duration
  , opCycleType :: CycleType
  } deriving (Show)

-- ---------------------------------------------------------------------------
-- Dependency edge: o_i precedes o_j in the dependency DAG
-- o_i < o_j  means  s'(o_i) + d(o_i) <= s'(o_j) must hold
-- ---------------------------------------------------------------------------

data DepEdge = DepEdge
  { depFrom :: OpId
  , depTo   :: OpId
  } deriving (Eq, Show)

-- ---------------------------------------------------------------------------
-- Entanglement edge: two qubits became entangled via a TwoQubit gate
-- ---------------------------------------------------------------------------

data EntangleEdge = EntangleEdge
  { entQ1 :: QubitId
  , entQ2 :: QubitId
  , entOp :: OpId
  } deriving (Eq, Show)

-- ---------------------------------------------------------------------------
-- QBH-IR program: the stripped structural representation
-- ---------------------------------------------------------------------------

data QBH_IR = QBH_IR
  { irQubits      :: [QubitId]
  , irCbits       :: [CbitId]
  , irOps         :: [Op]
  , irDepEdges    :: [DepEdge]
  , irEntEdges    :: [EntangleEdge]
  } deriving (Show)

emptyIR :: QBH_IR
emptyIR = QBH_IR [] [] [] [] []

-- ---------------------------------------------------------------------------
-- Invariant vector I(C) = (n_q, n_g, D, E, M, R, B, W, chi, Sigma)
-- ---------------------------------------------------------------------------

data InvariantVector = InvariantVector
  { ivNQ      :: Int      -- n_q: qubit count
  , ivNG      :: Int      -- n_g: total gate count
  , ivD       :: Int      -- D: critical-path circuit depth
  , ivE       :: Int      -- E: two-qubit interaction count
  , ivM       :: Int      -- M: measurement count
  , ivR       :: Int      -- R: reset count
  , ivB       :: Int      -- B: classical branch count
  , ivW       :: Int      -- W: max simultaneous active operations (width)
  , ivChi     :: Int      -- chi: graph complexity statistic
  , ivSigma   :: Double   -- Sigma: shard entropy estimate (log dim H_admissible)
  } deriving (Show)

extractInvariants :: QBH_IR -> InvariantVector
extractInvariants ir =
  let ops   = irOps ir
      nq    = length (irQubits ir)
      ng    = length ops
      e     = length [ o | o <- ops, opGate o == TwoQubit ]
      m     = length [ o | o <- ops, opGate o == Measure ]
      r     = length [ o | o <- ops, opGate o == Reset ]
      b     = length [ o | o <- ops, opGate o == Branch ]

      -- Critical path depth: longest chain in dependency DAG
      d     = criticalPathDepth (irOps ir) (irDepEdges ir)

      -- Width: maximum operations active at any single cycle step
      w     = maxWidth (irOps ir) d

      -- chi = |E_dep| - |V_ops| + 2P  (graph complexity statistic)
      -- P = number of connected components (simplified: 1 for connected graph)
      chi   = length (irDepEdges ir) - ng + 2

      -- Sigma: log of admissible state count (Area-BLIND estimate)
      -- Using entanglement structure as proxy; NOT inserted from BH formula
      sigma = fromIntegral e * log 2.0   -- each entangling gate ~ 1 ebit capacity

  in InvariantVector nq ng d e m r b w chi sigma

criticalPathDepth :: [Op] -> [DepEdge] -> Int
criticalPathDepth ops deps =
  -- Topological order -> longest path
  -- Simplified: sum of durations along longest chain
  let opMap = [ (opId o, durationUnits (opDuration o)) | o <- ops ]
      depMap = [ (depFrom e, depTo e) | e <- deps ]
      -- For each op, compute earliest completion time
      completionTime opId_ =
        let myDur = maybe 1 id (lookup opId_ opMap)
            preds = [ p | (p, t) <- depMap, t == opId_ ]
            predMax = if null preds then 0
                      else maximum (map completionTime preds)
        in predMax + myDur
  in if null ops then 0
     else maximum (map (completionTime . opId) ops)

maxWidth :: [Op] -> Int -> Int
maxWidth ops totalDepth =
  -- Width at each step: count ops whose duration overlaps that step
  -- Simplified estimate using uniform distribution
  if totalDepth == 0 then 0
  else max 1 (length ops `div` max 1 totalDepth)

-- ---------------------------------------------------------------------------
-- Schedule and cycle-stealing compression
-- ---------------------------------------------------------------------------

data Schedule = Schedule
  { schedStart    :: [(OpId, Int)]    -- op -> start time
  , schedDepth    :: Int              -- total circuit depth
  , schedCycles   :: [(Int, CycleType)]  -- cycle -> type
  } deriving (Show)

data CycleStealResult = CycleStealResult
  { csrOriginalDepth :: Int
  , csrCompressedDepth :: Int
  , csrDeltaCycle :: Int          -- Delta_cycle = D_original - D_min
  , csrCycleEfficiency :: Double  -- 1 - WaitCycles/TotalCycles
  , csrSchedule :: Schedule
  } deriving (Show)

-- Compute D_min: minimum depth preserving dependency DAG
-- Constraint: o_i < o_j => s'(o_i) + d(o_i) <= s'(o_j)
cycleStealing :: QBH_IR -> CycleStealResult
cycleStealing ir =
  let ops         = irOps ir
      deps        = irDepEdges ir
      dOriginal   = criticalPathDepth ops deps

      -- ASAP schedule: each op starts as early as allowed by deps
      asapStart op =
        let preds = [ p | DepEdge p t <- deps, t == opId op ]
            predEnds = [ asapEnd p | p <- preds ]
            predMax = if null predEnds then 0 else maximum predEnds
        in predMax
      asapEnd opId_ =
        case filter (\o -> opId o == opId_) ops of
          (o:_) -> asapStart o + durationUnits (opDuration o)
          []    -> 0

      schedStarts = [ (opId o, asapStart o) | o <- ops ]
      dMin        = if null ops then 0
                    else maximum [ s + durationUnits (opDuration o)
                                 | (o, s) <- zip ops (map snd schedStarts) ]

      -- Count wait cycles
      totalCycles  = dMin
      activeCycles = length [ () | (_, s) <- schedStarts
                                 , s < dMin ]
      waitCycles   = max 0 (totalCycles - activeCycles)
      efficiency   = if totalCycles == 0 then 1.0
                     else 1.0 - fromIntegral waitCycles / fromIntegral totalCycles

      sched = Schedule
        { schedStart  = schedStarts
        , schedDepth  = dMin
        , schedCycles = [ (t, QuantumCycle) | t <- [0..dMin-1] ]
        }

  in CycleStealResult
       { csrOriginalDepth   = dOriginal
       , csrCompressedDepth = dMin
       , csrDeltaCycle      = dOriginal - dMin
       , csrCycleEfficiency = efficiency
       , csrSchedule        = sched
       }
