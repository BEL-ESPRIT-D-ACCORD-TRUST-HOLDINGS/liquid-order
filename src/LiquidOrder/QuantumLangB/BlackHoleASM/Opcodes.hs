-- LiquidOrder: BlackHoleASM — Opcode definitions with formal semantics
--
-- Each opcode has:
--   1. Syntax (what the assembler accepts)
--   2. Semantic obligation (what LiquidOrder HOL must prove about it)
--   3. Invariant it must preserve
--
-- AREA-BLINDNESS applies to the entire opcode set:
--   No opcode may embed A/(4*lP^2) in its semantics.

module LiquidOrder.QuantumLangB.BlackHoleASM.Opcodes
  ( Opcode(..)
  , BHAsmProgram(..)
  , BHAsmInstruction(..)
  , SemanticObligation(..)
  , opcodeObligations
  , renderBHAsm
  , parseBHAsm
  ) where

import LiquidOrder.QuantumLangB.Types

-- ---------------------------------------------------------------------------
-- BlackHoleASM opcodes
-- ---------------------------------------------------------------------------

data Opcode
  -- Resource allocation
  = HORIZON      -- HORIZON h, capacity_hint
  | MACROBIT     -- MACROBIT m
  | SHARD        -- SHARD s, h
  | ALLOC        -- ALLOC q   (qubit allocation)
  | RELEASE      -- RELEASE q  (qubit deallocation)

  -- Quantum operations
  | SUPERPOSE    -- SUPERPOSE q  (Hadamard: |0> -> |+>)
  | BRAID        -- BRAID q0, q1  (topological exchange, optional)
  | ENTANGLE     -- ENTANGLE q0, q1  (any entangling gate)
  | SCRAMBLE     -- SCRAMBLE h  (unitary scrambling of horizon h)

  -- Shard / information flow
  | CYCLE        -- CYCLE t  (declare cycle step t)
  | MIGRATE      -- MIGRATE m, s0 -> s1  (recoverability migration)
  | SEAL         -- SEAL s  (shard sealed; no further migration)
  | RADIATE      -- RADIATE m  (transfer recoverability to radiation)

  -- Measurement and control
  | MEASURE      -- MEASURE q -> c  (qubit -> classical bit)
  | BRANCH       -- BRANCH c, @label
  | LABEL        -- @label:

  -- Reporting (area-blind)
  | REPORT       -- REPORT horizon, area, n_admissible
  deriving (Eq, Show)

-- ---------------------------------------------------------------------------
-- Instruction (opcode + operands)
-- ---------------------------------------------------------------------------

data BHAsmInstruction = BHAsmInstruction
  { bhaOpcode   :: Opcode
  , bhaOperands :: [String]    -- abstract operand strings
  , bhaComment  :: Maybe String
  } deriving (Show)

newtype BHAsmProgram = BHAsmProgram [BHAsmInstruction]
  deriving (Show)

-- ---------------------------------------------------------------------------
-- Semantic obligations per opcode
-- These map to LiquidOrder HOL proof targets.
-- ---------------------------------------------------------------------------

data SemanticObligation = SemanticObligation
  { soOpcode     :: Opcode
  , soStatement  :: String       -- human-readable obligation
  , soHOLTarget  :: String       -- HOL proposition identifier
  , soRequired   :: Bool
  } deriving (Show)

