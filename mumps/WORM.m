WORM ; YottaDB/MUMPS WORM ledger
 ; Logical append-only API. Physical storage can still be altered outside this routine.
 ;
 ; Globals:
 ; ^WORM("head") = latest sequence id
 ; ^WORM("last_hash") = latest chain hash
 ; ^WORM(id,"data") = payload
 ; ^WORM(id,"prev") = previous hash
 ; ^WORM(id,"hash") = current hash
 ; ^WORM(id,"locked") = 1
 ; ^WORM(id,"ts") = timestamp
 ; ^WORM("hash",hash) = id
 ;
 Q

INIT ; initialize metadata if absent
 I '$D(^WORM("head")) S ^WORM("head")=0
 I '$D(^WORM("last_hash")) S ^WORM("last_hash")="GENESIS"
 Q

EXISTS(ID) ; extrinsic: record exists
 Q $D(^WORM(ID,"locked"))

GET(ID,FIELD) ; extrinsic: get field
 Q $G(^WORM(ID,FIELD))

HEAD() ; extrinsic: current head
 D INIT
 Q +$G(^WORM("head"))

LASTHASH() ; extrinsic: current tail hash
 D INIT
 Q $G(^WORM("last_hash"))

APPEND(ID,PAYLOAD,PREV,HASH,TS) ; append immutable record
 N CUR
 D INIT
 L +^WORM("append"):10 E  Q "LOCK_TIMEOUT"

 ; Reject duplicate sequence ID or duplicate hash.
 I $D(^WORM(ID)) L -^WORM("append") Q "WORM_VIOLATION:ID_EXISTS"
 I $D(^WORM("hash",HASH)) L -^WORM("append") Q "WORM_VIOLATION:HASH_EXISTS"

 S CUR=+$G(^WORM("head"))

 ; Enforce strict monotone sequence.
 I ID'=(CUR+1) L -^WORM("append") Q "SEQUENCE_VIOLATION"

 ; Enforce chain continuity.
 I PREV'=$G(^WORM("last_hash")) L -^WORM("append") Q "CHAIN_HEAD_MISMATCH"

 ; Write record fields.
 S ^WORM(ID,"data")=PAYLOAD
 S ^WORM(ID,"prev")=PREV
 S ^WORM(ID,"hash")=HASH
 S ^WORM(ID,"ts")=TS

 ; Lock marker is written last.
 S ^WORM(ID,"locked")=1

 ; Reverse hash index.
 S ^WORM("hash",HASH)=ID

 ; Advance chain head.
 S ^WORM("head")=ID
 S ^WORM("last_hash")=HASH

 L -^WORM("append")
 Q "OK"

MUTATE(ID,FIELD,VALUE) ; reject mutation
 I $G(^WORM(ID,"locked"))=1 Q "WORM_VIOLATION:LOCKED"
 Q "WORM_VIOLATION:NO_MUTATION_API"

DUMP ; human-readable dump
 N I,H
 D INIT
 S H=+$G(^WORM("head"))
 F I=1:1:H W I,"|",$G(^WORM(I,"prev")),"|",$G(^WORM(I,"hash")),"|",$G(^WORM(I,"ts")),"|",$G(^WORM(I,"data")),!
 Q

RESET ; TEST ONLY
 K ^WORM
 D INIT
 Q
