#!/bin/bash
set -o pipefail

# Variables
VER="v0.9beta2"
BLACKLIST_LV=3
BASECRJ='https://raw.githubusercontent.com/stamparm/ipsum/master/levels/'
BLACKLIST_URL="$BASECRJ${BLACKLIST_LV}.txt" 
BLACKLIST_FILE="$SCRIPT_DIR/vipb-blacklist.ipb"
OPTIMIZED_FILE="$SCRIPT_DIR/vipb-optimised.ipb"
SUBNETS24_FILE="$SCRIPT_DIR/vipb-subnets24.ipb"
SUBNETS16_FILE="$SCRIPT_DIR/vipb-subnets16.ipb"
LOG_FILE="$SCRIPT_DIR/vipb-log.log"
IPSET_NAME='vipb-blacklist'
MANUAL_IPSET_NAME='vipb-manualbans'
IPSET_SUBNETS_NAME='vipb-blacklist-subs'
INFOS=false
ADDED_IPS=0
ALREADYBAN_IPS=0
REMOVED_IPS=0
IPS=()


function debug_log() {
    if [[ $DEBUG == "true" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - [${BASH_SOURCE[1]}] - $1" >> "$LOG_FILE"
        echo ">> debug LOG [${BASH_SOURCE[1]}]:@$LINENO $@"
    fi
}

function log() {
    if [[ -n "$1" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - [${BASH_SOURCE[1]}] - $1" >> "$LOG_FILE"
        if [[ $DEBUG == "true" ]]; then
            echo ">> LOG [${BASH_SOURCE[1]}]:@$LINENO $@"
        fi
    fi
}

log "▤▤▤▤ VIPB $VER START ▤▤▤▤"
log "globals.sh loaded [CLI $CLI / DEBUG $DEBUG]"