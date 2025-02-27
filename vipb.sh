#!/bin/bash
#export TERM=xterm-256color

#########################################################################
#  _____ _ _____ _____   
# |  |  |_|  _  | __  |  
# |  |  | |   __| __ -|  
#  \___/|_|__|  |_____| v0.9beta2  
#

# check if debug mode is enabled
check_debug_mode() {
    DEBUG="false"
    CLI="false"

    if [ "$1" == "debug" ]; then
        DEBUG="true"
        echo ">> DEBUG mode: $DEBUG"
        shift
	fi

    if [ "$1" == "true" ]; then
        echo ">> CLI simulation: $@"
        CLI="true"
        shift
    elif [ -t 0 ] && [ $# -eq 0 ]; then
        CLI="false"
    else
        CLI="true"
    fi
    # echo "@$LINENO - args: $@ / count: $# / first: $1 / CLI: $CLI / DEBUG: $DEBUG"
}

check_debug_mode "$@"

# Use absolute path to source VIPB files
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Bootstrap VIPB core functions
source "$SCRIPT_DIR/vipb-core.sh" "$@"
debug_log "vipb-core loaded"

# Check/Set dependencies and set variables
log "Checking dependencies..."
check_dependencies

if [ "$CLI" == "false" ]; then
    # load UI
    source "$SCRIPT_DIR/vipb-ui.sh"
    
    # Start UI execution
    header
    menu_main

    # Nice UI quit
    vquit 
    
    echo "UI error? Exit."
    log "UI error? Exit."
    exit 1

elif [ "$CLI" == "true" ]; then
    # If CLI then parse arguments
    echo "VIPB $VER loaded in CLI/CronJob mode"
    log "▤▤▤▤ VIPB $VER loaded ▤▤▤▤ in CLI/CronJob mode"
    debug_log "args: $*"
    check_args() {
        case $1 in
            "download") echo "download lv. $2"; download_blacklist "$2"; exit 0;;
            "compress") echo "compress $2"; compressor "$2"; exit 0;;
            "banlist")  echo "banlist $2"; ban_core "$2"; exit 0;;
            "ban")      echo "ban IP $2"; ban_ip "$MANUAL_IPSET_NAME" "$2"; exit 0;;
            "unban")    echo "unban IP $2"; unban_ip "$MANUAL_IPSET_NAME" "$2"; exit 0;;
            "stats")    echo "Banned in VIPB-set: $(count_ipset "$IPSET_NAME")" 
                        echo "Banned in user set: $(count_ipset "$MANUAL_IPSET_NAME")"
                        exit 0;;
            "true"|"debug"|"")  echo "Starting core autoban...";
                        debug_log "Starting core autoban..." # default CLI operation > ban blacklist.ipb
                        debug_log "args: $@"
                        debug_log "Blacklist source file: $BLACKLIST_FILE" 
                        ban_core "$BLACKLIST_FILE" # core default operation
                        log "▤▤▤▤ VIPB $VER END. ▤▤▤▤ (CLI $CLI)"
                        exit 0 
                        ;;
                    *)  echo "invalid argument: $@"
                        echo
                        echo "► VIPB.sh ($VER) CLI ARGUMENTS"
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