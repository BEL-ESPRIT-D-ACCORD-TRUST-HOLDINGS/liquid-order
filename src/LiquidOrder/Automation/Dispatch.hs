-- LiquidOrder: Proof-producing automation dispatcher
-- SMT is a subordinate backend, not the trust source.
-- Every solver must produce a proof certificate; the kernel validates it.
--
-- Dispatch hierarchy (in order):
--   1. βη normalization
--   2. Rewrite engine
--   3. Higher-order pattern matching (Miller)
--   4. Arithmetic decision procedure (proof-producing)
--   5. Order/lattice solver
--   6. Fixpoint/induction rule
--   7. Interactive tactic / bounded HO search

module LiquidOrder.Automation.Dispatch
  ( GoalShape(..)
  , classifyGoal
  , dispatch
  ) where

import LiquidOrder.IR.Types
import LiquidOrder.Kernel.Kernel (Thm)

-- ---------------------------------------------------------------------------
-- Goal shape classification
-- ---------------------------------------------------------------------------

data GoalShape
  = BetaEta              -- reducible by βη
  | RewriteTarget        -- matches a known rewrite theorem
  | HOPattern            -- higher-order pattern (Miller matching applicable)
  | ArithFragment        -- linear/polynomial arithmetic fragment
  | OrderGoal            -- lattice / order predicate
  | RecursiveGoal        -- requires induction or fixpoint rule
  | Interactive          -- none of the above; requires user tactic
  deriving (Eq, Show)

-- ---------------------------------------------------------------------------
-- Classify a goal without solving it
-- ---------------------------------------------------------------------------

classifyGoal :: Goal -> GoalShape
classifyGoal goal =
  let t = subject goal
  in if isBetaRedex t        then BetaEta
     else if isArith t       then ArithFragment
     else if isOrderPred t   then OrderGoal
     else if isRecursive t   then RecursiveGoal
     else if isHOPattern t   then HOPattern
     else                         Interactive

-- ---------------------------------------------------------------------------
-- Dispatch to the appropriate proof-producing backend
-- ---------------------------------------------------------------------------

dispatch :: Goal -> IO (Either String Thm)
dispatch goal = case classifyGoal goal of
  BetaEta       -> return $ normalizeBeta goal
  ArithFragment -> proveArith goal
  OrderGoal     -> proveOrder goal
  RecursiveGoal -> proveFixpoint goal
  HOPattern     -> proveHOMatch goal
  RewriteTarget -> proveRewrite goal
  Interactive   -> return $ Left "INTERACTIVE: no automatic proof found"

-- ---------------------------------------------------------------------------
-- Stub backends (replace with proof-producing implementations)
-- ---------------------------------------------------------------------------

normalizeBeta :: Goal -> Either String Thm
normalizeBeta _ = Left "normalizeBeta: stub"

proveArith :: Goal -> IO (Either String Thm)
proveArith _ = return $ Left "proveArith: stub — attach proof-producing arithmetic solver"

proveOrder :: Goal -> IO (Either String Thm)
proveOrder _ = return $ Left "proveOrder: stub — attach order solver"

proveFixpoint :: Goal -> IO (Either String Thm)
proveFixpoint _ = return $ Left "proveFixpoint: stub — attach fixpoint induction rule"

proveHOMatch :: Goal -> IO (Either String Thm)
proveHOMatch _ = return $ Left "proveHOMatch: stub — attach Miller pattern unifier"

proveRewrite :: Goal -> IO (Either String Thm)
proveRewrite _ = return $ Left "proveRewrite: stub — attach rewrite engine"

-- ---------------------------------------------------------------------------
-- Shape detection helpers (structural, no evaluation)
-- ---------------------------------------------------------------------------

isBetaRedex :: Term -> Bool
isBetaRedex (App (Lam _ _ _) _) = True
isBetaRedex _                   = False

isArith :: Term -> Bool
isArith (App (App (Const op _) _) _)
  | op `elem` ["+", "-", "*", "<", "<=", ">", ">="] = True
isArith _ = False

isOrderPred :: Term -> Bool
isOrderPred (App (App (Const "leq" _) _) _) = True
isOrderPred _ = False

isRecursive :: Term -> Bool
isRecursive (App (Const "fix" _) _) = True
isRecursive _ = False

isHOPattern :: Term -> Bool
isHOPattern (App (Const "!" _) (Lam _ _ _)) = True
isHOPattern _ = False
