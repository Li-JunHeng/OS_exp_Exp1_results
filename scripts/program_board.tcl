set script_dir [file normalize [file dirname [info script]]]
set results_dir [file normalize [file join $script_dir ..]]

set default_bit [file join $results_dir bitstream OS_Exp_1_top.bit]
set fallback_bit [file join $results_dir OS_Exp_1.runs impl_1 top.bit]

if {[info exists ::env(BIT_FILE)] && [file exists $::env(BIT_FILE)]} {
    set bit_file [file normalize $::env(BIT_FILE)]
} elseif {[file exists $default_bit]} {
    set bit_file [file normalize $default_bit]
} elseif {[file exists $fallback_bit]} {
    set bit_file [file normalize $fallback_bit]
} else {
    error "No bitstream found. Run scripts/build_bitstream.tcl first."
}

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set devices [get_hw_devices xc7a100t*]
if {[llength $devices] == 0} {
    set devices [get_hw_devices]
}
if {[llength $devices] == 0} {
    error "No hardware device found. Check USB cable, board power, and Vivado cable drivers."
}

set device [lindex $devices 0]
current_hw_device $device
refresh_hw_device $device
set_property PROGRAM.FILE $bit_file $device
program_hw_devices $device
refresh_hw_device $device

puts "Programmed $device with $bit_file"
