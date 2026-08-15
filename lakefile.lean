-- Lake build configuration for SNAPKITTYWEST
-- SEIT Certified | Tier III Igneous
-- WORM: bifrost:4b565498-9afc-4782-af4a-c6b11a5d0058
-- Lean 4.8.0 | Mathlib4 | HOL Light compatibility

import Lake
open Lake DSL

package SnapKitty where
  name    := "SnapKitty"
  version := "1.0.0"

-- Dependencies
require mathlib from git
  "https://github.com/leanprover-community/mathlib4" @ "4.8.0"

require batteries from git
  "https://github.com/leanprover-community/batteries" @ "main"

-- Libraries
lean_lib SnapKittyTheoremBook where
  srcDir := "SnapKitty/TheoremBook"
  globs  := #[.andSubmodules `SnapKitty.TheoremBook]

lean_lib SnapKittyQuantum where
  srcDir := "SnapKitty/Quantum"
  globs  := #[.andSubmodules `SnapKitty.Quantum]

lean_lib SnapKittyStorage where
  srcDir := "SnapKitty/Storage"
  globs  := #[.andSubmodules `SnapKitty.Storage]

-- Verification executables
lean_exe seit_verify where
  root := `Scripts.Verify

lean_exe seit_audit where
  root := `Scripts.Audit

-- Custom targets (run via: lake script run <target>)
-- hol_light_check  : hol_light -script RH_F2_QuantumCelestial.ml
-- seit_certify     : lake build seit_verify && ./build/bin/seit_verify
-- worm_commit      : scripts/worm_commit.sh  (after seit_certify passes)
