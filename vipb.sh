#!/bin/bash

#########################################################################
#  _____ _ _____ _____   
# |  |  |_|  _  | __  |  
# |  |  | |   __| __ -|  
#  \___/|_|__|  |_____| v0.9beta  
#

#
# check if debug mode is enabled
check_debug_mode() {
    DEBUG="false"
    CLI=false

    if [ "$1" == "debug" ]; then
        echo ">> DEBUG mode: $1"
        DEBUG="true"
        shift
    fi

    if [ "$1" == "true" ]; then
        echo ">> CLI simulation: $@"
        CLI=true
        shift
    elif [ -t 0 ] && [ $# -eq 0 ]; then
        CLI=false
    else
        CLI=true
    fi
    # echo "@$LINENO - args: $@ / count: $# / first: $1 / CLI: $CLI / DEBUG: $DEBUG"
}

check_debug_mode "$@"

# Use absolute path to source VIPB files
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Bootstrap VIPB core functions
source "$SCRIPT_DIR/vipb-core.sh" "$@"

if [ "$CLI" == "false" ]; then
    # load UI
    source "$SCRIPT_DIR/vipb-ui.sh"
    
    # Start UI execution
    header
    dashboard
    menu_main

    vquit
    
    echo "UI error? Exit."
    log "UI error? Exit."
    exit 1

elif [ "$CLI" == "true" ]; then
    # If CLI then parse arguments
    echo "VIPB $VER loaded in CLI/CronJob mode"
    log "▤▤▤▤ VIPB $VER starting ▤▤▤▤ in CLI/CronJob mode"
    debug_log "args: $*"
    check_args() {
        case $1 in
            "download") echo "download lv. $2"; download_blacklist "$2"; exit 0;;
            "compress") echo "compress $2"; compressor "$2"; exit 0;;
            "banlist")  echo "banlist $2"; ban_core "$2"; exit 0;;
            "ban")      echo "ban IP $2"; ban_ip "$MANUAL_IPSET_NAME" "$2"; exit 0;;
            "unban")    echo "unban IP $2"; unban_ip "$MANUAL_IPSET_NAME" "$2"; exit 0;;
            "stats")    echo "Banned in VIPB-set: $(count_ipset "$IPSET_NAME")" 
                        echo "banned in user set: $(count_ipset "$MANUAL_IPSET_NAME")"
                        exit 0;;
            "true"|"debug"|"")  debug_log "Starting autoban VIPB ban_core" # default CLI operation > ban blacklist.ipb
                        debug_log "args: $@"
                        debug_log "BLACKLIST_SOURCE: $BLACKLIST_FILE" 
                        ban_core $BLACKLIST_FILE
                        log "▤▤▤▤ VIPB $VER END. ▤▤▤▤ (CLI $CLI)"
                        exit 0 
                        ;;
                    *)  echo "invalid argument: $@"
                        echo
                        echo "► VIPB.sh CLI ARGUMENTS"
                        echo
                        echo "  ban #.#.#.#               ban single IP in manual/user list"
                        echo "  unban #.#.#.#             unban single IP in manual/user list"
                        echo "  download #                download lv #"
                        echo "  compress [listfile.ipb]   compress IPs list [optional: file.ipb]"
                        echo "  banlist [listfile.ipb]    ban IPs/subnets list [optional: file.ipb]"
                        echo "  stats                     view banned VIPB IPs/subnets counts"
                        echo "  true                      simulate cron/CLI (autoban)"
                        echo "  debug [true]              debug mode (echoes logs) [optional: force CLI]"
                        echo
                        echo "                            (*.ipb = list of IPs, one per line)"
                        echo
                        exit 0
                        ;;
        esac
    }
    check_args "$@"
fi

echo "No console? Exit."
log "No console? Exit."
exit 1