#!/usr/bin/env tclsh

source [file join [file dirname [info script]] worm.tcl]

set workers 1024

if {[llength $argv] >= 1} {
    set workers [lindex $argv 0]
}

if {[worm::head] == 0} {
    worm::commit "seed-record"
}

set rejected   0
set unexpected 0
set samples    {}

for {set i 0} {$i < $workers} {incr i} {

    set status [worm::mutate_attempt 1 data "mutation-$i"]

    if {[string match "WORM_VIOLATION:*" $status]} {
        incr rejected
    } else {
        incr unexpected
        if {[llength $samples] < 10} {
            lappend samples [list $i $status]
        }
    }
}

set verify [worm::verify]

set invariant [dict create \
    attempted_mutations $workers                                         \
    rejected_mutations  $rejected                                        \
    unexpected_accepts  $unexpected                                      \
    chain_valid         [dict get $verify ok]                            \
    records             [dict get $verify records]                       \
    invariant           "Locked records are immutable through the exposed API; all attempted post-lock mutations were rejected" \
    scope               "logical/API WORM, not physical-media immutability"]

puts $invariant

if {$unexpected != 0 || ![dict get $verify ok]} {
    exit 1
}
