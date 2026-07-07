set script_dir [file normalize [file dirname [info script]]]
set results_dir [file normalize [file join $script_dir ..]]
set repo_root [file normalize [file join $results_dir ..]]

set project_name OS_Exp_1
set project_file [file join $results_dir ${project_name}.xpr]
set part_name xc7a100tcsg324-1

if {[llength [get_projects -quiet]] == 0} {
    if {[file exists $project_file]} {
        open_project $project_file
    } else {
        create_project -force $project_name $results_dir -part $part_name
    }
}

set_property part $part_name [current_project]

set source_files {
    src/board/top.v
    src/board/data_ram.v
    src/cpu/ctrl_encode_def.v
    src/cpu/alu.v
    src/cpu/ctrl.v
    src/cpu/EXT.v
    src/cpu/NPC.v
    src/cpu/PC.v
    src/cpu/RF.v
    src/cpu/SCPU.v
    src/cpu/im.v
    src/io/Enter.v
    src/io/clk_div.v
    src/io/Counter_3_IO.v
    src/ip/MIO_BUS.V
    src/ip/MIO_BUS.edf
    src/ip/Multi_8CH32.v
    src/ip/Multi_8CH32.edf
    src/ip/SPIO.v
    src/ip/SPIO.edf
    src/ip/SSeg7.v
    src/ip/SSeg7.edf
    src/ip/dm_controller.v
    src/ip/dm_controller.edf
}

foreach rel $source_files {
    set abs [file normalize [file join $repo_root $rel]]
    if {![file exists $abs]} {
        error "Missing required source file: $abs"
    }
    if {[llength [get_files -quiet $abs]] == 0} {
        add_files -norecurse [list $abs]
    }
}

set constraint_file [file normalize [file join $repo_root constraints icf.xdc]]
if {![file exists $constraint_file]} {
    error "Missing constraint file: $constraint_file"
}
if {[llength [get_files -quiet $constraint_file]] == 0} {
    add_files -fileset constrs_1 -norecurse [list $constraint_file]
}

foreach rel {memory/Test_37_Instr8.dat memory/D_mem.dat} {
    set abs [file normalize [file join $results_dir $rel]]
    if {![file exists $abs]} {
        error "Missing board initialization file: $abs"
    }
    if {[llength [get_files -quiet $abs]] == 0} {
        add_files -norecurse [list $abs]
        set_property used_in_synthesis true [get_files $abs]
        set_property used_in_implementation true [get_files $abs]
    }
}

set_property top top [current_fileset]

set prep_script [file normalize [file join $script_dir prepare_run_memory.tcl]]
set_property STEPS.SYNTH_DESIGN.TCL.PRE $prep_script [get_runs synth_1]

update_compile_order -fileset sources_1
save_project_as -force $project_name $results_dir

puts "Configured Vivado project: $project_file"
puts "Top module: top"
puts "Part: $part_name"
puts "Next: run scripts/build_bitstream.tcl or launch synth_1/impl_1 in Vivado."
