#!/bin/bash
#
# v1.1
#
# v1.0 - Initial release
# v1.1 - Added clearance of Vivado_OutDir directory
#        Added copy of ila_log.txt file
#
# This script must be run from ./tcl directory of current project
# 
# NEEDS to be EDITED based on needs:
# - List of source directories (for example ../ip directory might be added)
# - Destination directory (usually last subdirectory - i.e. sha256 changed to sha512)
# - Destination directory must already exist on the server
#
rm -rf ../res7/Vivado_OutDir

scp -r  192.168.10.32:/home/user/work/vivado/gauss/Vivado_OutDir  ../res7

