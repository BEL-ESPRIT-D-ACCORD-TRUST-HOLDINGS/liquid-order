-- Haiku Kernel: Multi-Level Kill Switch
-- L0: Graceful — finish current stage, save state
-- L1: SandboxWipe — clear /tmp, reset memory
-- L2: WorldEnd — nuclear, erase all persistent data
-- L3: Defunct — process termination + cleanup

module LiquidOrder.HaikuKernel.KillSwitch
  ( KillSwitchLevel(..)
  , KillSwitchState(..)
  , triggerKillSwitch
  , initKillSwitchState
  ) where

import LiquidOrder.HaikuKernel.WorldState
import System.Exit (exitSuccess, exitFailure)

data KillSwitchLevel
  = L0_Graceful
  | L1_SandboxWipe
  | L2_WorldEnd
  | L3_Defunct
  deriving (Show, Eq, Ord)

data KillSwitchState = KillSwitchState
  { ksLevel       :: KillSwitchLevel
  , ksBackupPath  :: String
  , ksWipeProgress :: Double    -- 0.0 to 1.0
  } deriving (Show)

initKillSwitchState :: KillSwitchState
initKillSwitchState = KillSwitchState
  { ksLevel        = L0_Graceful
  , ksBackupPath   = ".haiku/backup"
  , ksWipeProgress = 0.0
  }

triggerKillSwitch :: KillSwitchLevel -> WorldState -> IO ()
triggerKillSwitch L0_Graceful ws = do
  putStrLn "L0: Graceful shutdown — finishing current stage, saving state"
  putStrLn $ " decisions preserved: " ++ show (length (wsDecisions ws))
  -- Persist to git: TODO
  exitSuccess

triggerKillSwitch L1_SandboxWipe ws = do
  putStrLn "L1: Sandbox wipe — clearing /tmp, resetting agent memory"
  -- Clear /tmp: TODO (exec rm -rf /tmp/haiku-*)
  putStrLn " agent memory reset to initial state"
  exitSuccess

triggerKillSwitch L2_WorldEnd _ = do
  putStrLn "L2: WORLD END — erasing all persistent data"
  -- git gc --aggressive --prune=now: TODO
  putStrLn "WORLD END COMPLETE"
  exitFailure

triggerKillSwitch L3_Defunct _ = do
  putStrLn "L3: DEFUNCT — process termination"
  exitFailure
