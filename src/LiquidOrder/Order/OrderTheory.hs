-- LiquidOrder: Order-theoretic primitives
-- Order structure is first-class, not a side theory.
-- Subtyping = predicate ordering. Recursion = fixed-point reasoning.

module LiquidOrder.Order.OrderTheory
  ( -- Predicate ordering (subtyping)
    predicateLeq
  , subtypeLeq
    -- Fixpoint
  , lfpApprox
    -- Contracts as higher-order refinements
  , monotoneContract
  , invariantContract
  , idempotentContract
  , preservesContract
  ) where

import LiquidOrder.IR.Types

-- ---------------------------------------------------------------------------
-- Predicate ordering
-- P ≤ Q  iff  ∀x. P(x) ⇒ Q(x)
-- ---------------------------------------------------------------------------

-- Build the HOL term: ∀x:τ. P(x) ⇒ Q(x)
predicateLeq :: Type -> Refinement -> Refinement -> Term
predicateLeq tau p q =
  let x    = Var "x" tau
      px   = App (predicate p) x
      qx   = App (predicate q) x
      body = App (App imp px) qx
  in App (forallConst tau) (Lam "x" tau body)

-- Subtype inclusion: {x:τ|P} <: {x:τ|Q}  iff  P ≤ Q
subtypeLeq :: RefinedType -> RefinedType -> Term
subtypeLeq rt1 rt2 =
  predicateLeq (baseType rt1) (refinePred rt1) (refinePred rt2)

-- ---------------------------------------------------------------------------
-- Fixed-point approximation
-- fix(F) = lub { F^n(⊥) | n ≥ 0 }
-- Represented as ascending chain of HOL terms.
-- ---------------------------------------------------------------------------

-- Iterate F n times from bottom (represented symbolically)
lfpApprox :: Term -> Term -> Int -> Term
lfpApprox _bottom f 0 = _bottom
lfpApprox bot f n     = App f (lfpApprox bot f (n - 1))

-- ---------------------------------------------------------------------------
-- Contracts as higher-order refinements
-- These are HOL terms — not special compiler annotations.
-- ---------------------------------------------------------------------------

-- Monotone(f) := ∀x y. x ≤ y ⇒ f(x) ≤ f(y)
monotoneContract :: Type -> Term -> Term
monotoneContract tau f =
  let x   = Var "x" tau
      y   = Var "y" tau
      leq = leqConst tau
      body =
        App (App imp (App (App leq x) y))
            (App (App leq (App f x)) (App f y))
      inner = App (forallConst tau) (Lam "y" tau body)
  in App (forallConst tau) (Lam "x" tau inner)

-- Invariant(P, f) := ∀x. P(x) ⇒ P(f(x))
invariantContract :: Type -> Refinement -> Term -> Term
invariantContract tau p f =
  let x    = Var "x" tau
      px   = App (predicate p) x
      pfx  = App (predicate p) (App f x)
      body = App (App imp px) pfx
  in App (forallConst tau) (Lam "x" tau body)

-- Idempotent(f) := ∀x. f(f(x)) = f(x)
idempotentContract :: Type -> Term -> Term
idempotentContract tau f =
  let x    = Var "x" tau
      ffx  = App f (App f x)
      fx   = App f x
      body = App (App (eqConst tau) ffx) fx
  in App (forallConst tau) (Lam "x" tau body)

-- Preserves(f, P) := ∀x. P(x) ⇒ P(f(x))
preservesContract :: Type -> Term -> Refinement -> Term
preservesContract = invariantContract

-- ---------------------------------------------------------------------------
-- Typed constants (mirrors kernel vocabulary)
-- ---------------------------------------------------------------------------

boolT :: Type
boolT = TConst "Bool"

imp :: Term
imp = Const "==>" (TFun boolT (TFun boolT boolT))

eqConst :: Type -> Term
eqConst t = Const "=" (TFun t (TFun t boolT))

leqConst :: Type -> Term
leqConst t = Const "leq" (TFun t (TFun t boolT))

forallConst :: Type -> Term
forallConst t = Const "!" (TFun (TFun t boolT) boolT)
