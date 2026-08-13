-- LiquidOrder: LCF-style trusted kernel
-- No public Thm constructor. All proofs must reduce to these rules.
-- Automation ≠ Trust. Thm = trust boundary.

module LiquidOrder.Kernel
  ( -- Types (opaque)
    Type(..)
  , Term(..)
  , Thm
    -- Kernel rules (all producers of Thm)
  , assume
  , refl
  , beta
  , absCong
  , appCong
  , eqMp
  , deduct
  , inst
  , typeInst
    -- Inspection (read-only)
  , conclusion
  , hypotheses
  ) where

-- ---------------------------------------------------------------------------
-- Type language
-- ---------------------------------------------------------------------------

data Type
  = TVar  Name
  | TConst Name
  | TFun  Type Type
  | TApp  Type [Type]
  deriving (Eq, Ord)

type Name = String

-- ---------------------------------------------------------------------------
-- Term language
-- Proposition φ is just a Term of type Bool.
-- No separate logical datatype.
-- ---------------------------------------------------------------------------

data Term
  = Var   Name Type
  | Const Name Type
  | App   Term Term
  | Lam   Name Type Term
  deriving (Eq, Ord)

-- ---------------------------------------------------------------------------
-- Theorem (abstract — constructor unexported)
-- ---------------------------------------------------------------------------

data Thm = Thm
  { hypotheses :: [Term]   -- set of assumptions (terms of type Bool)
  , conclusion :: Term     -- conclusion (term of type Bool)
  }

-- Thm is not exported via constructor.
-- Only the kernel rules below can produce values of type Thm.

-- ---------------------------------------------------------------------------
-- Primitive logic constants (typed)
-- These are the logical vocabulary; no separate AST for propositions.
-- ---------------------------------------------------------------------------

_eq :: Type -> Term
_eq t = Const "=" (TFun t (TFun t boolT))

_imp :: Term
_imp = Const "==>" (TFun boolT (TFun boolT boolT))

_forall :: Type -> Term
_forall t = Const "!" (TFun (TFun t boolT) boolT)

_leq :: Type -> Term
_leq t = Const "leq" (TFun t (TFun t boolT))

_fix :: Type -> Term
_fix t = Const "fix" (TFun (TFun t t) t)

boolT :: Type
boolT = TConst "Bool"

-- ---------------------------------------------------------------------------
-- Kernel rules
-- ---------------------------------------------------------------------------

-- ASSUME: Γ∪{φ} ⊢ φ
assume :: Term -> Thm
assume phi = Thm { hypotheses = [phi], conclusion = phi }

-- REFL: ⊢ t = t
refl :: Term -> Thm
refl t =
  let ty = typeOf t
  in Thm { hypotheses = [], conclusion = App (App (_eq ty) t) t }

-- BETA: ⊢ (λx:τ.t) s = t[x:=s]
beta :: Name -> Type -> Term -> Term -> Thm
beta x tau body s =
  let lhs = App (Lam x tau body) s
      rhs = subst x s body
      ty  = typeOf rhs
  in Thm { hypotheses = [], conclusion = App (App (_eq ty) lhs) rhs }

-- ABSCONG: Γ ⊢ t = t'  =>  Γ ⊢ (λx.t) = (λx.t')
absCong :: Name -> Type -> Thm -> Thm
absCong x tau thm =
  case conclusion thm of
    App (App eq t) t' ->
      let lhs = Lam x tau t
          rhs = Lam x tau t'
          ty  = TFun tau (typeOf t)
      in Thm
           { hypotheses = hypotheses thm
           , conclusion  = App (App (_eq ty) lhs) rhs
           }
    _ -> error "absCong: conclusion is not an equality"

