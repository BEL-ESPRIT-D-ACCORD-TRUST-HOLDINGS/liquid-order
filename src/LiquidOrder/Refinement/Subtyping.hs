-- LiquidOrder: Refinement subtyping
-- Subtyping is predicate ordering.
-- {x:τ|P} <: {x:τ|Q}  iff  ∀x. P(x) ⇒ Q(x)
-- The obligation is discharged by the dispatcher, not by SMT flat queries.

module LiquidOrder.Refinement.Subtyping
  ( subtypeObligation
  , checkSubtype
  , SubtypeResult(..)
  ) where

import LiquidOrder.IR.Types
import LiquidOrder.Kernel.Kernel (Thm)
import LiquidOrder.Order.OrderTheory (subtypeLeq)
import LiquidOrder.Automation.Dispatch (dispatch, GoalShape(..))

-- ---------------------------------------------------------------------------
-- Subtyping obligation
-- Produces a Goal whose subject is the implication term.
-- ---------------------------------------------------------------------------

subtypeObligation :: Context -> RefinedType -> RefinedType -> Goal
subtypeObligation ctx sub sup =
  let obligationTerm = subtypeLeq sub sup
      resultType = RefinedType
        { baseType   = TConst "Bool"
        , binder     = "_"
        , refinePred = Refinement (Const "True" (TConst "Bool"))
        }
  in Goal
       { context  = ctx
       , subject  = obligationTerm
       , goalType = resultType
       }

-- ---------------------------------------------------------------------------
-- Check subtype: attempt proof of the obligation
-- ---------------------------------------------------------------------------

data SubtypeResult
  = SubtypeHolds Thm
  | SubtypeOpen  String   -- proof obligation returned to user
  | SubtypeFailed String
  deriving (Show)

checkSubtype :: Context -> RefinedType -> RefinedType -> IO SubtypeResult
checkSubtype ctx sub sup = do
  let goal = subtypeObligation ctx sub sup
  result <- dispatch goal
  return $ case result of
    Right thm           -> SubtypeHolds thm
    Left "INTERACTIVE:" -> SubtypeOpen (baseType sub `show'` baseType sup)
    Left msg            -> SubtypeFailed msg

show' :: Type -> Type -> String
show' t1 t2 = show t1 ++ " <: " ++ show t2

instance Show Type where
  show (TVar n)      = n
  show (TConst n)    = n
  show (TFun a b)    = "(" ++ show a ++ " -> " ++ show b ++ ")"
  show (TApp tc as)  = show tc ++ " " ++ unwords (map show as)
