-- LiquidOrder: Quantum Language B — Type declarations
--
-- Formalizes the Macrobit-Shard Hypothesis as a LiquidOrder proof target.
--
-- Central hypothesis:
--
--   exists E : BulkState -> ShardState such that
--     log(dim(E(H_bulk))) = A / (4 * lP^2)
--
--   and a sequence of unitaries U_1..U_T such that
--     U_t† U_t = I  (unitary, no information loss)
--     dim(H_code) = constant  (logical information conserved)
--
-- Open question formalized as a LiquidOrder obligation:
--
--   What constraints on (E, {U_t}, H_shard) force
--   log(dim(H_code)) ∝ A  rather than V?
--
-- Complexity firewall (explicit):
--   Entropy-area relation is NOT connected to P vs NP here.
--   The relevant complexity question is: how hard is decoding
--   a logical bulk state from a given shard set?
--   That is a separate QMA-style question, not an entropy question.

module LiquidOrder.QuantumLangB.Types
  ( -- Core types
    BulkState(..)
  , HorizonState(..)
  , RadiationState(..)
  , Macrobit(..)
  , Shard(..)
  , LogicalQubit(..)
  , ShardSet(..)
  , Horizon(..)
  , Time(..)
    -- Observables
  , Entropy(..)
  , Area(..)
  , Dimension(..)
    -- Encoding and evolution
  , EncodingMap(..)
  , ScrambleMap(..)
  , RecoveryResult(..)
    -- Subsystem partition
  , Partition(..)
  , Recoverability(..)
  ) where

-- ---------------------------------------------------------------------------
-- Core types (abstract — no constructors exposed to untrusted code)
-- ---------------------------------------------------------------------------

-- A state in the physical bulk Hilbert space H_bulk
newtype BulkState    = BulkState    { bulkDim  :: Integer } deriving (Show, Eq)

-- A state encoded on the horizon H_horizon
newtype HorizonState = HorizonState { horizonDim :: Integer } deriving (Show, Eq)

-- A state in the radiation field H_radiation
newtype RadiationState = RadiationState { radDim :: Integer } deriving (Show, Eq)

-- A fundamental horizon degree of freedom.
-- dim(H_i) is NOT assumed to be 2 — that is a hypothesis to derive.
newtype Macrobit = Macrobit { macrobitDim :: Integer } deriving (Show, Eq)

-- A boundary subsystem carrying a recoverable share of a bulk logical state.
-- Shard = boundary subsystem, not a pixel or literal bit.
data Shard = Shard
  { shardIndex  :: Int
  , shardDim    :: Integer     -- dim(H_i) for this shard
  , shardRegion :: String      -- boundary region label
  } deriving (Show, Eq)

newtype ShardSet = ShardSet { shards :: [Shard] } deriving (Show)

-- A logical qubit: abstract encoded quantum information
newtype LogicalQubit = LogicalQubit { logicalDim :: Integer } deriving (Show, Eq)

-- A horizon: characterized by its area only (no interior assumptions)
data Horizon = Horizon
  { horizonArea :: Double    -- A in Planck units (A / lP^2)
  } deriving (Show)

newtype Time = Time { timeStep :: Int } deriving (Show, Eq, Ord)

-- ---------------------------------------------------------------------------
-- Observables
-- ---------------------------------------------------------------------------

newtype Entropy   = Entropy   { entropyValue :: Double } deriving (Show, Eq, Ord)
newtype Area      = Area      { areaValue    :: Double } deriving (Show, Eq, Ord)
newtype Dimension = Dimension { dimValue     :: Integer } deriving (Show, Eq, Ord)

-- Bekenstein-Hawking entropy for a given horizon
bekensteinHawking :: Horizon -> Entropy
bekensteinHawking h = Entropy (horizonArea h / 4.0)
  -- S_BH = k_B * A / (4 * lP^2); in natural units k_B = 1

-- Number of microscopic states compatible with BH entropy
bhMicrostates :: Horizon -> Double
bhMicrostates h = exp (entropyValue (bekensteinHawking h))

-- ---------------------------------------------------------------------------
-- Encoding map E : H_bulk -> H_horizon
-- Must be an isometry: E† E = I on the code subspace
-- ---------------------------------------------------------------------------

data EncodingMap = EncodingMap
  { encodeDomain   :: Dimension    -- dim(H_bulk input)
  , encodeCodomain :: Dimension    -- dim(H_horizon output)
  , encodeLabel    :: String
  } deriving (Show)

-- Isometry condition: codomain >= domain
isIsometry :: EncodingMap -> Bool
isIsometry e = dimValue (encodeCodomain e) >= dimValue (encodeDomain e)

-- ---------------------------------------------------------------------------
-- Scrambling map U_t : State -> State (must be unitary)
-- ---------------------------------------------------------------------------

data ScrambleMap = ScrambleMap
  { scrambleDim   :: Dimension    -- dim of Hilbert space it acts on
  , scrambleStep  :: Time
  , scrambleLabel :: String
  } deriving (Show)

-- Unitarity: input and output dimension are equal (necessary condition)
isUnitary :: ScrambleMap -> Bool
isUnitary _ = True   -- placeholder: full unitarity check requires matrix representation

-- ---------------------------------------------------------------------------
-- Recovery: given a shard set, can we recover a logical qubit?
-- ---------------------------------------------------------------------------

data RecoveryResult
  = Recovered  LogicalQubit   -- logical state recovered
  | Unrecoverable String      -- which information was lost and why
  | RecoveryUnresolved String -- method limit
  deriving (Show)

-- ---------------------------------------------------------------------------
-- Subsystem partition: interior, horizon, radiation
-- ---------------------------------------------------------------------------

data Partition = Partition
  { partInterior  :: Dimension
  , partHorizon   :: Dimension
  , partRadiation :: Dimension
  } deriving (Show)

totalDim :: Partition -> Integer
totalDim p = dimValue (partInterior p)
           * dimValue (partHorizon p)
           * dimValue (partRadiation p)

-- ---------------------------------------------------------------------------
-- Recoverability: logical information migrates between subsystems
-- under scrambling while total information is conserved.
-- "Cycle stealing" = reallocation of recoverability across encoding cycles.
-- NOT: physical theft of quantum states or clock cycles.
-- ---------------------------------------------------------------------------

data Recoverability = Recoverability
  { recTime        :: Time
  , recFromInterior :: Double   -- fraction recoverable from interior
  , recFromHorizon  :: Double   -- fraction recoverable from horizon
  , recFromRadiation :: Double  -- fraction recoverable from radiation
  } deriving (Show)

-- Conservation invariant: total recoverability = 1.0 at all times
-- (modulo mixed-state complications; 1.0 for pure states)
recoverabilityConserved :: Recoverability -> Bool
recoverabilityConserved r =
  abs (recFromInterior r + recFromHorizon r + recFromRadiation r - 1.0) < 1e-9
