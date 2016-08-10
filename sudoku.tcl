#!/usr/bin/tclsh


proc print_board { board } {
  if { $board == {} } {
    puts "Unable to solve."

  } else {
    foreach row $board {
      puts $row
    }
  }
}


proc flip { board } {
  set columns {{} {} {} {} {} {} {} {} {}}

  for {set c 0} {$c < 9} {incr c} {
    for {set r 0} {$r < 9} {incr r} {
      sub_lappend columns $c [lindex [lindex $board $r] $c]
    }
  }

  return $columns
}


proc rotate { board } {
  set squares {{} {} {} {} {} {} {} {} {}}

  for {set r 0} {$r < 9} {incr r} {
    for {set c 0} {$c < 9} {incr c} {
      set sq [expr {int(floor($r/3)) * 3 + int(floor($c/3))}]
      sub_lappend squares $sq [lindex [lindex $board $r] $c]
    }
   }

  return $squares
}


# -- helper for appending to a sublist
proc sub_lappend { listname idx args } {
  upvar 1 $listname l
  set subl [lindex $l $idx]
  lappend subl {*}$args
  lset l $idx $subl
}


# -- gets all the picks from each row
proc get_picks {row} {
  set picks {}
  foreach cell $row {
    if { [llength $cell] == 1 } {
      lappend picks $cell
    }
  }
  return [lsort -integer $picks]
}


proc eliminate_picks { board } {
  set r -1
  foreach row $board {
    incr r
    #puts "new row. removing picks from $row"
    set c -1
    foreach cell $row  {
    incr c
      if { [llength $cell] == 1 } {
        #puts "row: $row"
        #puts "removing pick: $cell (found at c: $c)"
        #read stdin 1
        for { set cx 0 } { $cx < 9 } {incr cx} {
          if { $cx != $c } {
            set filtered [lsearch -all -inline -not -exact [lindex $row $cx] $cell]
            set row [lreplace $row $cx $cx $filtered]
          }
        }
      }
    }

    set board [lreplace $board $r $r $row]
  }
  return $board
}



# -- find subsets of N numbers that exist in exactly N cells
# -- and remove that subset of numbers from the rest of the cells
proc find_subset { unit } {
  foreach search $unit {
    set len [llength $search]
    if { $len > 1 } {
      set results [lsearch -all $unit $search]
      if { [llength $results] == $len } {
        return [list $search]
       } 
    }
  }
  return {}
}

proc eliminate_subsets { board } {
  set r -1
  foreach row $board {
    incr r
    foreach subset [find_subset $row] {

      #puts "Found matches for $subset"
      #puts "No other cells should have $subset in them..."

      for {set c 0} {$c < 9} {incr c} {
        if {[lindex $row $c] != $subset} {
          set cell [lindex $row $c]
          foreach pick $subset {
            set cell [lsearch -all -inline -not -exact $cell $pick]
            set row [lreplace $row $c $c $cell]
          }
        }
      }

      set board [lreplace $board $r $r $row]
    }

 }
  
  return $board
}


proc basic { board } {
  #puts "trying basic method"
  set old {}
  while { $old != $board && [done $board] != 1} {
    set old $board

    set board [eliminate_picks $board]
    set board [flip [eliminate_picks [flip $board]]]
    set board [rotate [eliminate_picks [rotate $board]]]
  }

  #puts "basic approach only worked for $i iterations"
  return $board
}

proc subsets { board } {
  #puts "trying subset detection"

  set old {}
  while { $old != $board && [done $board] != 1} {
    set old $board

    set board [eliminate_subsets $board]
    set board [flip [eliminate_subsets [flip $board]]]
    set board [rotate [eliminate_subsets [rotate $board]]]
  }

  return $board
}

#
# -- "hidden" detection

proc find_hidden { board } {
  set r -1
  foreach unit $board {
    incr r
    set picks [get_picks $unit]

    foreach q {1 2 3 4 5 6 7 8 9} {
      set count 0
      if {[lsearch -sorted $picks $q] >= 0 } {
        # nop
      } else {
        foreach cell $unit {
          if { [llength $cell] > 1 && [lsearch -sorted $cell $q] >= 0 } {
            incr count
          }
       }
     }
     if { $count == 1 } {
       set c -1
       foreach cell $unit {
         incr c
         if { [llength $cell] > 1 && [lsearch -sorted $cell $q] >= 0 } {
           set unit [lreplace $unit $c $c $q]
         }
       }
       set board [lreplace $board $r $r $unit]
     }
    }
  }

  return $board
}


proc hidden { board } {
  set old {}

  while { $old != $board } {
    set old $board

    set board [find_hidden $board]
    set board [flip [find_hidden [flip $board]]]
    set board [rotate [find_hidden [rotate $board]]]
  }

  return $board
}

proc invalid { board } {
  if { [llength $board] == 0 } {
    return 1
  }

  foreach row $board {
    foreach cell $row {
      if {[llength $cell] == 0} {
        return 1
      }
    }
  }

  return 0
}



proc done { board } {
  if { [llength $board] == 0 } {
    return 0
  }

  foreach row $board {
    foreach cell $row {
      if {[llength $cell] != 1} {
        return 0
      }
    }
  }
  return 1
}


proc algorithms { board } {
  set old {}
  while { $old != $board && [invalid $board] != 1} {
    set old $board

    set board [basic $board]

    if { [done $board] } {
      break
    }

    set board [subsets $board]

    if { [done $board] } {
      break
    }

    set board [hidden $board]

    if { [done $board] } {
      break
    }
  }

  return $board
}



proc solve { board } {

  if { [invalid $board] == 1 } {
    return {}
  }

  if { [done $board] } {
    return $board
  }

  # -- do all our algorithms that we know
  set board [algorithms $board]

  if { [done $board] } {
    return $board

  } else {
    # -- we have to start guessing

    set r -1
    foreach row $board {
      incr r

      set c -1
      foreach cell $row {
        incr c

        if {[llength $cell] > 1} {

          # only advantage taken...
          foreach guess [lreverse $cell] {
            set guess_board [solve [lreplace $board $r $r [lreplace $row $c $c $guess]]]

            if { $guess_board != {} } {
              return $guess_board
            }
          }
        }
      }
    }

    # -- guessing didn't work, we return an empty list
    return {}
  }
}


proc read_gameboard { } {
  global argv

  # -- read in the gameboard
  set filename [lindex $argv 0]
  set fp [open $filename r]
  set lines [split [read $fp] "\n"]
  close $fp

  set board {{} {} {} {} {} {} {} {} {}}

  # -- parse the rows into the gameboard
  set row 0
  foreach line $lines {
    foreach cell [split $line] {
      if { [string trim $cell] ne "" } {
        if { $cell eq "x" } {
          sub_lappend board $row {1 2 3 4 5 6 7 8 9}
        } else {
          sub_lappend board $row $cell
        }
      }
    }
    incr row
  }

  return $board
}

# this is it.
print_board [solve [read_gameboard]]


