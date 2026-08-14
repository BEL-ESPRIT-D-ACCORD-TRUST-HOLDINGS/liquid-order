# Proof Certificates

Each `.cert.json` file records a discharged proof obligation from the Sovereign-Covenant theorem registry.

## Status

| ID | Theorem | Proof Method | Status |
|----|---------|-------------|--------|
| LO-SC-003 | `∀ A B. A →* B → N(A)=N(B)` | Agda structural induction | PROVED |
| LO-SC-004 | `EquivalenceRelation(EquivalentN)` | Agda refl/sym/trans | PROVED |
| LO-SC-005 | `N(A)=N(B) → F(N(A))=F(N(B))` | Agda congruence | PROVED |

## Pending

LO-SC-001, LO-SC-002, LO-SC-006 through LO-SC-010 remain `Unresolved`.
These require the concrete Γ_SC instantiation audit per `spec/PROTOCOL_v1.md`.

## Certificate Format

Each certificate records:
- `theorem_id`: Registry ID from `Obligations.hs`
- `proof_term`: The Agda/Lean term that discharges the goal
- `status`: `PROVED` | `UNRESOLVED` | `REFUTED`
- `sorry_count`: Must be 0 for PROVED status
- `holes_count`: Must be 0 for PROVED status
- `cert_hash_sha3_256`: BLAKE3 hash of the proof file (replace placeholder before blind execution)
