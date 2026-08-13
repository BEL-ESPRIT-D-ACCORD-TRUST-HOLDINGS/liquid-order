#!/usr/bin/env tclsh

namespace eval worm {
    variable genesis "GENESIS"
    variable anchorFile [file normalize [file join [pwd] worm.anchor]]
}

proc worm::sha256 {s} {
    if {![catch {package require sha256}]} {
        return [string tolower [::sha2::sha256 -hex $s]]
    }

    set tmp [file tempfile fh]
    puts -nonewline $fh $s
    close $fh

    set out [exec openssl dgst -sha256 $tmp]
    file delete -force $tmp

    if {![regexp {= ([0-9A-Fa-f]+)$} $out -> h]} {
        error "unable to parse openssl sha256 output"
    }

    return [string tolower $h]
}

proc worm::ydb_eval {code} {
    if {[catch {exec ydb -run %XCMD $code} out opts]} {
        return -code error "YottaDB command failed: $out"
    }

    return [string trim $out]
}

proc worm::init {} {
    ydb_eval {D INIT^WORM W "OK",!}
}

proc worm::head {} {
    return [ydb_eval {W $$HEAD^WORM(),!}]
}

proc worm::last_hash {} {
    return [ydb_eval {W $$LASTHASH^WORM(),!}]
}

proc worm::escape_m {s} {
    # Escape double quotes for a MUMPS string literal.
    return [string map [list "\"" "\"\""] $s]
}

proc worm::commit {payload} {
    init

    set id   [expr {[head] + 1}]
    set prev [last_hash]
    set ts   [clock seconds]

    # Domain-separated chain hash.
    set material "WORMv1|$id|$prev|$ts|$payload"
    set h [sha256 $material]

    set p [escape_m $payload]

    set code [format \
        {W $$APPEND^WORM(%d,"%s","%s","%s",%d),!} \
        $id $p $prev $h $ts]

    set status [ydb_eval $code]

    if {$status ne "OK"} {
        error $status
    }

    return [dict create \
        id        $id   \
        prev      $prev \
        hash      $h    \
        timestamp $ts]
}

proc worm::get {id field} {
    set code [format \
        {W $$GET^WORM(%d,"%s"),!} \
        $id [escape_m $field]]

    return [ydb_eval $code]
}

proc worm::mutate_attempt {id field value} {
    set code [format \
        {W $$MUTATE^WORM(%d,"%s","%s"),!} \
        $id [escape_m $field] [escape_m $value]]

    return [ydb_eval $code]
}

proc worm::verify {} {
    init

    set n            [head]
    set expectedPrev $::worm::genesis
    set errors       {}

    for {set i 1} {$i <= $n} {incr i} {
        set data   [get $i data]
        set prev   [get $i prev]
        set h      [get $i hash]
        set ts     [get $i ts]
        set locked [get $i locked]

        if {$locked ne "1"} {
            lappend errors [dict create id $i error unlocked]
        }

        if {$prev ne $expectedPrev} {
            lappend errors [dict create \
                id       $i            \
                error    prev_mismatch \
                expected $expectedPrev \
                actual   $prev]
        }

        set recomputed [sha256 "WORMv1|$i|$prev|$ts|$data"]

        if {$recomputed ne $h} {
            lappend errors [dict create \
                id       $i            \
                error    hash_mismatch \
                expected $recomputed   \
                actual   $h]
        }

        set expectedPrev $h
    }

    if {[llength $errors] == 0 &&
        [last_hash] ne $expectedPrev} {

        lappend errors [dict create \
            error    tail_mismatch \
            expected $expectedPrev \
            actual   [last_hash]]
    }

    return [dict create \
        ok      [expr {[llength $errors] == 0}] \
        records $n                               \
        errors  $errors                          \
        tail    $expectedPrev]
}

proc worm::merkle_pair {a b} {
    return [sha256 "MERKLEv1|$a|$b"]
}

proc worm::merkle_root {} {
    set n [head]

    if {$n == 0} {
        return [sha256 "MERKLEv1|EMPTY"]
    }

    set layer {}

    for {set i 1} {$i <= $n} {incr i} {
        lappend layer [get $i hash]
    }

    while {[llength $layer] > 1} {
        set next {}

        for {set i 0} {$i < [llength $layer]} {incr i 2} {
            set a [lindex $layer $i]

            if {$i + 1 < [llength $layer]} {
                set b [lindex $layer [expr {$i + 1}]]
            } else {
                set b $a
            }

            lappend next [merkle_pair $a $b]
        }

        set layer $next
    }

    return [lindex $layer 0]
}

proc worm::anchor_write {{path ""}} {
    if {$path eq ""} {
        set path $::worm::anchorFile
    }

    set root [merkle_root]

    set fh [open $path w]
    puts $fh "WORM-ANCHOR-v1"
    puts $fh "records=[head]"
    puts $fh "root=$root"
    puts $fh "timestamp=[clock seconds]"
    close $fh

    return $root
}

proc worm::anchor_verify {{path ""}} {
    if {$path eq ""} {
        set path $::worm::anchorFile
    }

    if {![file exists $path]} {
        error "anchor file not found: $path"
    }

    set fh      [open $path r]
    set content [read $fh]
    close $fh

    if {![regexp {root=([0-9a-f]+)} $content -> anchored]} {
        error "invalid anchor format"
    }

    set current [merkle_root]

    return [dict create \
        ok       [expr {$anchored eq $current}] \
        anchored $anchored                       \
        current  $current]
}

proc worm::usage {} {
    puts "worm.tcl commit <payload>"
    puts "worm.tcl get <id> <field>"
    puts "worm.tcl verify"
    puts "worm.tcl mutate <id> <field> <value>"
    puts "worm.tcl merkle"
    puts "worm.tcl anchor-write ?file?"
    puts "worm.tcl anchor-verify ?file?"
}

if {[info exists argv0] &&
    [file normalize $argv0] eq [file normalize [info script]]} {

    if {[llength $argv] == 0} {
        worm::usage
        exit 2
    }

    set cmd [lindex $argv 0]

    switch -- $cmd {
        commit {
            puts [worm::commit [join [lrange $argv 1 end] " "]]
        }
        get {
            puts [worm::get [lindex $argv 1] [lindex $argv 2]]
        }
        verify {
            puts [worm::verify]
        }
        mutate {
            puts [worm::mutate_attempt \
                [lindex $argv 1] \
                [lindex $argv 2] \
                [join [lrange $argv 3 end] " "]]
        }
        merkle {
            puts [worm::merkle_root]
        }
        anchor-write {
            puts [worm::anchor_write [lindex $argv 1]]
        }
        anchor-verify {
            puts [worm::anchor_verify [lindex $argv 1]]
        }
        default {
            worm::usage
            exit 2
        }
    }
}
