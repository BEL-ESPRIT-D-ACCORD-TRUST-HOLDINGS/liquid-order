"""
LiquidOrder integration tests.

Tests the full pipeline:
  Certificate structure -> Kernel replay -> Epistemic status
  Pipeline with no certs -> all UNRESOLVED, build fails
  Pipeline with valid cert -> PROVED, build passes for that theorem
  Pipeline with bad cert -> kernel rejects, build fails
  Track 3 isolation -> never runs if required theorems unproved
  Epistemic promotion legality
  Numerical target firewall (gate 9)

All tests are self-contained. No external dependencies required.
"""

import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "impl"))

from run_pipeline import (
    OBLIGATIONS,
    kernel_replay,
    cert_digest,
    build_manifest,
    KERNEL_PRIMITIVE_RULES,
    EpistemicStatus,
)

# ---------------------------------------------------------------------------
# Helpers: build valid and invalid certificates
# ---------------------------------------------------------------------------

def make_valid_cert(theorem_id: str, proposition: str) -> dict:
    """A certificate with a syntactically valid kernel derivation."""
    return {
        "theorem_id":   theorem_id,
        "proposition":  proposition,
        "assumptions":  [],
        "dependencies": [],
        "derivation": {
            "rule":       "REFL",
            "conclusion": proposition,
            "premises":   [],
        },
    }

def make_invalid_cert(theorem_id: str, proposition: str) -> dict:
    """A certificate that uses a non-kernel rule — must be rejected."""
    return {
        "theorem_id":   theorem_id,
        "proposition":  proposition,
        "assumptions":  [],
        "dependencies": [],
        "derivation": {
            "rule":       "SOLVER_SAYS_TRUE",   # NOT a primitive
            "conclusion": proposition,
            "premises":   [],
        },
    }

def make_mismatch_cert(theorem_id: str, proposition: str) -> dict:
    """A certificate whose derivation conclusion differs from stated proposition."""
    return {
        "theorem_id":   theorem_id,
        "proposition":  proposition,
        "assumptions":  [],
        "dependencies": [],
        "derivation": {
            "rule":       "REFL",
            "conclusion": "WRONG_PROPOSITION",   # mismatch
            "premises":   [],
        },
    }


# ---------------------------------------------------------------------------
# Test suite
# ---------------------------------------------------------------------------

class TestKernelReplay(unittest.TestCase):

    def test_valid_cert_produces_proved(self):
        cert = make_valid_cert("LO-SC-001", "Derive in FP")
        status, reason = kernel_replay(cert)
        self.assertEqual(status, EpistemicStatus.PROVED)

    def test_invalid_rule_produces_refuted(self):
        cert = make_invalid_cert("LO-SC-001", "Derive in FP")
        status, reason = kernel_replay(cert)
        self.assertEqual(status, EpistemicStatus.REFUTED)
        self.assertIn("Unknown rule", reason)

    def test_conclusion_mismatch_produces_refuted(self):
        cert = make_mismatch_cert("LO-SC-001", "Derive in FP")
        status, reason = kernel_replay(cert)
        self.assertEqual(status, EpistemicStatus.REFUTED)
        self.assertIn("mismatch", reason)

    def test_empty_derivation_produces_unresolved(self):
        cert = {
            "theorem_id":  "LO-SC-001",
            "proposition": "Derive in FP",
            "assumptions": [],
            "dependencies": [],
            "derivation":  {},
        }
        status, reason = kernel_replay(cert)
        self.assertEqual(status, EpistemicStatus.UNRESOLVED)

    def test_solver_boolean_rejected(self):
        """Solver returning bare True must not produce PROVED."""
        cert = {
            "theorem_id":  "LO-SC-001",
            "proposition": "Derive in FP",
            "assumptions": [],
            "dependencies": [],
            "derivation":  {"rule": "TRUST_ME", "conclusion": "Derive in FP", "premises": []},
        }
        status, _ = kernel_replay(cert)
        self.assertNotEqual(status, EpistemicStatus.PROVED)

    def test_all_primitive_rules_accepted(self):
        for rule in KERNEL_PRIMITIVE_RULES:
            cert = {
                "theorem_id":  "TEST",
                "proposition": "p",
                "assumptions": [],
                "dependencies": [],
                "derivation":  {"rule": rule, "conclusion": "p", "premises": []},
            }
            status, _ = kernel_replay(cert)
            self.assertEqual(status, EpistemicStatus.PROVED,
                             f"Rule {rule} should produce PROVED")


class TestPipelineNoCerts(unittest.TestCase):

    def test_empty_manifest_fails_build(self):
        manifest = build_manifest({})
        self.assertFalse(manifest["build_ok"])

    def test_all_required_unresolved_without_certs(self):
        manifest = build_manifest({})
        req_entries = [t for t in manifest["theorems"] if t["required"]]
        for entry in req_entries:
            self.assertEqual(entry["kernel_status"], "UNRESOLVED")

    def test_error_count_equals_required_count(self):
        manifest = build_manifest({})
        required_count = sum(1 for ob in OBLIGATIONS if ob["required"])
        self.assertEqual(len(manifest["errors"]), required_count)


