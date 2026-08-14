-- LiquidOrder: Quantum Language B — Proof obligations
--
-- These are the formal targets for the Macrobit-Shard Hypothesis.
-- Every obligation maps to a HOL proposition that the solver must certify.
-- None of these are assumed. They are what must be derived.
--
-- Complexity firewall reminder:
--   QLB-001 through QLB-006 are quantum information / holography questions.
--   They are NOT connected to P vs NP.
--   QLB-007 is the separate complexity question (QMA-style decoding hardness).

module LiquidOrder.QuantumLangB.Obligations
  ( qlbObligations
  , qlbRequired
  ) where

import LiquidOrder.Epistemic.Types

-- ---------------------------------------------------------------------------
-- Quantum Language B proof obligations
-- ---------------------------------------------------------------------------

qlbObligations :: [TheoremRecord]
qlbObligations =
  [ TheoremRecord
      { trId          = "QLB-001"
      , trProposition =
          "Isometry(Encode): E† E = I on H_code subspace. "
          ++ "dim(H_horizon) >= dim(H_bulk_logical)"
      , trAssumptions  = ["EncodingMapWellDefined"]
      , trDependencies = []
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = False  -- open research question
      }

  , TheoremRecord
      { trId          = "QLB-002"
      , trProposition =
          "AreaLaw: log(dim(E(H_bulk_physical))) = A / (4 * lP^2) "
          ++ "to leading semiclassical order. "
          ++ "Do NOT insert: this must be derived from constraints on (E, {U_t}, H_shard)."
      , trAssumptions  = ["QLB-001", "PhysicalHilbertSpaceConstraints", "GravityGaugeRedundancy"]
      , trDependencies = ["QLB-001"]
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = False  -- open research question
      }

  , TheoremRecord
      { trId          = "QLB-003"
      , trProposition =
          "Unitarity: forall t. U_t† U_t = I. "
          ++ "dim(H_code) = constant under all scrambling steps."
      , trAssumptions  = ["ScrambleMapWellDefined"]
      , trDependencies = []
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = False  -- open research question
      }

  , TheoremRecord
      { trId          = "QLB-004"
      , trProposition =
          "InformationConservation: I_logical(t+1) = I_logical(t) "
          ++ "under unitary evolution. "
          ++ "Accessibility changes; encoded information does not."
      , trAssumptions  = ["QLB-003"]
      , trDependencies = ["QLB-003"]
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = False  -- open research question
      }

  , TheoremRecord
      { trId          = "QLB-005"
      , trProposition =
          "ShardRecoverability: forall B (bulk logical state). "
          ++ "Recoverable(B) => exists S subset boundary. Recover(S, B) = Recovered(B). "
          ++ "Shard = boundary subsystem, not surface pixel."
      , trAssumptions  = ["QLB-001", "QLB-004", "HolographicErrorCorrection"]
      , trDependencies = ["QLB-001", "QLB-004"]
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = False  -- open research question
      }

  , TheoremRecord
      { trId          = "QLB-006"
      , trProposition =
          "MacrobitDimConstraint: constraints on (E, {U_t}, H_shard) "
          ++ "force log(dim(H_code)) proportional to A not V. "
          ++ "This is the central open question. "
          ++ "Binary shard assumption d_i=2 is a special case, not assumed."
      , trAssumptions  = ["QLB-002", "QLB-005", "PhysicalConstraints", "GaugeRedundancy"]
      , trDependencies = ["QLB-002", "QLB-005"]
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = False  -- open research question; central conjecture of QLB
      }

    -- Complexity question: SEPARATE from entropy-area relation
  , TheoremRecord
      { trId          = "QLB-007"
      , trProposition =
          "DecodingComplexity: classifying the computational hardness "
          ++ "of Recover(S, B) for arbitrary shard sets S. "
          ++ "Conjecture: QMA-hard in general. "
          ++ "This is INDEPENDENT of QLB-001 through QLB-006. "
          ++ "Entropy-area relation does NOT resolve P vs NP."
      , trAssumptions  = ["QLB-005", "ComputationalComplexityFramework"]
      , trDependencies = ["QLB-005"]
      , trStatus       = Conjecture   -- complexity conjecture, not corpus observation
      , trCertDigest   = Nothing
      , trRequired     = False        -- open research question, not build-required
      }

    -- Counterexample search obligations
  , TheoremRecord
      { trId          = "QLB-CE-001"
      , trProposition =
          "Counterexample search: find (E, H_shard) where "
          ++ "log(dim(H_code)) = V (volume) not A (area). "
          ++ "If found: QLB-006 is refuted for that class."
      , trAssumptions  = []
      , trDependencies = []
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = False
      }

  , TheoremRecord
      { trId          = "QLB-CE-002"
      , trProposition =
          "Counterexample search: find unitary sequence {U_t} where "
          ++ "recoverability is NOT conserved. "
          ++ "If found: QLB-004 is refuted."
      , trAssumptions  = []
      , trDependencies = []
      , trStatus       = Unresolved
      , trCertDigest   = Nothing
      , trRequired     = False
      }
  ]

qlbRequired :: [TheoremRecord]
qlbRequired = filter trRequired qlbObligations
