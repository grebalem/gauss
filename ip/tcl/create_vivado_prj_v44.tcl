# Script to create Vivado project v4.4
#
# Revision history:
#
# v1.0 - Initial release
# v1.1 - Added txt files to the list of sources 
# v1.2 - Added top_wrapper.v as name for the top file
#        removed txt files from the list of sources 
#        added IP revision check 
# v2.0 - Corrected creation of SrcXCI variable
# v2.1 - Added configurable number of jobs
# v2.2 - Added some extra options to synthesis config  
# v2.3 - Added parameter to specify current Synth and Impl, added some more options to Synth and Impl 
# v2.4 - Corrected insertion of IPs into the project 
# v2.5 - Changed location of output dir. Now it's at the same level as src
#        Added copy of bit,bin,ltx files into output dir
# v2.6 - Corrected comment about Vivado output dir
# v2.7 - Changed IP dir location within Vivado hierarchy to comply with Vivado project mode
# v2.8 - Added multiple implementation runs based on content of ila_constr directory
# v2.9 - Made some minor changes to multiple run flow
# v3.0 - Changed format of ila constraints to *.tcl (instead of *.xdc) as xdc format does not support some tcl commands (for example lsort)
# v3.1 - Added implementation constraints
# v3.2 - Fix when implementation constraints where not added with no ila in design
# v3.3 - Added implementation reports
# v3.4 - Added multiple runs with different properties based on one parent implementation run
# v3.5 - Run pre_synthesis hooks (tcl scripts stored in pre_synth_hooks folder)
# v3.6 - Added bin file generation to derivative Implementation Strategies 
# v3.7 - Added BD support
# v3.8 - Added brief report to the set of reports
# v3.9 - Added print to console name of top file
# v4.0 - Corrected set of parameters displayed in brief report
# v4.1 - Added various Synth Strategies support
# v4.2 - Added post implementation critical path's report
# v4.3 - Added system time of compilation to the brief report
# v4.4 - Added support for IP generation from script
#
# Script must be run in Vivado
# Description of some rules of the file in the section "Notes"
#
#
# ----------------------------------Notes--------------------------------------
# Top file must be in src directory and have name in format *_top.* or top_wrapper.v 
# Name of the top module must be the same as name of the top file - i.e mod_top.v -> module mod_top{}
#
# All IP's must be stored in "ip" directory (at the same level as src) in *.xci files
# All xci files must be in one directory. During project creation subdir "impl/ip" created where subdirectory 
# for each IP is created (if several IP's stored in one directory Vivado locks them)
#
# Simulation files must be stored in ./src/TestBench directory 
#
# Constraints must be stored in src/constr directory  
# Constraints used only in implementation must be stored in src/constr/impl directory in *.tcl format
# ILA constraints must be stored in ./ila_constr dir (at the same level as src). One ila*.tcl file is for one implementation run
#
# Pre-synthesis hooks must be stored in ./pre_synth_hooks directory in *.tcl format 
#
# Need to ajdust Vivado Implementation for Vivado version being used (need to adjust year)
# 
# Directory named "impl" created for Vivado implementation
# Results written into directory ${Vivado_OutDir}
#
# If multiple implementation strategies to be implemented they need to be added to variable Impl_Strategies
# in form "Strategy1 Strategy2 ... Strategy_n" (names of strategies separated by spaces)
# If no various implementation strategies to be explored this variable must be in form Impl_Strategies ""
# -------------------------------End of notes----------------------------------
#
# --------------------Procedures---------------------------------
#
# ----------Procedure to find files in dir and subdirs-----------
proc findFiles { basedir pattern } {

    # Fix the directory name, this ensures the directory name is in the
    # native format for the platform and contains a final directory seperator
    set basedir [string trimright [file join [file normalize $basedir] { }]]
    set fileList {}
    array set myArray {}
    
    # Look in the current directory for matching files, -type {f r}
    # means ony readable normal files are looked at, -nocomplain stops
    # an error being thrown if the returned list is empty

    foreach fileName [glob -nocomplain -type {f r} -path $basedir $pattern] {
        lappend fileList $fileName
    }
    
    # Now look for any sub direcories in the current directory
    foreach dirName [glob -nocomplain -type {d  r} -path $basedir *] {
        # Recusively call the routine on the sub directory and append any
        # new files to the results
        # put $dirName
        set subDirList [findFiles $dirName $pattern]
        if { [llength $subDirList] > 0 } {
            foreach subDirFile $subDirList {
                lappend fileList $subDirFile
            }
        }
    }
    return $fileList
}
# --------------------------------End of procedure-----------------------------
# ------------------------------------------------------------------------
# reportCriticalPaths
# ------------------------------------------------------------------------
# This function generates a CSV file that provides a summary of the first
# 50 violations for both Setup and Hold analysis. So a maximum number of
# 100 paths are reported.
# ------------------------------------------------------------------------
proc reportCriticalPaths { fileName } {
# Open the specified output file in write mode
set FH [open $fileName w]
# Write the current date and CSV format to a file header
puts $FH "#\n# File created on [clock format [clock seconds]]\n#\n"
puts $FH "Startpoint,Endpoint,DelayType,Slack,#Levels,#LUTs"
# Iterate through both Min and Max delay types
foreach delayType {max min} {
# Collect details from the 50 worst timing paths for the current analysis
# (max = setup/recovery, min = hold/removal)
# The $path variable contains a Timing Path object.
foreach path [get_timing_paths -delay_type $delayType -max_paths 50 -nworst 1] {
# Get the LUT cells of the timing paths
set luts [get_cells -filter {REF_NAME =~ LUT*} -of_object $path]
# Get the startpoint of the Timing Path object
set startpoint [get_property STARTPOINT_PIN $path]
# Get the endpoint of the Timing Path object
set endpoint [get_property ENDPOINT_PIN $path]
# Get the slack on the Timing Path object
set slack [get_property SLACK $path]
# Get the number of logic levels between startpoint and endpoint
set levels [get_property LOGIC_LEVELS $path]
# Save the collected path details to the CSV file
puts $FH "$startpoint,$endpoint,$delayType,$slack,$levels,[llength $luts]"
}
}
# Close the output file
close $FH
puts "CSV file $fileName has been created.\n"
return 0
}; 
# ---------------------------------End PROC------------------------------------
#
# -------------------End of procedures----------------------------------------- 
#
# -----------------------------------------------------------------------------
# ------------------------------Start of routine-------------------------------
# -----------------------------------------------------------------------------
#
#Specify FPGA for the project
set FPGA_name "xc7k325tffg900-2L"
# Synth strategies cannot be empty - at least one strategy must be entered!
set Synth_Strategies "{Vivado Synthesis Defaults}"
#set Synth_Strategies "Flow_PerfThresholdCarry Flow_RuntimeOptimized"
#set Synth_Strategies "Flow_AlternateRoutability"
#set Synth_Strategies "Flow_PerfOptimized_high"
#set Synth_Strategies "Flow_AreaOptimized_medium Flow_AreaMultThresholdDSP Flow_AlternateRoutability Flow_PerfOptimized_high Flow_PerfThresholdCarry Flow_RuntimeOptimized"   
#
# Impl strategies can be empty - in this case only one run with default settings generated. But at least one line must be uncommented! 
#set Impl_Strategies "Performance_Auto_1 Performance_ExtraTimingOpt Performance_Auto_3 Congestion_SpreadLogic_high"
#set Impl_Strategies "Area_Explore Performance_BalanceSLRs Congestion_SSI_SpreadLogic_high Performance_ExtraTimingOpt Performance_Auto_3 Congestion_SpreadLogic_high"
#set Impl_Strategies "Performance_ExtraTimingOpt  Performance_Auto_3  Performance_Auto_2 Performance_Auto_1 Congestion_SpreadLogic_high Performance_NetDelay_high Performance_ExplorePostRoutePhysOpt Performance_RefinePlacement"
#set Impl_Strategies "Performance_Auto_1 Power_ExploreArea Performance_BalanceSLRs"	 
# For Vivado 2025.1
#set Impl_Strategies "Performance_ExplorePostRoutePhysOpt Performance_RefinePlacement"
set Impl_Strategies ""
#
# Define number of CPUs to be used by synthesis and implementation
set NumJobs 12
# Specify name for the directory where project will be implemented
set PrjDir   "impl"
set VivadoOut "Vivado_OutDir"

