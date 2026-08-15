"""
WormEsolang Runtime Interpreter
=================================
5-instruction stack-based language with O(1) gravitational tunnel semantics.
MUMPS ^BH globals provide persistent black hole state.

Instructions:
  Ω              — initialize singularity (head=0, time=0, stack=[])
  ~> SectorName  — gravitational tunnel: head ← sector_base_address (O(1))
  MUMPS_FETCH k  — push ^BH(k) to stack
  ⊕              — F₂ add: pop a, b; push (a+b) mod 2
  #invariant     — pop result; output topological invariant

Sector map (matches PlanetaryTape.lean):
  Mercury:  0
  Venus:    1001
  Earth:    2001
  Jupiter:  3001
  Neptune:  4001
  Horizon:  ^BH("HorizonSector")  [default 5001]

Execution trace for BH entropy extraction:
  Ω
  ~> Horizon_Sector
  MUMPS_FETCH ^BH("Entropy")
  ⊕
  #invariant
  → output: S_BH mod 2

Complexity note:
  Classical TM head movement: O(N) per step
  WormEsolang ~> operator: O(1) for any sector
  Earth → Neptune: 5000 classical steps → 1 wormhole transition
"""

import math
from typing import Any


SECTOR_MAP = {
    "Mercury":        0,
    "Venus":          1001,
    "Earth":          2001,
    "Jupiter":        3001,
    "Neptune":        4001,
    "Horizon_Sector": 5001,   # overridden by ^BH("HorizonSector") if set
    "Tail":           8001,
}


class WormEsolangRuntime:
    """Interpreter for the 5-instruction WormEsolang language."""

    def __init__(self, mumps_globals: dict = None):
        self._bh    = mumps_globals or {}
        self._stack: list  = []
        self._head:  int   = 0
        self._time:  int   = 0
        self._output: list = []

    # -----------------------------------------------------------------------
    # Instructions
    # -----------------------------------------------------------------------

    def omega(self) -> None:
        """Ω: Initialize singularity."""
        self._head   = 0
        self._time   = 0
        self._stack  = []
        self._output = []

    def tunnel(self, sector: str) -> None:
        """~> SectorName: O(1) gravitational warp to sector base address."""
        if sector == "Horizon_Sector":
            addr = int(self._bh.get("HorizonSector", 5001))
        elif sector in SECTOR_MAP:
            addr = SECTOR_MAP[sector]
        else:
            raise ValueError(f"Unknown sector: {sector}")
        self._head = addr

    def mumps_fetch(self, key: str) -> None:
        """MUMPS_FETCH key: push ^BH(key) to stack."""
        val = self._bh.get(key, 0.0)
        self._stack.append(val)

    def f2_add(self) -> None:
        """⊕: pop a, b; push (a + b) mod 2."""
        if len(self._stack) < 1:
            raise RuntimeError("⊕ requires at least 1 value on stack")
        a = self._stack.pop()
        b = self._stack.pop() if self._stack else 0
        self._stack.append((int(a) + int(b)) % 2)

    def mass_collapse(self) -> Any:
        """#invariant: pop result; output topological invariant."""
        if not self._stack:
            result = 0
        else:
            result = self._stack.pop()
        invariant = int(result) % 2   # F₂-valued
        self._output.append(invariant)
        return invariant

    # -----------------------------------------------------------------------
    # Execution engine
    # -----------------------------------------------------------------------

    def execute(self, program: list[str]) -> list:
        """Run a list of instruction strings. Returns output list."""
        for instr in program:
            instr = instr.strip()
            if not instr or instr.startswith(";"):
                continue   # blank / comment

            if instr == "Ω":
                self.omega()
            elif instr.startswith("~>"):
                sector = instr[2:].strip()
                self.tunnel(sector)
            elif instr.startswith("MUMPS_FETCH"):
                key = instr[len("MUMPS_FETCH"):].strip()
                # Strip ^BH("...") notation
                if key.startswith("^BH("):
                    key = key[4:].strip(')').strip('"').strip("'")
                self.mumps_fetch(key)
            elif instr == "⊕":
                self.f2_add()
            elif instr == "#invariant":
                self.mass_collapse()
            else:
                raise ValueError(f"Unknown instruction: {instr}")

            self._time += 1

        return self._output

    def state(self) -> dict:
        return {
            "head":   self._head,
            "time":   self._time,
            "stack":  list(self._stack),
            "output": list(self._output),
        }


# ---------------------------------------------------------------------------
# Standard BH entropy extraction program
# ---------------------------------------------------------------------------

BH_ENTROPY_PROGRAM = [
    "Ω",
    "~> Horizon_Sector",
    'MUMPS_FETCH Entropy',
    "⊕",
    "#invariant",
]


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import json, sys, io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

    PI = math.pi
    M  = 10.0   # mass in Planck units
    RS = 2 * M
    A  = 4 * PI * RS * RS
    S  = A / 4

    bh_globals = {
        "Mass":          M,
        "PlanckArea":    A,
        "Entropy":       S,
        "HorizonSector": 5001,
    }

    print("=== WormEsolang Runtime ===")
    print(f"BH Mass:    {M} Planck units")
    print(f"BH Entropy: {S:.4f}")
    print(f"F2(S_BH):   {int(S) % 2}  (trivial for integer mass)")
    print()

    rt = WormEsolangRuntime(bh_globals)
    output = rt.execute(BH_ENTROPY_PROGRAM)

    print("Program:")
    for line in BH_ENTROPY_PROGRAM:
        print(f"  {line}".encode("ascii", "replace").decode())
    print()

    print("Execution trace:")
    print(f"  Step 1 (Ω):            head=0, time=0, stack=[]")
    print(f"  Step 2 (~>Horizon):    head={bh_globals['HorizonSector']} (O(1) warp)")
    print(f"  Step 3 (FETCH):        stack=[{S:.4f}]")
    print(f"  Step 4 (⊕):            stack=[{int(S) % 2}]  (S_BH mod 2)")
    print(f"  Step 5 (#invariant):   output={output}")
    print()
    print(f"Final state: {json.dumps(rt.state(), indent=2)}")
    print()
    print("Complexity:")
    print("  Classical TM Earth→Neptune: 5000 steps")
    print("  WormEsolang ~>Neptune:        1 step (O(1))")
    print()
    print("Note: F₂ invariant = 0 for integer mass (trivial).")
    print("      Quantum corrections (log(A) terms) needed for non-trivial invariant.")
