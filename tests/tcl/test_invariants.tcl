#!/usr/bin/env tclsh

source [file join [file dirname [info script]] .. .. tcl worm.tcl]

proc assert {cond msg} {
    if {![uplevel 1 [list expr $cond]]} {
        error "ASSERTION FAILED: $msg"
    }
}

# Reset — test only.
worm::ydb_eval {D RESET^WORM W "OK",!}

set c1 [worm::commit "alpha"]
set c2 [worm::commit "beta"]

set v [worm::verify]

assert {[dict get $v ok] == 1} \
    "fresh chain must verify"

assert {[dict get $v records] == 2} \
    "expected two records"

set m [worm::mutate_attempt 1 data "evil"]

assert {[string match "WORM_VIOLATION:*" $m]} \
    "mutation must be rejected"

set r [worm::merkle_root]

assert {[string length $r] == 64} \
    "merkle root must be sha256 hex"

puts "PASS"
