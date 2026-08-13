# WORM Ledger Invariants

## Trust path

```
Payload
  → SHA256
  → MUMPS ^WORM
  → LockedRecord
  → HashChain
  → MerkleRoot
  → ExternalAnchor
```

Verification reverses it:

```
AnchorRoot =? Merkle(RecomputedChain(^WORM))
```

## INV-001 — PREFIX MONOTONICITY

```
Ledger_t ≼ Ledger_(t+1)
```

A valid transition may append records but cannot reorder or remove the existing prefix.

## INV-002 — LOCKED RECORD

```
locked(i) = 1
  =>
Mutate(i, field, value) = WORM_VIOLATION
```

## INV-003 — HASH BINDING

```
H_i = SHA256("WORMv1" || i || H_(i-1) || timestamp_i || payload_i)
```

## INV-004 — STRICT SEQUENCE

```
id_new = head + 1
```

## INV-005 — CHAIN CONTINUITY

```
prev_new = last_hash
```

## INV-006 — MERKLE COMMITMENT

```
Root = Merkle(H_1, H_2, ..., H_n)
```

Anchor file format:

```
WORM-ANCHOR-v1
records=N
root=<64-hex-merkle-root>
timestamp=<unix-time>
```

## Scope

Logical/API immutability. Physical-media immutability requires external controls.
The API surface enforces INV-001 through INV-006. Physical writes outside this
API are outside scope.
