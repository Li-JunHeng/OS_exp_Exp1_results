set script_dir [file normalize [file dirname [info script]]]
set results_dir [file normalize [file join $script_dir ..]]
set run_dir [pwd]

file mkdir [file join $run_dir memory]
foreach name {testac.dat D_mem.dat} {
    set src [file join $results_dir memory $name]
    if {![file exists $src]} {
        error "Missing memory initialization file: $src"
    }
    file copy -force $src [file join $run_dir memory $name]
}

puts "Copied memory initialization files into synthesis run directory: $run_dir/memory"
