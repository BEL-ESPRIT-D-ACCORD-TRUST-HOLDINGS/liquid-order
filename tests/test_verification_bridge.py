"""
Tests for the Verification <-> EpistemicStatus bridge architecture.

Validates that:
  Verified  -> CORPUS_OBSERVATION  (NOT PROVED)
  Unverified -> UNRESOLVED
  Refuted   -> REFUTED (counterexample)
  collectCorpusObservations semantics
  VerificationEvidence correctly classifies mixed corpus results
"""

import unittest
import os
import sys

# ---------------------------------------------------------------------------
# Python mirror of the Haskell Verification type + bridge logic
# (mirrors VerificationBridge.hs semantics for test purposes)
# ---------------------------------------------------------------------------

class Proof:
    INVARIANT_PRESERVED = "InvariantPreserved"
    SEMANTIC_EQUIVALENT = "SemanticEquivalent"

class Verified:
    def __init__(self, value, proof): self.value = value; self.proof = proof
    def __repr__(self): return f"Verified({self.value!r}, {self.proof})"

class Unverified:
    def __init__(self, reason): self.reason = reason
    def __repr__(self): return f"Unverified({self.reason!r})"

class Refuted:
    def __init__(self, value, reason): self.value = value; self.reason = reason
    def __repr__(self): return f"Refuted({self.value!r}, {self.reason!r})"

# EpistemicStatus bridge labels
PROVED                = "PROVED"
REFUTED               = "REFUTED"
UNRESOLVED            = "UNRESOLVED"
CORPUS_OBSERVATION    = "CORPUS_OBSERVATION"
CANDIDATE_INVARIANT   = "CANDIDATE_INVARIANT"

def verification_to_epistemic(prop_name, result):
    if isinstance(result, Verified):
        return (CORPUS_OBSERVATION,
                f"{prop_name}: runtime evidence — corpus observation (NOT proved)")
    if isinstance(result, Unverified):
        return (UNRESOLVED, f"{prop_name}: {result.reason}")
    if isinstance(result, Refuted):
        return (REFUTED, f"{prop_name}: counterexample — {result.reason}")
    raise ValueError(f"Unknown result type: {type(result)}")

def preserves_invariant(before, transform, after, x):
    y  = transform(x)
    i0 = before(x)
    i1 = after(y)
    if i0 == i1:
        return Verified(y, Proof.INVARIANT_PRESERVED)
    else:
        return Refuted(y, "invariant-violation")

def collect_corpus_observations(prop_name, checker, corpus):
    results = [checker(x) for x in corpus]
    n_total    = len(results)
    n_verified = sum(1 for r in results if isinstance(r, Verified))
    n_refuted  = sum(1 for r in results if isinstance(r, Refuted))
    n_deferred = n_total - n_verified - n_refuted

    if n_refuted > 0:
        first = next(r.reason for r in results if isinstance(r, Refuted))
        status = REFUTED
        note   = f"refuted on {n_refuted}/{n_total}: {first}"
    elif n_verified == n_total:
        status = CORPUS_OBSERVATION
        note   = f"held on all {n_total} — candidate invariant (NOT proved)"
    else:
        status = UNRESOLVED
        note   = f"{n_deferred}/{n_total} unresolved"

    return {
        "property":    prop_name,
        "status":      status,
        "note":        note,
        "n_total":     n_total,
        "n_verified":  n_verified,
        "n_refuted":   n_refuted,
        "n_deferred":  n_deferred,
    }

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestVerificationToEpistemic(unittest.TestCase):

    def test_verified_invariant_maps_to_corpus_observation(self):
        result = Verified(42, Proof.INVARIANT_PRESERVED)
        status, _ = verification_to_epistemic("test_prop", result)
        self.assertEqual(status, CORPUS_OBSERVATION)

    def test_verified_semantic_maps_to_corpus_observation(self):
        result = Verified("x", Proof.SEMANTIC_EQUIVALENT)
        status, _ = verification_to_epistemic("sem_prop", result)
        self.assertEqual(status, CORPUS_OBSERVATION)

    def test_verified_does_NOT_map_to_proved(self):
        # The critical invariant: runtime evidence ≠ kernel-checked theorem
        result = Verified(99, Proof.INVARIANT_PRESERVED)
        status, _ = verification_to_epistemic("critical", result)
        self.assertNotEqual(status, PROVED,
            "Verified result must NEVER produce PROVED status — "
            "only KernelReplay(certificate) = ReplayValid permits PROVED")

    def test_unverified_maps_to_unresolved(self):
        result = Unverified("proof-deferred")
        status, _ = verification_to_epistemic("deferred", result)
        self.assertEqual(status, UNRESOLVED)

    def test_refuted_maps_to_refuted(self):
        result = Refuted("bad_value", "invariant-violation")
        status, _ = verification_to_epistemic("broken", result)
        self.assertEqual(status, REFUTED)