# Get directory name where tcl script being executed is located
set TclPath  [file dirname [file normalize [info script]]]
set BaseLoc [string range ${TclPath} 0 [string last / ${TclPath}]-1]
set TopName [string range ${BaseLoc} [string last / ${BaseLoc}]+1 end]
set PrjName ${TopName}.xpr
set SrcDir ${BaseLoc}/src
set IPGenDir ${BaseLoc}/ip_gen
set PreSynthHooksDir ${BaseLoc}/pre_synth_hooks				   
set ImplConstrDir ${BaseLoc}/src/constr/impl
set TbDir  ${SrcDir}/TestBench
set IlaDir ${BaseLoc}/ila_constr
set TopFileFull [glob -type f -path ${SrcDir}/ *{top_wrapper.sv}*]
set TopFileDot [string range ${TopFileFull} [string last / ${TopFileFull}]+1 end]
set TopFile    [string range ${TopFileDot} 0 [string last . ${TopFileDot}]-1]

puts "---------------------------------------------------"
puts "Top file for the project: ${TopFileFull}"
puts "---------------------------------------------------"

# Set names for Vivado implementation top directory and directory where all outputs will be recorded
set PrjDirFull ${BaseLoc}/${PrjDir}
set IpDirImpl  ${PrjDirFull}/${TopName}.srcs/sources_1/ip  	
set BDDirImpl  ${PrjDirFull}/${TopName}.srcs/sources_1/bd
set IpDir ${BaseLoc}/ip	 
set BDDir ${BaseLoc}/bd
set OutputDir  ${BaseLoc}/${VivadoOut}
set bf_filename "${OutputDir}/brief_report.rpt"


