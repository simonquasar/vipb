#!/usr/bin/env bash
#########################################################################
# VIPB.sh - Versatile IP Ban (VIPB) script
# A simple, versatile and efficient IP ban script for Linux servers
# by simonquasar @ github
#########################################################################
#  _____ _ _____ _____   
# |  |  |_|  _  | __  |  
# |  |  | |   __| __ -|  
#  \___/|_|__|  |_____| v0.9  
#
VER="v0.9.2"
ARGS=("$@")

if [ "$EUID" -ne 0 ]; then
    echo "✦ VIPB $VER ✦"
    echo "Error: This script must be run as root. Please use sudo.${NC}"
    exit 1
fi

# check if debug mode is enabled
check_debug_mode() {
    DEBUG="false"
    CLI="false"

    if [ "$1" == "debug" ]; then
        DEBUG="true"
        echo ">> DEBUG MODE [$DEBUG]"
        shift
    fi
    ARGS=("$@")

    if [ "$1" == "true" ]; then
        echo ">> CLI simulation: $*"
        CLI="true"
        shift
    elif [ -t 0 ] && [ $# -eq 0 ]; then
        CLI="false"
    else
        CLI="true"
    fi
    #echo "@$LINENO - args: $@ / count: $# / first: $1 / CLI: $CLI / DEBUG: $DEBUG"
}
check_debug_mode "${ARGS[@]}"

# use absolute path to source VIPB files
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_FILE="$SCRIPT_DIR/vipb-log.log"

# bootstrap log functions
function lg {
    local stripped_message 
    stripped_message=$(echo "$2" | sed 's/\x1b\[[0-9;]*m//g')
    printf "%-19s %-13s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$(basename "${BASH_SOURCE[2]}")" "$1 $stripped_message" >> "$LOG_FILE"
}
  
function debug_log() {
    if [[ $DEBUG == "true" ]]; then
        lg "+" "$@"
        echo "<< DBG [$(basename "${BASH_SOURCE[1]}")] $*"
    fi
}

function log() {
    if [[ -n "$1" ]]; then
        lg "-" "$@"
        if [[ $DEBUG == "true" ]]; then
            echo ">> LOG [$(basename "${BASH_SOURCE[1]}")] $*"
        fi
    fi
}

log "▤▤▤▤▤▤▤▤ VIPB START ▤▤▤▤ $VER"
log "▤ ARGS [""${ARGS[*]}""]"
debug_log "▤ DEBUG mode ENABLED"

# bootstrap VIPB core functions and variables
source "$SCRIPT_DIR/vipb-core.sh" "${ARGS[*]}"
log "$SCRIPT_DIR/vipb-core.sh $( echo -e "${GRN}LOADED${NC}")"

# check/set dependencies
log "Checking dependencies..."
check_dependencies
err=$?
if [ "$err" == 0 ]; then
    log "Dependencies OK"
else
    log "Dependencies ERROR $err"
fi
debug_log "check_dependencies() $err"
echo "Firewall: $FIREWALL"

# if UI terminal > load vipb-ui.sh
if [ "$CLI" == "false" ]; then
    # load UI
    source "$SCRIPT_DIR/vipb-ui.sh"
    log "$SCRIPT_DIR/vipb-ui.sh $( echo -e "${GRN}LOADED${NC}")"
    log "UI interface LOADED"
    # Start UI execution
    check_firewall_rules
    VIPB_BANS=$(count_ipset "$VIPB_IPSET_NAME")
    USER_BANS=$(count_ipset "$MANUAL_IPSET_NAME")
    header
    menu_main

    # Nice UI quit
    vquit 
    
    echo "UI error? Exit."
    log "UI error? Exit."
    exit 1

# if CLI/CronJob > parse arguments
elif [ "$CLI" == "true" ]; then
    #echo "VIPB $VER loaded in CLI/CronJob mode"
    log "VIPB loaded in CLI/CronJob mode."
    debug_log "(args: ${ARGS[*]})"
    check_args() {
        case ${ARGS[0]} in
            "download") echo "download lv. ${ARGS[1]}"; download_blacklist "${ARGS[1]}"; exit 0;;
            "compress") echo "compress ${ARGS[1]}"; compressor "${ARGS[1]}"; exit 0;;
            "banlist")  echo "banlist ${ARGS[1]}"; ban_core "${ARGS[1]}"; exit 0;;
            "ban")      echo "ban IP ${ARGS[1]}"; INFOS=true; ban_ip "$MANUAL_IPSET_NAME" "${ARGS[1]}"; exit 0;;
            "unban")    echo "unban IP ${ARGS[1]}"; INFOS=true; unban_ip "$MANUAL_IPSET_NAME" "${ARGS[1]}"; exit 0;;
            "stats")    echo "Banned in $VIPB_IPSET_NAME set: $(count_ipset "$VIPB_IPSET_NAME")" 
                        echo "Banned in $MANUAL_IPSET_NAME set: $(count_ipset "$MANUAL_IPSET_NAME")"
                        exit 0;;
            "true"|"autoban"|"debug"|"")  echo "Starting CLI/cron core autoban...";
                        debug_log "Starting CLI/cron core autoban..." 
                        #debug_log "(args: $@)"
                        download_blacklist
                        compressor
                        ban_core "$OPTIMIZED_FILE"
                        log "▩▩▩▩▩▩▩▩ VIPB END.  ▩▩▩▩ [CLI $CLI]"
                        exit 0 
                        ;;
                    *)  echo "invalid argument: $*"
                        echo
                        echo "► VIPB.sh ($VER) CLI ARGUMENTS"
                        echo
                        echo "  ban #.#.#.#               ban single IP in manual/user list"
                        echo "  unban #.#.#.#             unban single IP in manual/user list"
                        echo "  download #                download lv #"
                        echo "  compress [listfile.ipb]   compress IPs list [optional: file.ipb]"
                        echo "  banlist [listfile.ipb]    ban IPs/subnets list [optional: file.ipb]"
                        echo "  stats                     view banned VIPB IPs/subnets counts"
                        echo "  true                      simulate cron/CLI (or autoban)"
                        echo "  debug                     debug mode (echoes logs)"
                        echo
                        echo "                            (*.ipb = list of IPs, one per line)"
                        echo
                        exit 0
                        ;;
        esac
    }
    check_args "$@"
fi

# we should never reach this point
echo "No console? Exit."
log "No console? Exit."
exit 1