opcodeObligations :: [SemanticObligation]
opcodeObligations =
  [ SemanticObligation ENTANGLE
      "[[ENTANGLE(q_i, q_j)]] = U_ij |psi>  where U is a valid 2-qubit unitary"
      "QLB-003-ENTANGLE"
      True

  , SemanticObligation SCRAMBLE
      "|psi_{t+1}> = U_t |psi_t>  and  U_t† U_t = I"
      "QLB-003-SCRAMBLE"
      True

  , SemanticObligation MIGRATE
      "I_logical(M, before) = I_logical(M, after)  AND  \
      \Recover(M, s0, t) = 1  AND  Recover(M, s1, t+1) = 1"
      "QLB-004-MIGRATE"
      True

  , SemanticObligation RADIATE
      "Recoverability transfers to radiation subsystem; \
      \information is NOT deleted (no-cloning not violated)"
      "QLB-004-RADIATE"
      True

  , SemanticObligation SEAL
      "After SEAL(s): no further MIGRATE targeting s is valid"
      "QLB-005-SEAL"
      True

  , SemanticObligation REPORT
      "REPORT emits: HORIZON_AREA, ADMISSIBLE_STATES, ENTROPY=log(N), \
      \AREA_RATIO=log(N)/A.  \
      \AREA-BLINDNESS: A/(4*lP^2) does NOT appear in the computation. \
      \Convergence of AREA_RATIO toward 1/(4*lP^2) is the experimental finding."
      "QLB-002-REPORT"
      True

  , SemanticObligation CYCLE
      "Each CYCLE t is assigned a CycleType: QuantumCycle | ClassicalCycle | WaitCycle. \
      \WaitCycles are compressible by the scheduler."
      "QLB-CYCLE-TYPE"
      False

  , SemanticObligation BRAID
      "BRAID(q0, q1) is a topological exchange. \
      \Semantic obligation: anyonic exchange statistics preserved if applicable."
      "QLB-BRAID-ANYON"
      False
  ]

-- ---------------------------------------------------------------------------
-- Example program renderer
-- ---------------------------------------------------------------------------

renderInstruction :: BHAsmInstruction -> String
renderInstruction (BHAsmInstruction op operands comment) =
  let opStr  = show op
      argStr = if null operands then "" else " " ++ unwords (punctuate operands)
      cStr   = maybe "" (\c -> "  ; " ++ c) comment
  in opStr ++ argStr ++ cStr

punctuate :: [String] -> [String]
punctuate [] = []
punctuate [x] = [x]
punctuate (x:xs) = (x ++ ",") : punctuate xs

renderBHAsm :: BHAsmProgram -> String
renderBHAsm (BHAsmProgram instrs) = unlines (header : map renderInstruction instrs)
  where
    header = "; QBH-ASM v0.1\n; Area-blind. IBM internals not required."

-- ---------------------------------------------------------------------------
-- Minimal example program (the canonical reference program)
-- ---------------------------------------------------------------------------

exampleProgram :: BHAsmProgram
exampleProgram = BHAsmProgram
  [ BHAsmInstruction HORIZON  ["h0", "256"]       (Just "horizon with capacity hint 256")
  , BHAsmInstruction MACROBIT ["m0"]               Nothing
  , BHAsmInstruction MACROBIT ["m1"]               Nothing
  , BHAsmInstruction SHARD    ["s0", "h0"]         Nothing
  , BHAsmInstruction SHARD    ["s1", "h0"]         Nothing
  , BHAsmInstruction ALLOC    ["q0"]               Nothing
  , BHAsmInstruction ALLOC    ["q1"]               Nothing
  , BHAsmInstruction SUPERPOSE ["q0"]              (Just "|0> -> |+>")
  , BHAsmInstruction BRAID    ["q0", "q1"]         Nothing
  , BHAsmInstruction ENTANGLE ["q0", "q1"]         Nothing
  , BHAsmInstruction CYCLE    ["0"]                Nothing
  , BHAsmInstruction MIGRATE  ["m0", "s0->s1"]     (Just "recoverability migrates, info conserved")
  , BHAsmInstruction SCRAMBLE ["h0"]               Nothing
  , BHAsmInstruction MEASURE  ["q0->c0"]           Nothing
  , BHAsmInstruction BRANCH   ["c0", "@evaporate"] Nothing
  , BHAsmInstruction SEAL     ["s0"]               Nothing
  , BHAsmInstruction SEAL     ["s1"]               Nothing
  , BHAsmInstruction LABEL    ["@evaporate"]       Nothing
  , BHAsmInstruction RADIATE  ["m0"]               Nothing
  , BHAsmInstruction RELEASE  ["q0"]               Nothing
  , BHAsmInstruction RELEASE  ["q1"]               Nothing
  , BHAsmInstruction REPORT   ["h0"]               (Just "area-blind entropy report")
  ]

-- Stub parser (expand with real lexer/parser when needed)
parseBHAsm :: String -> Either String BHAsmProgram
parseBHAsm _ = Right exampleProgram