# Check if directory with this name already exist. If so - delete it
if {[file exists ${PrjDirFull}]} {
  file delete -force ${PrjDirFull}
  }
# Create implementation directory
file mkdir ${PrjDirFull}


# Check if directory with this name already exist. If so - delete it
if {[file exists ${OutputDir}]} {
  file delete -force ${OutputDir}
  }
# Create directory for output data from Vivado
file mkdir ${OutputDir}

# Open file for brief report 
set fp_main [open ${bf_filename} w+]

# Find sources in the src dir
set SrcVer         [findFiles ${SrcDir} "*.v"]
set SrcSV          [findFiles ${SrcDir} "*.sv"]
set SrcVH          [findFiles ${SrcDir} "*.vh"]
set SrcVHD         [findFiles ${SrcDir} "*.vhd"]
set SrcNGC         [findFiles ${SrcDir} "*.ngc"]
set SrcXDC         [findFiles ${SrcDir} "*.xdc"]
set SrcILA         [findFiles ${IlaDir} "*.tcl"]
set SrcConstrImpl  [findFiles ${ImplConstrDir} "*.tcl"]
set PreSynthFiles  [findFiles ${PreSynthHooksDir} "*.tcl"] 	
set IPGenScript    [findFiles ${IPGenDir} "*.tcl"]
set SrcBD          [findFiles ${BDDir} "*.tcl"]

# Create project 
create_project -force ${TopName} ${PrjDirFull} -part ${FPGA_name}
set_property target_language Verilog [current_project]

# Add sources
if {${SrcNGC} != ""} {
  add_files -norecurse $SrcNGC
} 

# -------------------------Run generation of ip_cores from script (if exist)------------------------------------
set IPGenQty [llength ${IPGenScript}]
set IPGenQtyIdx 0

while {${IPGenQty} != 0} {
  set IPGenQty [expr ${IPGenQty} - 1]
  source [lindex ${IPGenScript} ${IPGenQtyIdx}] -notrace
  set IPGenQtyIdx [expr ${IPGenQtyIdx} + 1]  
}
# ---------------------------End of run generation of ip_cores from script--------------------------------------


# ------------------------Check if IP cores included in the project---------------------------

if {[file exists ${IpDir}]} {
  file mkdir ${IpDirImpl}
  
  foreach fileName [glob -nocomplain -type f  -path ${IpDir}/ *.xci] {
        set IpSubDir [string range ${fileName} [string last / ${fileName}] [string last . ${fileName}]-1]
		set SubDirCpy ${IpDirImpl}/${IpSubDir}
        file mkdir ${SubDirCpy}
		file copy -- ${fileName} ${SubDirCpy} 
    }
  set SrcXCI [findFiles ${IpDirImpl} "*.xci"]
  
  if {${SrcXCI} != ""} {
    add_files -norecurse $SrcXCI
    export_ip_user_files -of_objects [get_files $SrcXCI] -force 
} 
  
}
# --------------------------------------------------------------------------------------------
  
if {${SrcVer} != ""} {
  add_files -norecurse $SrcVer
} 
  
if {${SrcSV} != ""} {
  add_files -norecurse $SrcSV
} 

if {${SrcVH} != ""} {
  add_files -norecurse $SrcVH
} 

if {${SrcVHD} != ""} {
  add_files -norecurse $SrcVHD
} 

if {${SrcXDC} != ""} {
  add_files -fileset constrs_1   -norecurse ${SrcXDC}
} 

