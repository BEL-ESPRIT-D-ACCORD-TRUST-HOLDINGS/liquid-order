-- LiquidOrder IR: Minimal term and refinement IR
-- Proposition = Term of type Bool (no separate proposition AST)
-- Refinements are HOL terms, not SMT formulas.

module LiquidOrder.IR.Types
  ( Type(..)
  , Term(..)
  , Refinement(..)
  , RefinedType(..)
  , Context(..)
  , Goal(..)
  , Name
  ) where

type Name = String

-- ---------------------------------------------------------------------------
-- Type language (same as kernel)
-- ---------------------------------------------------------------------------

data Type
  = TVar  Name
  | TConst Name
  | TFun  Type Type
  | TApp  Type [Type]
  deriving (Eq, Ord, Show)

-- ---------------------------------------------------------------------------
-- Term language
-- Propositions are terms of type Bool.
-- ---------------------------------------------------------------------------

data Term
  = Var   Name Type
  | Const Name Type
  | App   Term Term
  | Lam   Name Type Term
  deriving (Eq, Ord, Show)

-- ---------------------------------------------------------------------------
-- Refinement
-- A predicate P : τ → Bool applied as a type constraint.
-- ---------------------------------------------------------------------------

newtype Refinement = Refinement { predicate :: Term }
  deriving (Eq, Show)

-- Refined type: {x : τ | P(x)}
data RefinedType = RefinedType
  { baseType    :: Type
  , binder      :: Name
  , refinePred  :: Refinement
  }
  deriving (Eq, Show)

-- ---------------------------------------------------------------------------
-- Typing context and proof goal
-- ---------------------------------------------------------------------------

data Context = Context
  { typeEnv  :: [(Name, Type)]          -- variable types
  , factEnv  :: [Term]                  -- proven higher-order facts (Bool terms)
  }
  deriving (Show)

data Goal = Goal
  { context :: Context
  , subject :: Term
  , goalType :: RefinedType
  }
  deriving (Show)
