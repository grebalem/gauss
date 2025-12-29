#!/bin/bash
#
# v1.0
#
# v1.0 - Initial release
#
# This script must be run from ./tcl directory of current project
# 
# NEEDS to be EDITED based on needs:
# - List of source directories (for example ../ip directory might be added)
# - Destination directory (usually last subdirectory - i.e. sha256 changed to sha512)
# - Destination directory must already exist on the server
#
scp -r ../src ../tcl ../ip_gen user@192.168.10.32:/home/user/work/vivado/gauss/