# Extract BD
if {${SrcBD} != ""} {
  source ${SrcBD}

  regenerate_bd_layout

  set SrcBD [findFiles ${BDDirImpl} "*.bd"]

  set_property synth_checkpoint_mode None [get_files $SrcBD]

  generate_target all [get_files $SrcBD]

  export_ip_user_files -of_objects [get_files $SrcBD] -no_script -sync -force -quiet
  export_simulation -of_objects [get_files $SrcBD] -directory ${PrjDirFull}/${TopName}.ip_user_files/sim_scripts -ip_user_files_dir ${PrjDirFull}/${TopName}.ip_user_files -ipstatic_source_dir ${PrjDirFull}/${TopName}.ip_user_files/ipstatic -lib_map_path [list {modelsim=${PrjDirFull}/${TopName}..cache/compile_simlib/modelsim} {questa=${PrjDirFull}/${TopName}.cache/compile_simlib/questa} {riviera=${PrjDirFull}/${TopName}.cache/compile_simlib/riviera} {activehdl=${PrjDirFull}/${TopName}.cache/compile_simlib/activehdl}] -use_ip_compiled_libs -force -quiet

}

# Create ILA filesets
# Fileset constrs_2 always exists and relates to constrs_1 + ila_constrs
#
if {${SrcILA} != ""} {
  set run_qty [expr [llength ${SrcILA}]]
  set constrs_set_init_val 2
  
  foreach fileName [glob -nocomplain -type f  -path ${IlaDir}/ *.tcl] {
        create_fileset constrs_${constrs_set_init_val}
		add_files -fileset constrs_${constrs_set_init_val} [get_files -of [get_filesets {constrs_1}]]  
		
		# Add common implementation constraints to every run
		if {${SrcConstrImpl} != ""} {
		  add_files -fileset constrs_${constrs_set_init_val} ${SrcConstrImpl}
		  set_property USED_IN_SYNTHESIS false [get_files ${SrcConstrImpl}]
		  set_property USED_IN_IMPLEMENTATION true [get_files ${SrcConstrImpl}]
		}
		
		add_files -fileset constrs_${constrs_set_init_val} ${fileName}
		# ILA files used only in implementation
		set_property USED_IN_SYNTHESIS false [get_files ${fileName}]
        set_property USED_IN_IMPLEMENTATION true [get_files ${fileName}]
		

		set constrs_set_init_val [expr ${constrs_set_init_val} + 1]
    }  
} else {
  set run_qty 1
# Create and fill in fileset for implementation if there is no ila files
  create_fileset constrs_2
  add_files -fileset constrs_2 [get_files -of [get_filesets {constrs_1}]]
  
# Add common implementation constraints 
		if {${SrcConstrImpl} != ""} {
		  add_files -fileset constrs_2 ${SrcConstrImpl}
		  set_property USED_IN_SYNTHESIS false [get_files ${SrcConstrImpl}]
		  set_property USED_IN_IMPLEMENTATION true [get_files ${SrcConstrImpl}]
		}  
}

# Set top file of the project
set_property top ${TopFile} [current_fileset]

# ------------------Block to include simulation files into sim_1 fileset--------------------
# Exclude sim files from synthesis list
set SimFilesV [findFiles ${TbDir} "*.v"]
set SimFilesVHD [findFiles ${TbDir} "*.vhd"]

if {${SimFilesV} != ""} {
  remove_files $SimFilesV 
}

if {${SimFilesVHD} != ""} {
  remove_files $SimFilesVHD 
}

set SimFilesV   [findFiles ${TbDir} "*.v"]
set SimFilesVHD [findFiles ${TbDir} "*.vhd"]

if {${SimFilesV} != ""} {
  add_files -fileset sim_1 -norecurse $SimFilesV 
}

if {${SimFilesVHD} != ""} {
  add_files -fileset sim_1 -norecurse $SimFilesVHD 
}

# -----------------------------------End of block--------------------------------------------
 
for {set i 0} {$i < [llength ${SimFilesV}]} {incr i} {
# In order to change fileset of the file it first needs to be removed as FILESET_NAME is readonly property
  set_property used_in_synthesis false [get_files [lindex ${SimFilesV} ${i}]]
}

for {set i 0} {$i < [llength ${SimFilesVHD}]} {incr i} {
  set_property used_in_synthesis false [get_files [lindex ${SimFilesVHD} ${i}]]
}

# ------------------------------Check if upgrade of IP is required--------------------------
set IpCores [get_ips]
for {set i 0} {$i < [llength $IpCores]} {incr i} {
    set IpSingle [lindex $IpCores $i]
    
    set locked [get_property IS_LOCKED $IpSingle]
    set upgrade [get_property UPGRADE_VERSIONS $IpSingle]
    if {$upgrade != "" && $locked} {
        upgrade_ip $IpSingle
    }
}
# -------------------------------------------------------------------------------------------
#
# -------------------------Run pre_synth hooks (if exist)------------------------------------
set PreSynthHooksQty [llength ${PreSynthFiles}]
set PreSynthHooksIdx 0

