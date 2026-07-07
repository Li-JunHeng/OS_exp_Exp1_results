set script_dir [file normalize [file dirname [info script]]]
set results_dir [file normalize [file join $script_dir ..]]

source [file join $script_dir setup_project.tcl]

reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "synth_1 did not complete successfully"
}

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "impl_1 did not complete successfully"
}

open_run impl_1
file mkdir [file join $results_dir reports]
report_utilization -file [file join $results_dir reports utilization_post_route.rpt]
report_timing_summary -file [file join $results_dir reports timing_summary_post_route.rpt]

set run_bit [file join $results_dir OS_Exp_1.runs impl_1 top.bit]
if {![file exists $run_bit]} {
    error "Bitstream was not generated at expected path: $run_bit"
}

file mkdir [file join $results_dir bitstream]
set final_bit [file join $results_dir bitstream OS_Exp_1_top.bit]
file copy -force $run_bit $final_bit

puts "Bitstream ready: $final_bit"
puts "Next: connect the Nexys A7 board and run scripts/program_board.tcl."
