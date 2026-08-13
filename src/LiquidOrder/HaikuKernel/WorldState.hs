-- Haiku Learning Kernel: World State + Agent Memory
-- Foundation: Curry language semantics, continuation monad, SMT-Lib2
-- Provenance: SnapKitty Sovereign Systems

module LiquidOrder.HaikuKernel.WorldState
  ( WorldState(..)
  , Decision(..)
  , DecisionType(..)
  , AgentMemory(..)
  , PerformanceMetrics(..)
  , Constraint(..)
  , ConstraintType(..)
  , initializeKernel
  , initializeAgentMemory
  , initializeMetrics
  , updateAgentMemory
  , updateSuccessRate
  , calculateGradient
  , backtrackToDecision
  , verifyCausality
  ) where

import Data.List (sortBy)
import Data.Time (UTCTime, getCurrentTime)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M

-- ---------------------------------------------------------------------------
-- World State (AST representation)
-- ---------------------------------------------------------------------------

data WorldState = WorldState
  { wsVersion     :: Int
  , wsTimestamp   :: UTCTime
  , wsDecisions   :: [Decision]
  , wsAgentMem    :: AgentMemory
  , wsConstraints :: [Constraint]
  , wsMetrics     :: PerformanceMetrics
  } deriving (Show, Eq)

data Decision = Decision
  { decId        :: String
  , decType      :: DecisionType
  , decTimestamp :: UTCTime
  , decAgent     :: String        -- "haiku3" | "haiku4"
  , decInput     :: String
  , decOutput    :: String
  , decSuccess   :: Bool
  , decLatency   :: Int           -- ms
  , decTokens    :: Int
  } deriving (Show, Eq, Ord)

data DecisionType
  = Routing
  | Verification
  | Coordination
  | Learning
  deriving (Show, Eq, Ord)

-- ---------------------------------------------------------------------------
-- Agent Memory (adaptive, time-indexed)
-- ---------------------------------------------------------------------------

data AgentMemory = AgentMemory
  { amDecisions        :: Map String [Decision]  -- agent -> decisions
  , amSuccessRate      :: Map String Double       -- agent -> win rate
  , amLatencyTrend     :: Map String [Int]        -- agent -> [latencies]
  , amLastUsed         :: Map String UTCTime
  , amLearningGradient :: Map String Double       -- agent -> improvement rate
  } deriving (Show, Eq)

-- ---------------------------------------------------------------------------
-- Performance Metrics
-- ---------------------------------------------------------------------------

data PerformanceMetrics = PerformanceMetrics
  { pmTotalDecisions      :: Int
  , pmSuccessfulDecisions :: Int
  , pmAverageLatency      :: Double
  , pmContextWindowUsage  :: (Int, Int)  -- (used, total)
  , pmConstraintViolations :: Int
  , pmToolInvocations     :: Int
  } deriving (Show, Eq)

-- ---------------------------------------------------------------------------
-- Constraints
-- ---------------------------------------------------------------------------

data Constraint = Constraint
  { cName       :: String
  , cType       :: ConstraintType
  , cPredicate  :: String         -- SMT-Lib2 formula
  , cViolations :: Int
  } deriving (Show, Eq)

data ConstraintType = Forbidden | Required | Invariant
  deriving (Show, Eq)

-- ---------------------------------------------------------------------------
-- Initialization
-- ---------------------------------------------------------------------------

initializeKernel :: IO WorldState
initializeKernel = do
  now <- getCurrentTime
  pure $ WorldState
    { wsVersion     = 1
    , wsTimestamp   = now
    , wsDecisions   = []
    , wsAgentMem    = initializeAgentMemory
    , wsConstraints = []
    , wsMetrics     = initializeMetrics
    }

initializeAgentMemory :: AgentMemory
initializeAgentMemory = AgentMemory
  { amDecisions        = M.fromList [("haiku3", []), ("haiku4", [])]
  , amSuccessRate      = M.fromList [("haiku3", 0.5), ("haiku4", 0.5)]
  , amLatencyTrend     = M.fromList [("haiku3", []), ("haiku4", [])]
  , amLastUsed         = M.empty
  , amLearningGradient = M.fromList [("haiku3", 0.0), ("haiku4", 0.0)]
  }

initializeMetrics :: PerformanceMetrics
initializeMetrics = PerformanceMetrics
  { pmTotalDecisions       = 0
  , pmSuccessfulDecisions  = 0
  , pmAverageLatency       = 0.0
  , pmContextWindowUsage   = (0, 200000)
  , pmConstraintViolations = 0
  , pmToolInvocations      = 0
  }

-- ---------------------------------------------------------------------------
-- Adaptive learning: update agent memory on decision outcome
-- ---------------------------------------------------------------------------

updateAgentMemory :: AgentMemory -> Decision -> AgentMemory
updateAgentMemory mem dec =
  let agent           = decAgent dec
      oldRate         = M.findWithDefault 0.5 agent (amSuccessRate mem)
      newRate         = updateSuccessRate oldRate dec
      oldLatencies    = M.findWithDefault [] agent (amLatencyTrend mem)
      newLatencies    = take 100 (decLatency dec : oldLatencies)
      gradient        = calculateGradient oldLatencies newLatencies
  in mem
    { amSuccessRate      = M.insert agent newRate       (amSuccessRate mem)
    , amLatencyTrend     = M.insert agent newLatencies  (amLatencyTrend mem)
    , amLearningGradient = M.insert agent gradient      (amLearningGradient mem)
    }

-- Exponential moving average (alpha = 0.2)
updateSuccessRate :: Double -> Decision -> Double
updateSuccessRate oldRate dec =
  let alpha   = 0.2
      outcome = if decSuccess dec then 1.0 else 0.0
  in oldRate * (1 - alpha) + outcome * alpha

-- Improvement rate: positive = latency decreasing (improving)
calculateGradient :: [Int] -> [Int] -> Double
calculateGradient [] _  = 0.0
calculateGradient _  [] = 0.0
calculateGradient old new =
  let avg xs = fromIntegral (sum xs) / fromIntegral (length xs)
      oldAvg  = avg old
      newAvg  = avg new
  in (oldAvg - newAvg) / max 1.0 oldAvg

-- ---------------------------------------------------------------------------
-- Prolog-style backtracking through decision history
-- ---------------------------------------------------------------------------

backtrackToDecision :: WorldState -> String -> Maybe WorldState
backtrackToDecision ws targetId =
  let decs = wsDecisions ws
      idx  = length decs - length (dropWhile (\d -> decId d /= targetId) decs)
  in if idx <= 0 || idx > length decs
     then Nothing
     else Just ws { wsDecisions = take idx decs }

-- ---------------------------------------------------------------------------
-- Temporal causality: decisions must respect timestamp ordering
-- ---------------------------------------------------------------------------

verifyCausality :: WorldState -> Bool
verifyCausality ws =
  let ts = map decTimestamp (wsDecisions ws)
  in ts == sortBy compare ts