while {${PreSynthHooksQty} != 0} {
  set PreSynthHooksQty [expr ${PreSynthHooksQty} - 1]
  source [lindex ${PreSynthFiles} ${PreSynthHooksIdx}] -notrace
  set PreSynthHooksIdx [expr ${PreSynthHooksIdx} + 1]  
}
# ---------------------------End of run pre_synth hooks--------------------------------------

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1


# -------------------------Settings of synthesis---------------------
# ---------Synthesis
set synth_run_cnt 0
set CurrentSynth "synth"

set SynthStrategiesQty [llength ${Synth_Strategies}]

while {${SynthStrategiesQty} != 0} {
  set SynthStrategiesQty [expr ${SynthStrategiesQty} - 1]
  set CurrentSynthStr ${CurrentSynth}_${SynthStrategiesQty}
  
  
  # Run synth_1 exists by default, don't need to recreate it
  # All synth runs use constrset 1
  
  if { ${CurrentSynthStr} != "synth_1"} {
  create_run ${CurrentSynthStr} -flow {Vivado Synthesis 2021} -constrset constrs_1
  } else {
    set_property CONSTRSET constrs_1 [get_runs synth_1]
  }
  
  current_run [get_runs ${CurrentSynthStr}]
  
  set_property strategy [lindex ${Synth_Strategies} ${SynthStrategiesQty}] [get_runs ${CurrentSynthStr}]
  set_property report_strategy {Vivado Synthesis Default Reports} [get_runs ${CurrentSynthStr}]
#
# Additional Synthesis settings
#
#set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs ${CurrentSynthStr}]
#set_property STEPS.SYNTH_DESIGN.ARGS.FSM_EXTRACTION auto [get_runs ${CurrentSynthStr}]
#set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs ${CurrentSynthStr}]
#
# These are unique settings for Synthesis and they need to be either set or reset based on needs
# -----------------------------------------------------------------------------------------------
# # -no_lc option. When checked, this option turns off LUT combining (UG901 p.12)
#set_property STEPS.SYNTH_DESIGN.ARGS.NO_LC true [get_runs ${CurrentSynthStr}]
# # -shreg_min_size option. Is the threshold for inference of SRLs (UG901 p.12), default value is 3
#set_property STEPS.SYNTH_DESIGN.ARGS.SHREG_MIN_SIZE 6 [get_runs ${CurrentSynthStr}]
# -----------------------------------------------------------------------------------------------
#
# --------------------------------------Synthesis-----------------------------------------------

launch_runs ${CurrentSynthStr} -jobs ${NumJobs}
wait_on_run ${CurrentSynthStr}

open_run ${CurrentSynthStr} -name ${CurrentSynthStr}

###write_checkpoint -force $OutputDir/${CurrentSynthStr}_post_synth.dcp
report_timing_summary -file $OutputDir/${CurrentSynthStr}_post_synth_timing_summary.rpt
report_utilization -file $OutputDir/${CurrentSynthStr}_post_synth_util.rpt
#
# Run custom script to report critical timing paths
reportCriticalPaths $OutputDir/${CurrentSynthStr}_post_synth_critpath_report.csv

set systemTime [clock seconds]
puts ${fp_main} "Time of synthesis is: [clock format $systemTime -format %Y:%d:%H:%M:%S]" 
puts ${fp_main} "================================================="
puts ${fp_main} "--------------Synthesis report-------------------"
puts ${fp_main} "================================================="
set synth_str [get_property strategy [get_runs ${CurrentSynthStr}]]
puts ${fp_main} "Synthesis strategy: ${synth_str}"
puts ${fp_main} "Synthesis run: ${CurrentSynthStr}"
set path [get_timing_paths -delay_type max -max_paths 1 -nworst 1]
set slack [get_property SLACK ${path}]
puts ${fp_main} "Data from get_timing_paths command:"
puts ${fp_main} "#"
puts ${fp_main} "Worst timing path: ${path}"
puts ${fp_main} "Worst slack: ${slack}"
puts ${fp_main} "#"
puts ${fp_main} "Statistics:"
puts ${fp_main} "Elapsed time: [get_property STATS.ELAPSED [get_runs ${CurrentSynthStr}]]"
puts ${fp_main} "---------------------------------------------------"

close_design

# --------------------------------------Implementation-------------------------------------------
#
# Create implementation runs
set run_qty_copy ${run_qty} 

# Impl_1 always exists and need to increment CONSTRSET for it 
#set_property CONSTRSET constrs_2 [get_runs impl_1]

while {${run_qty_copy} > 1} {
# Constrs set must be one digit more than impl num (for impl_1 - constrs_2, etc.)
  set run_qty_copy_dec [expr ${run_qty_copy} - 1]
  set run_num impl_${run_qty_copy_dec}_${CurrentSynthStr}
  
  create_run ${run_num} -parent_run ${CurrentSynthStr} -flow {Vivado Implementation 2021} -constrset constrs_${run_qty_copy}
  set run_qty_copy [expr ${run_qty_copy} - 1]  
}

# Prepare counters for multiple runs (if any)
set run_count 1
set run_qty_copy [expr ${run_qty} + 1]

#Main loop for implementation runs
#
while {${run_count} < ${run_qty_copy}} {

  set run_num impl_${run_count}_${CurrentSynthStr}
  set run_count_inc [expr ${run_count} + 1]
  create_run ${run_num} -parent_run ${CurrentSynthStr} -flow {Vivado Implementation 2021} -constrset constrs_${run_count_inc}

  set CurrentImpl ${run_num}
  set run_count [expr ${run_count} + 1]

  current_run [get_runs ${CurrentImpl}]
  
  # ------------------------Settings of implementation and bitgen----------------------------------
  # ---------Implementation
  set_property report_strategy {Vivado Implementation Default Reports} [get_runs ${CurrentImpl}]
  set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE Default [get_runs ${CurrentImpl}]
  #
  #set_property strategy  Performance_Auto_3 [get_runs ${CurrentImpl}] 
  set_property strategy  Performance_HighUtilSLRs [get_runs ${CurrentImpl}] 
  #set_property strategy Congestion_SpreadLogic_High [get_runs ${CurrentImpl}]
  #set_property strategy  {Vivado Implementation Defaults} [get_runs ${CurrentImpl}] 
  #set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs ${CurrentImpl}]
  #
  # These are unique settings for Implementation and they need to be either set or reset based on needs
  # -----------------------------------------------------------------------------------------------
  # # -directive Explore. When you run route_design -directive Explore, the router timing summary 
  # # is based on signoff timing. (UG904 p.92)
  #set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs ${CurrentImpl}]
  # # Post-Place Phys Opt Design (phys_opt_design) is enabled
  set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs ${CurrentImpl}]
  # # Post-Place Phys Opt Design -directive AggressiveExplore. Directs the router to further expand it's
  # # exploration of critical path routes while maintaining original timing budgets. (UG904 p.93)
  #set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs ${CurrentImpl}]
  # # Route Design (route_design) -directive Explore 
  #set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore [get_runs ${CurrentImpl}]
  # # Post-Route Phys Opt Design (phys_opt_design) is_enabled
  set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs ${CurrentImpl}]
  # # Post-Route Phys Opt Design -directive 
  #set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs ${CurrentImpl}]

  # -----------------------------------------------------------------------------------------------
  #
  # ---------Bitgen
  set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs ${CurrentImpl}]
  # ----------------------------------------------------------------------------------------------


  launch_runs ${CurrentImpl} -jobs ${NumJobs}
  wait_on_run ${CurrentImpl}
  
  open_run ${CurrentImpl} -name ${CurrentImpl}
  
  report_timing_summary -file $OutputDir/${CurrentImpl}_timing_summary.rpt
  report_timing_summary -no_detailed_paths -file $OutputDir/${CurrentImpl}_timing_summary_no_details.rpt

  report_utilization -file $OutputDir/${CurrentImpl}_util.rpt
  # Run custom script to report critical timing paths
  reportCriticalPaths $OutputDir/${CurrentImpl}_post_impl_critpath_report.csv
  
