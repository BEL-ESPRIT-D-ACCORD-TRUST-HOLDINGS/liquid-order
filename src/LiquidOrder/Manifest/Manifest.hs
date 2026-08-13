-- LiquidOrder: Theorem manifest
--
-- Generates the machine-readable manifest after kernel replay.
-- The build MUST fail if any REQUIRED theorem is not PROVED.
-- The manifest is the authoritative record of verification state.

module LiquidOrder.Manifest.Manifest
  ( Manifest(..)
  , buildManifest
  , checkBuildConstraints
  , renderManifestJSON
  , renderManifestText
  ) where

import LiquidOrder.Epistemic.Types
import LiquidOrder.Kernel.Certificate (ProofCertificate, ReplayResult(..), kernelReplay, digestCertificate)
import LiquidOrder.SovereignCovenant.Obligations (allObligations)
import Data.List (intercalate)

-- ---------------------------------------------------------------------------
-- Manifest type
-- ---------------------------------------------------------------------------

data Manifest = Manifest
  { manifestEntries :: [ManifestEntry]
  , manifestErrors  :: [String]    -- build failures (non-empty = build fails)
  , manifestVersion :: String
  } deriving (Show)

-- ---------------------------------------------------------------------------
-- Build manifest by replaying all available certificates
-- ---------------------------------------------------------------------------

buildManifest :: [(String, ProofCertificate)] -> Manifest
buildManifest certMap =
  let entries = map (resolveEntry certMap) allObligations
      errors  = concatMap collectErrors entries
  in Manifest
       { manifestEntries = entries
       , manifestErrors  = errors
       , manifestVersion = "v2"
       }

resolveEntry :: [(String, ProofCertificate)] -> TheoremRecord -> ManifestEntry
resolveEntry certMap tr =
  case lookup (trId tr) certMap of
    Nothing ->
      ManifestEntry
        { meId           = trId tr
        , meProposition  = trProposition tr
        , meAssumptions  = trAssumptions tr
        , meDependencies = trDependencies tr
        , meCertDigest   = "NONE"
        , meKernelStatus = statusLabel (trStatus tr)
        , meRequired     = trRequired tr
        }
    Just cert ->
      let replayResult = kernelReplay cert
          digest       = digestCertificate cert
          status       = case replayResult of
                           ReplayValid _    -> Proved
                           ReplayInvalid _  -> Refuted
                           ReplayUnresolved _ -> Unresolved
      in ManifestEntry
           { meId           = trId tr
           , meProposition  = trProposition tr
           , meAssumptions  = trAssumptions tr
           , meDependencies = trDependencies tr
           , meCertDigest   = show digest
           , meKernelStatus = statusLabel status
           , meRequired     = trRequired tr
           }

collectErrors :: ManifestEntry -> [String]
collectErrors entry
  | meRequired entry && meKernelStatus entry /= "PROVED" =
      [ "BUILD FAILURE: required theorem "
        ++ meId entry
        ++ " has kernel status "
        ++ meKernelStatus entry
        ++ " (certificate required)"
      ]
  | otherwise = []

-- ---------------------------------------------------------------------------
-- Build constraint check — returns Left errors if build should fail
-- ---------------------------------------------------------------------------

checkBuildConstraints :: Manifest -> Either [String] ()
checkBuildConstraints m
  | null (manifestErrors m) = Right ()
  | otherwise               = Left (manifestErrors m)

-- ---------------------------------------------------------------------------
-- Render manifest as JSON (hand-rolled; no aeson dependency needed yet)
-- ---------------------------------------------------------------------------

renderManifestJSON :: Manifest -> String
renderManifestJSON m = unlines
  [ "{"
  , "  \"version\": " ++ show (manifestVersion m) ++ ","
  , "  \"build_ok\": " ++ (if null (manifestErrors m) then "true" else "false") ++ ","
  , "  \"theorems\": ["
  , intercalate ",\n" (map renderEntryJSON (manifestEntries m))
  , "  ],"
  , "  \"errors\": [" ++ intercalate ", " (map show (manifestErrors m)) ++ "]"
  , "}"
  ]

renderEntryJSON :: ManifestEntry -> String
renderEntryJSON e = unlines
  [ "    {"
  , "      \"id\": "           ++ show (meId e) ++ ","
  , "      \"proposition\": "  ++ show (meProposition e) ++ ","
  , "      \"assumptions\": "  ++ showList' (meAssumptions e) ++ ","
  , "      \"dependencies\": " ++ showList' (meDependencies e) ++ ","
  , "      \"cert_digest\": "  ++ show (meCertDigest e) ++ ","
  , "      \"kernel_status\": " ++ show (meKernelStatus e) ++ ","
  , "      \"required\": "     ++ (if meRequired e then "true" else "false")
  , "    }"
  ]

showList' :: [String] -> String
showList' xs = "[" ++ intercalate ", " (map show xs) ++ "]"

-- ---------------------------------------------------------------------------
-- Render manifest as human-readable text
-- ---------------------------------------------------------------------------

renderManifestText :: Manifest -> String
renderManifestText m = unlines $
  [ "=== LiquidOrder Theorem Manifest " ++ manifestVersion m ++ " ==="
  , ""
  , "ID            STATUS          REQUIRED  CERT DIGEST"
  , replicate 70 '-'
  ]
  ++ map renderEntryText (manifestEntries m)
  ++ [ replicate 70 '-'
     , ""
     , "Build: " ++ if null (manifestErrors m) then "OK" else "FAILED"
     ]
  ++ if null (manifestErrors m) then []
     else [""] ++ manifestErrors m

renderEntryText :: ManifestEntry -> String
renderEntryText e =
  padR 14 (meId e)
  ++ padR 16 (meKernelStatus e)
  ++ padR 10 (if meRequired e then "YES" else "no")
  ++ take 24 (meCertDigest e)

padR :: Int -> String -> String
padR n s = s ++ replicate (max 0 (n - length s)) ' '
