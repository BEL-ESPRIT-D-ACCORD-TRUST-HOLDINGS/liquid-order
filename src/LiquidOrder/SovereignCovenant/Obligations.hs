-- LiquidOrder: Theorem obligation registry
--
-- Canonical registry of all 10 required theorems.
-- The build fails if any trRequired=True entry lacks status=Proved.
--
-- Each entry maps:
--   theorem ID -> HOL proposition -> assumptions -> dependencies -> status

module LiquidOrder.SovereignCovenant.Obligations
  ( allObligations
  , requiredObligations
  , optionalObligations
  , lookupObligation
  ) where

import LiquidOrder.Epistemic.Types
import LiquidOrder.SovereignCovenant.HOLFormalization

-- ---------------------------------------------------------------------------
-- Registry
-- ---------------------------------------------------------------------------

allObligations :: [TheoremRecord]
allObligations =
  [ TheoremRecord
      { trId           = "LO-SC-001"
      , trProposition  = "Derive_{Gamma_SC} in FP"
      , trAssumptions  = ["H1-Acyclic", "H2-AllFP", "H4-RootsFixed"]
      , trDependencies = []
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = True
      }
  , TheoremRecord
      { trId           = "LO-SC-002"
      , trProposition  = "Check_{Gamma_SC} in P"
      , trAssumptions  = ["H1-Acyclic", "H2-AllFP", "H3-AllP", "H4-RootsFixed"]
      , trDependencies = ["LO-SC-001"]
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = True
      }
  , TheoremRecord
      { trId           = "LO-SC-003"
      , trProposition  = "forall A B. RewriteStar(A,B) -> N(A)=N(B)"
      , trAssumptions  = ["NormalizationAbsorption-PerRule"]
      , trDependencies = []
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = True
      }
  , TheoremRecord
      { trId           = "LO-SC-004"
      , trProposition  = "EquivalenceRelation(EquivalentN)"
      , trAssumptions  = []
      , trDependencies = ["LO-SC-003"]
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = True
      }
  , TheoremRecord
      { trId           = "LO-SC-005"
      , trProposition  = "N(A)=N(B) -> F(N(A))=F(N(B))"
      , trAssumptions  = []
      , trDependencies = ["LO-SC-004"]
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = True
      }
  , TheoremRecord
      { trId           = "LO-SC-006"
      , trProposition  = "Serialize injective: Serialize(f1)=Serialize(f2) -> f1=f2"
      , trAssumptions  = ["FixedWidthEncoding", "RationalsNormalized"]
      , trDependencies = []
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = True
      }
  , TheoremRecord
      { trId           = "LO-SC-007"
      , trProposition  = "EquivalentN(A,B) -> ClassHash(A)=ClassHash(B)"
      , trAssumptions  = []
      , trDependencies = ["LO-SC-005", "LO-SC-006"]
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = True
      }
  , TheoremRecord
      { trId           = "LO-SC-008"
      , trProposition  = "forall Phi R x. NormalizationPhase(Phi) -> pi(Sem(Phi(R),x))=Sem(R,x)"
      , trAssumptions  = ["SemanticPreservation-PerPhase"]
      , trDependencies = []
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = True
      }
  , TheoremRecord
      { trId           = "LO-SC-009"
      , trProposition  = "ValidRenaming(rho) /\\ Resolved(R) -> N(Rename(rho,R))=N(R)"
      , trAssumptions  = ["StructuralSignatureIndependence"]
      , trDependencies = ["LO-SC-003"]
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = True
      }
  , TheoremRecord
      { trId           = "LO-SC-010"
      , trProposition  = "UnresolvedAutomorphism(R) -> HALT"
      , trAssumptions  = []
      , trDependencies = []
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = True
      }
    -- Optional Track 2 discovery theorem (FactorsThrough N P_ext)
  , TheoremRecord
      { trId           = "LO-SC-P"
      , trProposition  = "forall A B in K. N(A)=N(B) -> P_external(A)=P_external(B)"
      , trAssumptions  = ["ExternalPropertyIndependence", "CorpusObservation"]
      , trDependencies = ["LO-SC-005"]
      , trStatus       = CorpusObservation
      , trCertDigest   = Nothing
      , trRequired     = False   -- discovery; not a build-required obligation
      }
  ]

requiredObligations :: [TheoremRecord]
requiredObligations = filter trRequired allObligations

optionalObligations :: [TheoremRecord]
optionalObligations = filter (not . trRequired) allObligations

lookupObligation :: String -> Maybe TheoremRecord
lookupObligation tid = case filter ((== tid) . trId) allObligations of
  [r] -> Just r
  _   -> Nothing
