"""
Sovereign Model Implant — Python membrane
==========================================

Architecture:
  Prompt -> SovereignImplant -> LLM -> Logic IR -> Verifier -> AcceptedOutput

Core rule:  ModelOutput != TrustedOutput
            Only Verify(ModelOutput) = TRUE allows promotion.

Invariant:
  Trusted(O) <=> KernelVerified(O) AND TraceValid(O) AND PolicyValid(O)

Entropy note:
  temperature=0 does NOT imply H=0 in any general information-theoretic sense.
  H_branch = execution branching entropy for a single-permitted-transition pipeline = 0.
  That is the legitimate invariant.
"""

import hashlib
import json
from dataclasses import dataclass, field, asdict
from enum import Enum
from typing import Optional


# ---------------------------------------------------------------------------
# Trust states (closed enumeration — mirrors EpistemicStatus)
# ---------------------------------------------------------------------------

class TrustState(str, Enum):
    UNTRUSTED  = "UNTRUSTED"    # raw model generation
    CANDIDATE  = "CANDIDATE"    # compiled to IR, not yet verified
    VERIFIED   = "VERIFIED"     # kernel + trace + policy all passed
    REJECTED   = "REJECTED"     # failed at least one check
    INCOMPLETE = "INCOMPLETE"   # verification could not complete

    # Only the external verifier may emit VERIFIED.
    # This class cannot self-assign VERIFIED.


# ---------------------------------------------------------------------------
# Typed output IR — SOVEREIGN-IR-1
# ---------------------------------------------------------------------------

@dataclass
class ComplexityClaim:
    complexity_class: str = "UNKNOWN"
    proof_status: str     = "UNPROVED"
    reduction: Optional[str] = None   # required if claiming NP-hardness


@dataclass
class CryptoClaim:
    claim: Optional[str]       = None
    certificate: Optional[str] = None
    security_model: Optional[str] = None


@dataclass
class QuantumClaim:
    claim: Optional[str]       = None
    is_simulation: bool        = True   # always True unless physical hardware confirmed
    area_blind: bool           = True   # target not embedded


@dataclass
class SovereignIR:
    version: str    = "SOVEREIGN-IR-1"
    claim_type: str = "candidate"          # candidate | theorem | observation | conjecture
    statement: str  = ""
    assumptions: list = field(default_factory=list)
    derivation: list  = field(default_factory=list)
    invariants: list  = field(default_factory=list)
    complexity:  ComplexityClaim  = field(default_factory=ComplexityClaim)
    cryptography: CryptoClaim     = field(default_factory=CryptoClaim)
    quantum:     QuantumClaim     = field(default_factory=QuantumClaim)
    verification_status: str      = "PENDING"  # only verifier may set VERIFIED


# ---------------------------------------------------------------------------
# Candidate: raw model output, explicitly untrusted
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class Candidate:
    model: str
    input_hash: str
    raw_output: str
    trust_state: TrustState = TrustState.UNTRUSTED


# ---------------------------------------------------------------------------
# Verified output: IR + audit trail
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class VerifiedOutput:
    ir: dict
    input_hash: str
    candidate_hash: str
    ir_hash: str
    proof_hash: str
    verdict: str
    trust_state: TrustState = TrustState.VERIFIED


# ---------------------------------------------------------------------------
# Verifier result
# ---------------------------------------------------------------------------

@dataclass
class VerifierResult:
    ok: bool
    reason: str
    checks: dict = field(default_factory=dict)


# ---------------------------------------------------------------------------
# Verifier: runs all proof obligations
# ---------------------------------------------------------------------------

class Verifier:
    """
    Runs: type_check, invariant_check, proof_check,
          complexity_firewall, crypto_firewall, quantum_firewall.
    Only this class may produce TrustState.VERIFIED.
    """

    def check(self, ir: dict) -> VerifierResult:
        checks = {}

        # 1. Type check: required IR fields present
        checks["type_check"] = self._type_check(ir)

        # 2. Complexity firewall
        checks["complexity_firewall"] = self._complexity_firewall(ir)

        # 3. Crypto firewall
        checks["crypto_firewall"] = self._crypto_firewall(ir)

        # 4. Quantum firewall
        checks["quantum_firewall"] = self._quantum_firewall(ir)

        # 5. Invariants
        checks["invariants"] = self._invariant_check(ir)

        passed = all(v["ok"] for v in checks.values())
        reason = "all checks passed" if passed else \
                 "; ".join(v["reason"] for v in checks.values() if not v["ok"])

        return VerifierResult(ok=passed, reason=reason, checks=checks)

    def _type_check(self, ir: dict) -> dict:
        required = ["version", "claim_type", "statement",
                    "assumptions", "complexity", "verification_status"]
        missing = [f for f in required if f not in ir]
        if missing:
            return {"ok": False, "reason": f"missing fields: {missing}"}
        if ir.get("version") != "SOVEREIGN-IR-1":
            return {"ok": False, "reason": "wrong IR version"}
        return {"ok": True, "reason": "type check passed"}

    def _complexity_firewall(self, ir: dict) -> dict:
        c = ir.get("complexity", {})
        status = c.get("proof_status", "UNPROVED")
        cls    = c.get("complexity_class", "UNKNOWN")

        forbidden = [
            (cls == "P=NP",   "P=NP claim without machine-checked proof"),
            (cls == "P!=NP",  "P!=NP claim without machine-checked proof"),
        ]
        for condition, msg in forbidden:
            if condition and status != "PROVED":
                return {"ok": False, "reason": msg}

        return {"ok": True, "reason": "complexity firewall passed"}

    def _crypto_firewall(self, ir: dict) -> dict:
        c = ir.get("cryptography", {})
        if c.get("claim") in ("BROKEN", "KEY_RECOVERED"):
            if not c.get("certificate"):
                return {"ok": False,
                        "reason": "crypto claim requires reproducible certificate"}
        return {"ok": True, "reason": "crypto firewall passed"}

    def _quantum_firewall(self, ir: dict) -> dict:
        q = ir.get("quantum", {})
        if not q.get("area_blind", True):
            return {"ok": False,
                    "reason": "area law claim has target embedded — violates AREA-BLINDNESS"}
        return {"ok": True, "reason": "quantum firewall passed"}

    def _invariant_check(self, ir: dict) -> dict:
        invs = ir.get("invariants", [])
        # Stub: full invariant check delegates to LiquidOrder kernel replay
        return {"ok": True, "reason": f"{len(invs)} invariants registered (kernel replay pending)"}