class TestPreservesInvariant(unittest.TestCase):

    def test_length_preserving_transform_is_verified(self):
        checker = lambda xs: preserves_invariant(len, list, len, xs)
        self.assertIsInstance(checker([1, 2, 3]), Verified)

    def test_length_breaking_transform_is_refuted(self):
        checker = lambda xs: preserves_invariant(len, lambda xs: xs[1:], len, xs)
        result = checker([1, 2, 3])
        self.assertIsInstance(result, Refuted)

    def test_identity_preserves_any_invariant(self):
        checker = lambda x: preserves_invariant(lambda v: v, lambda v: v, lambda v: v, x)
        for val in [0, "hello", [1, 2], 3.14]:
            self.assertIsInstance(checker(val), Verified)


class TestCorpusObservations(unittest.TestCase):

    def test_all_verified_corpus_is_corpus_observation(self):
        checker = lambda xs: preserves_invariant(len, sorted, len, xs)
        corpus  = [[3, 1, 2], [5, 4], [], [9, 8, 7, 6]]
        result  = collect_corpus_observations("sorted-length", checker, corpus)
        self.assertEqual(result["status"], CORPUS_OBSERVATION)
        self.assertEqual(result["n_refuted"], 0)

    def test_all_verified_is_candidate_not_proved(self):
        # Explicit: even 100% corpus verification is NOT PROVED
        checker = lambda x: preserves_invariant(len, sorted, len, x)
        corpus  = [[1], [2, 3], [4, 5, 6]]
        result  = collect_corpus_observations("p", checker, corpus)
        self.assertNotEqual(result["status"], PROVED)
        self.assertEqual(result["status"], CORPUS_OBSERVATION)

    def test_any_refuted_makes_whole_corpus_refuted(self):
        def checker(xs):
            return preserves_invariant(len, lambda xs: xs[1:], len, xs)
        corpus = [[1, 2, 3], [4, 5, 6], [7]]  # last is empty after drop
        result = collect_corpus_observations("drop-length", checker, corpus)
        self.assertEqual(result["status"], REFUTED)
        self.assertGreater(result["n_refuted"], 0)

    def test_mixed_with_unverified_is_unresolved(self):
        def checker(xs):
            if len(xs) == 0:
                return Unverified("empty input: proof deferred")
            return preserves_invariant(len, sorted, len, xs)
        corpus = [[1, 2], [], [3]]
        result = collect_corpus_observations("mixed", checker, corpus)
        self.assertEqual(result["status"], UNRESOLVED)


class TestFactorsThroughConnection(unittest.TestCase):
    """
    Verify the connection:
    collect_corpus_observations(...) = CORPUS_OBSERVATION
    means: FactorsThrough N P is a CANDIDATE_INVARIANT (not yet proved)
    """

    def test_corpus_observation_is_candidate_not_theorem(self):
        # Simulate: N = sorted tuple (normal form), P = length
        corpus  = [[3, 1, 2], [2, 1, 3], [1, 2, 3]]  # all same length 3
        N       = lambda xs: tuple(sorted(xs))
        P       = lambda xs: len(xs)
        checker = lambda xs: preserves_invariant(P, lambda xs: sorted(xs), P, xs)
        result  = collect_corpus_observations("FactorsThrough(N,P=len)", checker, corpus)

        self.assertEqual(result["status"], CORPUS_OBSERVATION)
        # Explicit guard: CORPUS_OBSERVATION ≠ PROVED
        self.assertNotEqual(result["status"], PROVED,
            "A corpus observation of FactorsThrough is a candidate invariant, "
            "not a proved theorem. It requires KernelReplay(certificate) = ReplayValid.")

    def test_external_property_not_guaranteed(self):
        # External property (not computable from N) may NOT factor through
        import random
        random.seed(42)
        corpus  = [[1, 2, 3], [1, 3, 2], [2, 1, 3]]
        P_ext   = lambda xs: random.random()  # deliberately NOT a function of N
        checker = lambda xs: preserves_invariant(P_ext, sorted, P_ext, xs)
        result  = collect_corpus_observations("FactorsThrough(N,P_external)", checker, corpus)
        # Either CORPUS_OBSERVATION or REFUTED — never silently PROVED
        self.assertIn(result["status"], [CORPUS_OBSERVATION, REFUTED, UNRESOLVED])
        self.assertNotEqual(result["status"], PROVED)


class TestSemanticEquivalenceConnection(unittest.TestCase):
    """
    Verified _ SemanticEquivalent is evidence toward LO-SC-008
    (SemanticSoundness), not a proof of it.
    """

    def test_semantic_equivalent_is_corpus_evidence_not_proof(self):
        def phi_identity(x): return x  # trivial normalization phase

        # Simulate: pi(Sem(Phi(R), x)) = Sem(R, x) as a runtime check
        def sem(r, x): return (r, x)  # stub semantics
        def pi_proj(trace): return trace  # identity projection

        def checker(r):
            before = sem(r, "input")
            after  = pi_proj(sem(phi_identity(r), "input"))
            if before == after:
                return Verified(after, Proof.SEMANTIC_EQUIVALENT)
            return Refuted(after, "semantic-mismatch")

        corpus = ["R1", "R2", "R3"]
        result = collect_corpus_observations("LO-SC-008-evidence", checker, corpus)
        self.assertEqual(result["status"], CORPUS_OBSERVATION)
        # Not a proof of LO-SC-008 — that requires the formal obligation
        self.assertNotEqual(result["status"], PROVED)


if __name__ == "__main__":
    loader = unittest.TestLoader()
    suite  = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
