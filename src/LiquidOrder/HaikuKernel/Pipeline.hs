-- Haiku Kernel: Continuation Monad + DAG Pipeline
-- Dagger-style directed acyclic graph with backtracking stack

module LiquidOrder.HaikuKernel.Pipeline
  ( Cont(..)
  , Stage(..)
  , StageType(..)
  , PipelineState(..)
  , executePipelineStage
  , runStage
  , validatePipelineDAG
  , checkpointState
  ) where

import LiquidOrder.HaikuKernel.WorldState (WorldState(..))

-- ---------------------------------------------------------------------------
-- Continuation monad
-- ---------------------------------------------------------------------------

newtype Cont r a = Cont { runCont :: (a -> r) -> r }

instance Functor (Cont r) where
  fmap f m = Cont (\k -> runCont m (k . f))

instance Applicative (Cont r) where
  pure a  = Cont (\k -> k a)
  mf <*> ma = Cont (\k -> runCont mf (\f -> runCont ma (k . f)))

instance Monad (Cont r) where
  return  = pure
  m >>= f = Cont (\c -> runCont m (\a -> runCont (f a) c))

-- ---------------------------------------------------------------------------
-- Pipeline stage
-- ---------------------------------------------------------------------------

data Stage = Stage
  { stageId       :: String
  , stageType     :: StageType
  , stageDeps     :: [String]     -- dependency edges (DAG)
  , stageHasFailed :: Bool
  , stageBacktrack :: Bool
  } deriving (Show, Eq)

data StageType
  = Decompose
  | Verify
  | Synthesize
  | Execute
  | Checkpoint
  deriving (Show, Eq)

-- ---------------------------------------------------------------------------
-- Pipeline state with backtrack stack
-- ---------------------------------------------------------------------------

data PipelineState = PipelineState
  { psStages                :: [Stage]
  , psCompleted             :: [Stage]
  , psBacktrackStack        :: [Stage]
  , psCurrentContinuation   :: Maybe (WorldState -> Cont WorldState WorldState)
  }

-- ---------------------------------------------------------------------------
-- Execute stage with continuation
-- ---------------------------------------------------------------------------

executePipelineStage :: Stage -> WorldState -> Cont WorldState WorldState
executePipelineStage stage ws = Cont $ \k ->
  case runStage stage ws of
    Left _err ->
      if stageBacktrack stage
        then k (ws { wsDecisions = drop 1 (wsDecisions ws) })
        else error ("Unrecoverable stage error in: " ++ stageId stage)
    Right ws' -> k ws'

runStage :: Stage -> WorldState -> Either String WorldState
runStage stage ws =
  case stageType stage of
    Decompose   -> Right ws
    Verify      -> Right ws
    Synthesize  -> Right ws
    Execute     -> Right ws
    Checkpoint  -> checkpointState stage ws

checkpointState :: Stage -> WorldState -> Either String WorldState
checkpointState _ ws = Right ws   -- persist to git in full implementation

-- ---------------------------------------------------------------------------
-- DAG validation (cycle detection)
-- ---------------------------------------------------------------------------

validatePipelineDAG :: [Stage] -> Bool
validatePipelineDAG stages =
  let edges = [ (dep, stageId s) | s <- stages, dep <- stageDeps s ]
  in not (detectCycle edges [])

detectCycle :: [(String, String)] -> [String] -> Bool
detectCycle [] _                     = False
detectCycle ((from, to):edges) visited
  | to `elem` visited                = True
  | otherwise                        = detectCycle edges (from : visited)