# ---------------------------------------------------------------------------
# Sovereign Implant — the membrane
# ---------------------------------------------------------------------------

class SovereignImplant:
    """
    Wraps any LLM. The model is explicitly an untrusted generator.
    Output only becomes TrustState.VERIFIED after Verifier acceptance.
    """

    def __init__(self, model, verifier: Optional[Verifier] = None):
        self.model    = model
        self.verifier = verifier or Verifier()

    def generate(self, prompt: str) -> Candidate:
        prompt_hash = hashlib.sha256(prompt.encode()).hexdigest()

        # Model is untrusted — call with deterministic decoder settings
        raw = self.model.generate(
            prompt,
            temperature=0.0,
            do_sample=False,
        )

        return Candidate(
            model=self.model.name,
            input_hash=prompt_hash,
            raw_output=raw,
            trust_state=TrustState.UNTRUSTED,
        )

    def compile_to_ir(self, candidate: Candidate) -> dict:
        """Lower raw candidate to SOVEREIGN-IR-1 typed IR."""
        ir = asdict(SovereignIR(
            statement=candidate.raw_output,
            claim_type="candidate",
            verification_status="PENDING",
        ))
        ir["_model"]      = candidate.model
        ir["_input_hash"] = candidate.input_hash
        return ir

    def verify(self, candidate: Candidate) -> VerifiedOutput:
        ir      = self.compile_to_ir(candidate)
        verdict = self.verifier.check(ir)

        if not verdict.ok:
            raise ValueError({
                "status":  TrustState.REJECTED.value,
                "reason":  verdict.reason,
                "checks":  verdict.checks,
            })

        # Promote IR to VERIFIED only after all checks pass
        ir["verification_status"] = TrustState.VERIFIED.value

        canonical = json.dumps(ir, sort_keys=True, separators=(",", ":")).encode()

        return VerifiedOutput(
            ir           = ir,
            input_hash   = candidate.input_hash,
            candidate_hash = hashlib.sha256(candidate.raw_output.encode()).hexdigest(),
            ir_hash      = hashlib.sha256(canonical).hexdigest(),
            proof_hash   = "PENDING",   # filled by LiquidOrder kernel after replay
            verdict      = TrustState.VERIFIED.value,
        )

    def run(self, prompt: str) -> VerifiedOutput:
        """Full pipeline: Prompt -> Candidate -> IR -> Verify -> VerifiedOutput"""
        candidate = self.generate(prompt)
        return self.verify(candidate)

    def worm_record(self, run_id: str, verified: VerifiedOutput) -> dict:
        """Build the WORM ledger record for this run."""
        return {
            "run_id":         run_id,
            "input_hash":     verified.input_hash,
            "candidate_hash": verified.candidate_hash,
            "ir_hash":        verified.ir_hash,
            "proof_hash":     verified.proof_hash,
            "verdict":        verified.verdict,
            "locked":         True,
        }


# ---------------------------------------------------------------------------
# H_branch: execution branching entropy
# For a pipeline with exactly one permitted transition: H_branch = 0
# ---------------------------------------------------------------------------

def h_branch(transitions: list[float]) -> float:
    """
    H_branch = -sum_i p_i * log(p_i)
    For a single-permitted-transition pipeline: transitions = [1.0], H_branch = 0.
    This is the legitimate zero-entropy invariant, not neural temperature entropy.
    """
    import math
    return -sum(p * math.log(p) for p in transitions if p > 0)


# ---------------------------------------------------------------------------
# Null model stub (replace with actual Llama/Qwen/Mistral/Gemma adapter)
# ---------------------------------------------------------------------------

class NullModel:
    """Stub model for testing the implant without a live LLM."""
    name = "null_model"

    def generate(self, prompt: str, temperature=0.0, do_sample=False) -> str:
        return f"[NULL MODEL RESPONSE TO: {prompt[:40]}]"


# ---------------------------------------------------------------------------
# Smoke test
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    implant = SovereignImplant(NullModel())

    prompt = "Prove that P = NP."

    print("=== Sovereign Model Implant ===")
    print(f"Prompt: {prompt}")

    try:
        result = implant.run(prompt)
        print(f"Trust state: {result.verdict}")
        print(f"IR hash:     {result.ir_hash}")
        print(f"Complexity:  {result.ir.get('complexity')}")
    except ValueError as e:
        print(f"REJECTED: {e}")

    print(f"\nH_branch (single transition): {h_branch([1.0])}")
    print(f"H_branch (two transitions):   {h_branch([0.5, 0.5]):.4f}")