-- APPCONG: Γ ⊢ f = f'  Δ ⊢ x = x'  =>  Γ∪Δ ⊢ f x = f' x'
appCong :: Thm -> Thm -> Thm
appCong fThm xThm =
  case (conclusion fThm, conclusion xThm) of
    (App (App _ f) f', App (App _ x) x') ->
      let result = App f x
          result' = App f' x'
          ty = typeOf result
      in Thm
           { hypotheses = hypotheses fThm ++ hypotheses xThm
           , conclusion  = App (App (_eq ty) result) result'
           }
    _ -> error "appCong: conclusions are not equalities"

-- EQMP: Γ ⊢ φ = ψ  Δ ⊢ φ  =>  Γ∪Δ ⊢ ψ
eqMp :: Thm -> Thm -> Thm
eqMp eqThm phiThm =
  case conclusion eqThm of
    App (App _ phi) psi
      | phi == conclusion phiThm ->
          Thm
            { hypotheses = hypotheses eqThm ++ hypotheses phiThm
            , conclusion  = psi
            }
    _ -> error "eqMp: mismatch"

-- DEDUCT: Γ∪{ψ} ⊢ φ  Δ∪{φ} ⊢ ψ  =>  (Γ∪Δ) ⊢ φ = ψ
deduct :: Thm -> Thm -> Thm
deduct t1 t2 =
  let phi = conclusion t1
      psi = conclusion t2
      hyps = filter (/= psi) (hypotheses t1)
           ++ filter (/= phi) (hypotheses t2)
  in Thm
       { hypotheses = hyps
       , conclusion  = App (App (_eq boolT) phi) psi
       }

-- INST: Γ ⊢ φ  =>  Γ[θ] ⊢ φ[θ]   (term variable substitution)
inst :: [(Name, Term)] -> Thm -> Thm
inst theta thm = Thm
  { hypotheses = map (substMany theta) (hypotheses thm)
  , conclusion  = substMany theta (conclusion thm)
  }

-- TYPEINST: Γ ⊢ φ  =>  Γ[σ] ⊢ φ[σ]   (type variable substitution)
typeInst :: [(Name, Type)] -> Thm -> Thm
typeInst sigma thm = Thm
  { hypotheses = map (typeSubst sigma) (hypotheses thm)
  , conclusion  = typeSubst sigma (conclusion thm)
  }

-- ---------------------------------------------------------------------------
-- Helpers (private to module)
-- ---------------------------------------------------------------------------

typeOf :: Term -> Type
typeOf (Var _ t)     = t
typeOf (Const _ t)   = t
typeOf (App f _)     = case typeOf f of
                         TFun _ b -> b
                         _        -> error "typeOf: ill-typed application"
typeOf (Lam _ t b)   = TFun t (typeOf b)

subst :: Name -> Term -> Term -> Term
subst x s (Var y _)    | x == y    = s
subst _ _ v@(Var _ _)              = v
subst _ _ c@(Const _ _)            = c
subst x s (App f a)                = App (subst x s f) (subst x s a)
subst x s (Lam y t b) | x /= y    = Lam y t (subst x s b)
subst _ _ lam                      = lam  -- bound variable shadows

substMany :: [(Name, Term)] -> Term -> Term
substMany []          t = t
substMany ((x,s):rest) t = substMany rest (subst x s t)

typeSubst :: [(Name, Type)] -> Term -> Term
typeSubst sigma t = case t of
  Var n ty    -> Var n (tsubst sigma ty)
  Const n ty  -> Const n (tsubst sigma ty)
  App f a     -> App (typeSubst sigma f) (typeSubst sigma a)
  Lam n ty b  -> Lam n (tsubst sigma ty) (typeSubst sigma b)

tsubst :: [(Name, Type)] -> Type -> Type
tsubst sigma ty = case ty of
  TVar n      -> case lookup n sigma of Just t' -> t'; Nothing -> TVar n
  TConst n    -> TConst n
  TFun a b    -> TFun (tsubst sigma a) (tsubst sigma b)
  TApp tc args -> TApp (tsubst sigma tc) (map (tsubst sigma) args)