puts ${fp_main} "--------------Implementation report-------------------"
set impl_str [get_property strategy [get_runs ${CurrentImpl}]]
puts ${fp_main} "Implementation strategy: ${impl_str}"
puts ${fp_main} "Implementation run: ${CurrentImpl}"
set path [get_timing_paths -delay_type max -max_paths 1 -nworst 1]
set slack [get_property SLACK ${path}]
puts ${fp_main} "Data from get_timing_paths command:"
puts ${fp_main} "#"
puts ${fp_main} "Worst timing path: ${path}"
puts ${fp_main} "Worst slack: ${slack}"
puts ${fp_main} "#"
puts ${fp_main} "Statistics:"
puts ${fp_main} "Elapsed time: [get_property STATS.ELAPSED [get_runs ${CurrentImpl}]]"
puts ${fp_main} "Worst Negative Slack (WNS): [get_property STATS.WNS [get_runs ${CurrentImpl}]]"
puts ${fp_main} "Total Negative Slack (TNS): [get_property STATS.TNS [get_runs ${CurrentImpl}]]"
puts ${fp_main} "Worst Hold Slack (WHS): [get_property STATS.WHS [get_runs ${CurrentImpl}]]"
puts ${fp_main} "Total Hold Slack (THS): [get_property STATS.THS [get_runs ${CurrentImpl}]]"
puts ${fp_main} "Total Pulse Width Violation (TPWS): [get_property STATS.TPWS [get_runs ${CurrentImpl}]]"
puts ${fp_main} "Failed Nets: [get_property STATS.FAILED_NETS [get_runs ${CurrentImpl}]]"
puts ${fp_main} "Total Power: [get_property STATS.TOTAL_POWER [get_runs ${CurrentImpl}]]"
puts ${fp_main} "---------------------------------------------------"
  
  close_design

  # --------------------------------------Generate bitstream----------------------------------------

  # Command to reset bitgen step after it's completed
  #reset_run ${CurrentImpl} -prev_step 

  launch_runs ${CurrentImpl} -to_step write_bitstream -jobs ${NumJobs}
  wait_on_run ${CurrentImpl}
  #-------------------------------------------------------------------------------------------------
  #
  #--------------------------Copy bit,bin,ltx files to the output directory-------------------------
  set BitLocDir ${PrjDirFull}/${TopName}.runs/${CurrentImpl}/
  set BitFile ${BitLocDir}${TopFile}.bit
  set BinFile ${BitLocDir}${TopFile}.bin
  set LtxFile ${BitLocDir}${TopFile}.ltx


  if {[file exists ${BitFile}]} {
	  file copy -force -- ${BitFile} ${OutputDir}
	  file rename -force -- ${OutputDir}/${TopFile}.bit  ${OutputDir}/${TopFile}_${CurrentImpl}.bit 
  }

  if {[file exists ${BinFile}]} {
	  file copy -force -- ${BinFile} ${OutputDir}
	  file rename -force -- ${OutputDir}/${TopFile}.bin  ${OutputDir}/${TopFile}_${CurrentImpl}.bin 
  }

  if {[file exists ${LtxFile}]} {
	  file copy -force -- ${LtxFile} ${OutputDir}
	  file rename -force -- ${OutputDir}/${TopFile}.ltx  ${OutputDir}/${TopFile}_${CurrentImpl}.ltx 
  }
  # -------------------------------------------------------------------------------------------------
  puts "---------------------------------------------------------------------------"
  puts "---------------------------------------------------------------------------"
  puts "-----------Implementation run  ${CurrentImpl}  completed-------------------"
  puts "---------------------------------------------------------------------------"
  puts "---------------------------------------------------------------------------"
  
  # Write configuration file for flash
 # write_cfgmem  -format mcs -size 64 -interface SPIx4 -loadbit {up 0x00000000 "/home/user/work/vivado/dev_k7_test/Vivado_OutDir/top_wrapper_rmii_only_impl_1_synth_0.bit" } -checksum -file "/home/user/work/vivado/dev_k7_test/Vivado_OutDir/top_wrapper.mcs"

  # Runs with non-default implementation strategies 
  set StrategiesQty [llength ${Impl_Strategies}]
  
  while {${StrategiesQty} != 0} {
    set StrategiesQty [expr ${StrategiesQty} - 1]
	set CurrentImplStr ${CurrentImpl}-${StrategiesQty}
	
	# All runs based on CurrentSynthStr and implementation constraints of parent implementation run
    create_run ${CurrentImplStr} -parent_run ${CurrentSynthStr} -flow {Vivado Implementation 2021} -constrset [get_property constrset [get_runs ${CurrentImpl}]]
    current_run [get_runs ${CurrentImplStr}]
    set_property strategy [lindex ${Impl_Strategies} ${StrategiesQty}] [get_runs ${CurrentImplStr}]
    set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs ${CurrentImplStr}] 
	
	set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs ${CurrentImplStr}]
    set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs ${CurrentImplStr}]

  
    launch_runs ${CurrentImplStr} -jobs ${NumJobs}
    wait_on_run ${CurrentImplStr}
	
    open_run ${CurrentImplStr} -name ${CurrentImplStr}
  
    report_timing_summary -file $OutputDir/${CurrentImplStr}_timing_summary.rpt
    report_timing_summary -no_detailed_paths -file $OutputDir/${CurrentImplStr}_timing_summary_no_details.rpt

    report_utilization -file $OutputDir/${CurrentImplStr}_util.rpt
    reportCriticalPaths $OutputDir/${CurrentImplStr}_post_impl_critpath_report.csv
	
    puts ${fp_main} "--------------Implementation report-------------------"
    set impl_str [get_property strategy [get_runs ${CurrentImplStr}]]
    puts ${fp_main} "Implementation strategy: ${impl_str}"
	puts ${fp_main} "Implementation run: ${CurrentImplStr}"
    set path [get_timing_paths -delay_type max -max_paths 1 -nworst 1]
    set slack [get_property SLACK ${path}]
    puts ${fp_main} "Data from get_timing_paths command:"
    puts ${fp_main} "#"
    puts ${fp_main} "Worst timing path: ${path}"
    puts ${fp_main} "Worst slack: ${slack}"
    puts ${fp_main} "#"
    puts ${fp_main} "Statistics:"
    puts ${fp_main} "Elapsed time: [get_property STATS.ELAPSED [get_runs ${CurrentImplStr}]]"
    puts ${fp_main} "Worst Negative Slack (WNS): [get_property STATS.WNS [get_runs ${CurrentImplStr}]]"
    puts ${fp_main} "Total Negative Slack (TNS): [get_property STATS.TNS [get_runs ${CurrentImplStr}]]"
    puts ${fp_main} "Worst Hold Slack (WHS): [get_property STATS.WHS [get_runs ${CurrentImplStr}]]"
    puts ${fp_main} "Total Hold Slack (THS): [get_property STATS.THS [get_runs ${CurrentImplStr}]]"
    puts ${fp_main} "Total Pulse Width Violation (TPWS): [get_property STATS.TPWS [get_runs ${CurrentImplStr}]]"
    puts ${fp_main} "Failed Nets: [get_property STATS.FAILED_NETS [get_runs ${CurrentImplStr}]]"
    puts ${fp_main} "Total Power: [get_property STATS.TOTAL_POWER [get_runs ${CurrentImplStr}]]"
    puts ${fp_main} "---------------------------------------------------"
	
    close_design

    # --------------------------------------Generate bitstream----------------------------------------
    launch_runs ${CurrentImplStr} -to_step write_bitstream -jobs ${NumJobs}
    wait_on_run ${CurrentImplStr}
    #-------------------------------------------------------------------------------------------------
	
	
    #-------------------------------------------------------------------------------------------------
    #
    #--------------------------Copy bit,bin,ltx files to the output directory-------------------------
    set BitLocDir ${PrjDirFull}/${TopName}.runs/${CurrentImplStr}/
    set BitFile ${BitLocDir}${TopFile}.bit
    set BinFile ${BitLocDir}${TopFile}.bin
    set LtxFile ${BitLocDir}${TopFile}.ltx


    if {[file exists ${BitFile}]} {
   	    file copy -force -- ${BitFile} ${OutputDir}
   	    file rename -force -- ${OutputDir}/${TopFile}.bit  ${OutputDir}/${TopFile}_${CurrentImplStr}.bit 
    }

    if {[file exists ${BinFile}]} {
   	    file copy -force -- ${BinFile} ${OutputDir}
   	    file rename -force -- ${OutputDir}/${TopFile}.bin  ${OutputDir}/${TopFile}_${CurrentImplStr}.bin 
    }

    if {[file exists ${LtxFile}]} {
   	    file copy -force -- ${LtxFile} ${OutputDir}
   	    file rename -force -- ${OutputDir}/${TopFile}.ltx  ${OutputDir}/${TopFile}_${CurrentImplStr}.ltx 
    }
	
    # --------------------------------------------------------------------------------	
    puts "---------------------------------------------------------------------------"
    puts "---------------------------------------------------------------------------"
    puts "---------Implementation run  ${CurrentImplStr}  completed------------------"
    puts "---------------------------------------------------------------------------"
    puts "---------------------------------------------------------------------------"
  # Write configuration file for flash
 # write_cfgmem  -format mcs -size 64 -interface SPIx4 -loadbit {up 0x00000000 "/home/user/work/vivado/dev_k7_test/Vivado_OutDir/top_wrapper_impl_1_synth_0.bit" } -checksum -file "/home/user/work/vivado/dev_k7_test/Vivado_OutDir/top_wrapper.mcs"
	  
  }
  
# End of impl_loop  
}
# End of synth_loop
}  



puts "All tasks completed"

# --------------This part has to be moved with proc comment {}--------------------
close ${fp_main}
# --------------------------------------------------------------------------------

proc comment {} {

}