class TestPipelineWithValidCert(unittest.TestCase):

    def test_single_proved_cert_clears_one_error(self):
        ob = next(ob for ob in OBLIGATIONS if ob["id"] == "LO-SC-001")
        cert = make_valid_cert(ob["id"], ob["proposition"])
        manifest = build_manifest({"LO-SC-001": cert})

        lo_001 = next(t for t in manifest["theorems"] if t["id"] == "LO-SC-001")
        self.assertEqual(lo_001["kernel_status"], "PROVED")
        # Other 9 still unresolved
        self.assertFalse(manifest["build_ok"])

    def test_cert_digest_populated_on_proved(self):
        ob = next(ob for ob in OBLIGATIONS if ob["id"] == "LO-SC-002")
        cert = make_valid_cert(ob["id"], ob["proposition"])
        manifest = build_manifest({"LO-SC-002": cert})
        entry = next(t for t in manifest["theorems"] if t["id"] == "LO-SC-002")
        self.assertNotEqual(entry["cert_digest"], "NONE")

    def test_invalid_cert_does_not_prove(self):
        ob = next(ob for ob in OBLIGATIONS if ob["id"] == "LO-SC-003")
        cert = make_invalid_cert(ob["id"], ob["proposition"])
        manifest = build_manifest({"LO-SC-003": cert})
        entry = next(t for t in manifest["theorems"] if t["id"] == "LO-SC-003")
        self.assertNotEqual(entry["kernel_status"], "PROVED")


class TestTrack3Isolation(unittest.TestCase):

    def test_track3_does_not_run_without_all_proved(self):
        from run_pipeline import run_track3
        manifest = build_manifest({})   # all UNRESOLVED
        result = run_track3(manifest)
        self.assertEqual(result["status"], "NOT_RUN")
        self.assertIn("blocked", result["reason"])

    def test_track3_omega_extract_has_no_target(self):
        """omega_extract.py must not contain the numerical target."""
        path = os.path.join(ROOT, "impl", "omega_extract.py")
        with open(path) as f:
            content = f.read()
        # The numerical target must not appear as a literal
        # We check for a known forbidden pattern (see gate_9 for the real check)
        self.assertNotIn("2462", content,
                         "Numerical target must not appear in omega_extract.py")


class TestEpistemicStatuses(unittest.TestCase):

    def test_corpus_observation_not_proved(self):
        self.assertNotEqual(EpistemicStatus.CORPUS_OBSERVATION, EpistemicStatus.PROVED)

    def test_conjecture_not_proved(self):
        self.assertNotEqual(EpistemicStatus.CONJECTURE, EpistemicStatus.PROVED)

    def test_empirical_not_proved(self):
        self.assertNotEqual(EpistemicStatus.EMPIRICAL_NUMERICAL_RESULT, EpistemicStatus.PROVED)

    def test_proved_is_only_proved(self):
        non_proved = [s for s in EpistemicStatus if s != EpistemicStatus.PROVED]
        for s in non_proved:
            self.assertFalse(s == EpistemicStatus.PROVED,
                             f"{s} must not equal PROVED")


class TestFreezegateIntegration(unittest.TestCase):
    """Integration with the existing freeze gate checker."""

    def test_all_nine_gates_pass(self):
        import subprocess
        result = subprocess.run(
            [sys.executable,
             os.path.join(ROOT, "tests", "test_freeze_gates.py")],
            capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0,
                         f"Freeze gates failed:\n{result.stdout}\n{result.stderr}")

    def test_phi3_has_no_runtime_hash(self):
        import ast
        path = os.path.join(ROOT, "impl", "phi3_canonical.py")
        with open(path) as f:
            tree = ast.parse(f.read())
        for node in ast.walk(tree):
            if isinstance(node, ast.Call):
                if isinstance(node.func, ast.Name) and node.func.id == "hash":
                    self.fail(f"hash() found at line {node.lineno} in phi3_canonical.py")

    def test_phi3_has_unresolved_halt(self):
        path = os.path.join(ROOT, "impl", "phi3_canonical.py")
        with open(path) as f:
            content = f.read()
        self.assertIn("UNRESOLVED_AUTOMORPHISM", content)

    def test_complexity_types_not_conflated(self):
        """Verify HOL is not described as a complexity class in key files."""
        paths_to_check = [
            os.path.join(ROOT, "spec", "PROTOCOL_v1.md"),
            os.path.join(ROOT, "spec", "PROOF_JOB_v1.md"),
        ]
        bad_phrases = [
            "HOL is NP",
            "HOL is in P",
            "HOL complexity class",
        ]
        for fpath in paths_to_check:
            if not os.path.exists(fpath):
                continue
            with open(fpath, encoding="utf-8", errors="replace") as f:
                content = f.read().lower()
            for phrase in bad_phrases:
                self.assertNotIn(phrase.lower(), content,
                                 f"'{phrase}' found in {fpath} — HOL is not a complexity class")


# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    loader = unittest.TestLoader()
    suite  = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
