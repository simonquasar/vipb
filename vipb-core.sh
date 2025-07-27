#!/bin/bash
set -o pipefail

# Variables & Logging
# set the blacklisted IPsum level (2-8, default 3)
BLACKLIST_LV=5
# set the default files names and path
BLACKLIST_FILE="$SCRIPT_DIR/vipb-blacklist.ipb"
OPTIMIZED_FILE="$SCRIPT_DIR/vipb-optimised.ipb"
SUBNETS24_FILE="$SCRIPT_DIR/vipb-subnets24.ipb"
SUBNETS16_FILE="$SCRIPT_DIR/vipb-subnets16.ipb"
# set the name of the ipsets used by VIPB
VIPB_IPSET_NAME='vipb-blacklist'
MANUAL_IPSET_NAME='vipb-manualbans'
# environment variables, DO NOT CHANGE
BASECRJ='https://raw.githubusercontent.com/stamparm/ipsum/master/levels/'
BLACKLIST_URL="$BASECRJ${BLACKLIST_LV}.txt"
FIREWALL='firewalld'
INFOS=false
ERRORS=false
ADDED_IPS=false
ALREADYBAN_IPS=false
REMOVED_IPS=false
METAERRORS=0
RUN_BANS="n/a"
PERM_BANS="n/a"
IPS=()
BAN_IPS=()
err=false
# some basic colors
RED='\033[31m'
GRN='\033[32m'
VLT='\033[35m'
NC='\033[0m'
BG='\033[3m' # italic

# but if pure cli/cron or no color support, remove colors
if [ -z "$TERM" ] || ! tput colors >/dev/null 2>&1 || [ "$(tput colors 2>/dev/null || echo 0)" -eq 0 ]; then
    RED=''
    GRN=''
    VLT=''
    NC=''
    BG=''
fi

# VIPB Core functions
echo -e "${VLT}✦ VIPB $VER ✦${NC}"
if [ "$EUID" -ne 0 ]; then
    echo "This program must be run as admin. Please use sudo."
    if [[ $DEBUG != "true" ]]; then
        exit 1
    fi
fi
log "▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤ VIPB $VER - START ▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤"
log "▤ ARGS [""${ARGS[*]}""]"
debug_log "▤ DEBUG mode ENABLED"

function eta() {    # ETA calculation
    start_time="$1"
    done_count="$2"
    total_count="$3"
    now_time=$(date +%s)
    elapsed=$((now_time - start_time))
    remaining=$((total_count - done_count))
    sample=$((total_count / 5))
    if ((done_count > sample)) || ((elapsed > 0)); then
        avg_time=$(awk "BEGIN {printf \"%.4f\", $elapsed / $done_count}")
        eta_sec=$(awk "BEGIN {printf \"%.1f\", $avg_time * $remaining}")
        if ((${eta_sec%.*} > 60)); then
            eta_min=$(awk "BEGIN {printf \"%.1f\", $eta_sec / 60}")
            eta_str="~${eta_min} minute(s) remaining (avg: ${avg_time}s)"
        else
            eta_str="~${eta_sec}s remaining"
        fi
        echo "$eta_str"
        return ${eta_sec%.*} # return the remaining seconds as integer
    else
        echo "Calculating ETA..."
        return 99999 # return a large number to indicate no valid ETA
    fi


}

function check_dependencies() {
    err=0
    function check_service() {
        local service_name=$1
        local is_active=false

        if command -v "$service_name" &> /dev/null; then
            is_active=true
        elif command -v systemctl &>/dev/null; then
            if systemctl is-active --quiet "$service_name" 2>/dev/null ||
            systemctl status "$service_name" 2>/dev/null | grep -q "active (exited)"; then
                is_active=true
            fi
        elif command -v service &>/dev/null; then
            if service "$service_name" status &>/dev/null; then
                is_active=true
            fi
        fi

        echo "$is_active"
    }

    function check_firewall() {
        UFW=$(check_service "ufw")
        IPTABLES=$(check_service "iptables")
        FIREWALLD=$(check_service "firewall-cmd")

        if [[ -n "$FIREWALL" ]]; then # use variable
            FIREWALL="$FIREWALL"
        fi
        if [[ "$UFW" == "true" ]]; then
            FIREWALL="ufw"
        elif [[ "$IPTABLES" == "true" ]]; then
            FIREWALL="iptables"
        elif [[ "$FIREWALLD" == "true" ]]; then
            FIREWALL="firewalld"
        else
            FIREWALL="ERROR"
            err=1
        fi

        debug_log "▤ FIREWALLD: $FIREWALLD"
        debug_log "▤ IPTABLES: $IPTABLES"
        debug_log "▤ UFW: $UFW"
        if [[ "$FIREWALL" == "ERROR" ]]; then
            log "▤ FIREWALL: $(echo -e "${RED}$FIREWALL${NC}")"
        else
            log "▤ FIREWALL: $FIREWALL"
        fi

        if [[ "$FIREWALL" == "ERROR" ]]; then
            log "@$LINENO: CRITICAL: Firewall $FIREWALL No firewall system found."
            echo -e "${RED}CRITICAL - Firewall: $FIREWALL No firewall system found!${NC}"
            #if [ ! "$DEBUG" == "true" ]; then
            #    echo "Exit."
                #exit 1
            #fi
        fi

        return $err
    }

    CRON=$(check_service "crontab")
    log "▤ CRON: $CRON"

    CURL=$(check_service "curl") #no fallback
    debug_log "▤ CURL: $CURL"

    IPSET=$(check_service "ipset")
    log "▤ IPSET: $IPSET"

    #PERSISTENT=$(check_service "netfilter-persistent")
    PERSISTENT="false" #2do
    debug_log "▤ netfilter-persistent: $PERSISTENT"

    FAIL2BAN=$(check_service "fail2ban")
    debug_log "▤ FAIL2BAN: $FAIL2BAN"

    check_firewall

    return "$err"
}

function validate_ip() {
    local input=$1
    local ip
    local cidr
    if [[ $input =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
        if [[ $input == */* ]]; then
            ip=${input%/*}
            cidr=${input#*/}
            if ((cidr < 0 || cidr > 32)); then
                return 1
            fi
        else
            ip=$input
        fi
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if ((octet < 0 || octet > 255)); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

function check_ipset() {
    local ipset_name="$1"
    f=0
    r=0
    p=0
    err=0

    # STATUS CODES: 0 1 2 6 / 3 4 5 7 8 9
    #
    #   == ipset (iptables)
    #   0 ok
    #   1 not found
    #   == firewalld
    #   -- ipset found
    #   2 no sets
    #   3 ok runtime
    #   4 ok permanent
    #   5 ok both
    #   -- ipset NOT found
    #   6 no sets
    #   7 orph runtime
    #   8 orph permanent
    #   9 orph both
    #   --
    #   10 impossible - contact dev!

    if [[ "$IPSET" == "true" ]] && [[ -n "$ipset_name" ]]; then
        echo -ne "ipset ${BG}'$ipset_name'${NC} "

        if ipset list "$ipset_name" &>/dev/null; then
            echo -ne "${GRN}found in system${NC} "
            err=0
        else
            echo -ne "${RED}not found in system${NC} "
            err=1
        fi

        if [[ "$FIREWALLD" == "true" || "$FIREWALL" == "firewalld" ]]; then
            P=$P-1

            [[ $(firewall-cmd --get-ipsets | grep -q "$ipset_name" && echo 1) ]] && ((r++, f++))
            [[ $(firewall-cmd --permanent --get-ipsets | grep -q "$ipset_name" && echo 1) ]] && ((P++, f++))

            echo -n "["

            if [[ "$err" == 0 ]]; then
                case $f in
                    0) echo -ne "${ORG}NO LINK${NC}"; err=2 ;;
                    1)
                        if (( r )); then
                            echo -ne "${S24}RUNTIME${NC}"; err=3
                        else
                            echo -ne "${BLU}--PERMANENT${NC}"; err=4
                        fi
                        ;;
                    2) echo -ne "${S16}BOTH${NC}"; err=5 ;;
                    *) echo -ne "${RED}-impossible-${NC}"; err=10 ;;
                esac
            else
                case $f in
                    0) echo -ne "${YLW}NO LINK${NC}"; err=6 ;;
                    1)
                        if (( r )); then
                            echo -ne "${YLW}RUNTIME${NC} ${ORG}ORPHANED${NC}"; err=7
                        else
                            echo -ne "${YLW}--PERMANENT${NC} ${ORG}ORPHANED${NC}"; err=8
                        fi
                        ;;
                    2) echo -ne "${YLW}BOTH${NC} ${ORG}ORPHANED${NC}"; err=9 ;;
                    *) echo -ne "${RED}-impossible-${NC}"; err=10 ;;
                esac
            fi
            echo -n "] "
        fi
    else
        err=1
    fi
    debug_log "@$LINENO: check $ipset_name > result: $err (f $f)"
    return "$err"
}

# ============================
# Section: Firewall
# ============================

function get_fw_rules() { #$FW_RULES_LIST used in 7.1.
    local err=0

    function get_iptables_rules() {
        if [[ "$FIREWALL" == "iptables" ]]; then
            FW_RULES_LIST=()
            while IFS= read -r line; do
                FW_RULES_LIST+=("$line")
            done < <(iptables -L INPUT -n --line-numbers | tail -n +3) # skip first two lines (table header and column names)
        fi
        echo -e "Found ${SLM}${#FW_RULES_LIST[@]} rules${NC} in ${BG}iptables${NC}"
    }

    function get_firewalld_rules() {
        FW_RULES_LIST=()
        if [[ "$FIREWALL" == "firewalld" ]]; then
            firewall-cmd ${PERMANENT:+$PERMANENT} --list-all | grep -q "vipb-" && echo -e "${GRN}VIPB ${PERMANENT:+$PERMANENT }rules found in firewalld list${NC}" || echo -e "${ORG}No VIPB ${PERMANENT:+$PERMANENT }rules found in firewalld list${NC}"

            echo -ne "Looking in firewalld ${PERMANENT:+$PERMANENT }zones"
            for zone in $(firewall-cmd --get-zones); do
                log "@$LINENO: $? ($zone)"
                echo -ne "."
                while IFS= read -r source; do
                    [[ -z "$source" ]] && continue
                    FW_RULES_LIST+=("$((${#FW_RULES_LIST[@]}+1)) $zone: $source")
                done < <(firewall-cmd ${PERMANENT:+$PERMANENT} --zone="$zone" --list-sources)
                firewall-cmd ${PERMANENT:+$PERMANENT} --zone="$zone" --list-sources | grep -q "vipb-" && echo -e "${GRN}VIPB ${PERMANENT:+$PERMANENT }rules found in firewalld zone $zone.${NC}"
            done
            if [[ "${#FW_RULES_LIST[@]}" == 0 ]] ; then
                echo -e " ${ORG}no rule found${NC}"
            fi

            log "Found ${SLM}${#FW_RULES_LIST[@]} rules${NC} in ${BG}firewalld${NC}"

            #check for other fw rules
            if firewall-cmd --direct --get-all-rules | grep -q "vipb-" ; then
                echo -e "${S16}VIPB --direct rules (iptables) found${NC} "
                echo -e "${YLW}WARNING: Possible firewall conflict!${NC}${BG}"
                ((METAERRORS++))
                METAERROR="found rules in other firewall"
                firewall-cmd --direct --get-all-rules
                echo -ne "${NC}"
            else
                echo -e "${S16}No VIPB --direct rules found.${NC} That's OK!"
            fi
        fi
    }

    if [[ "$FIREWALL" == "iptables" ]]; then
        if ! get_iptables_rules; then
            echo "Error: Failed to get iptables rules" >&2
            return 1
        fi
    elif [[ "$FIREWALL" == "firewalld" ]]; then
        if ! get_firewalld_rules; then
            echo "Error: Failed to get firewalld rules" >&2
            return 1
        fi
    elif [[ "$FIREWALL" == "ufw" ]]; then
        ufw status verbose
        if ufw status | grep -q "vipb-"; then
            echo -e "${GRN}VIPB rules found in UFW.${NC}"
        else
            echo -e "${RED}No VIPB rules found in UFW.${NC}"
        fi
    fi

    return $err
}

function get_fw_by_rulenum() { #$FW_RULES_LIST[NUM]
    local rule_num=$1
    if [[ $rule_num -gt 0 && $rule_num -le ${#FW_RULES_LIST[@]} ]]; then
        echo "${FW_RULES_LIST[$((rule_num-1))]}"
    else
        echo "Invalid rule #" >&2
        return 1
    fi
}

function check_firewall_rules() { #optional ipset_name firewall
    #lg "*" "check_firewall_rules $*"
    local ipset_name="$1"

    # STATUS CODES:
        #
        #   0 ok found (all)
        #   1 not found (all)
        #   3 ok runtime (firewalld)
        #   4 ok permanent (firewalld)
        #   + too many #2do

    if [[ -n "$ipset_name" ]]; then
        if [[ "$FIREWALL" == "iptables" ]]; then
                iptables -L INPUT -n --line-numbers | grep -q "match-set $ipset_name" && return 0 || return 1
        elif [[ "$FIREWALL" == "firewalld" ]] ; then
            f=0
            r=0
            p=0

            for zone in $(firewall-cmd --get-zones 2>/dev/null); do
                if command -v firewall-cmd &>/dev/null && firewall-cmd --zone="drop" --list-sources | grep -q "$ipset_name" ; then
                    (($f++))
                    r=1
                fi
            done
            for zone in $(firewall-cmd --get-zones 2>/dev/null); do
                if command -v firewall-cmd &>/dev/null && firewall-cmd --permanent --zone="drop" --list-sources | grep -q "$ipset_name" ; then
                    (($f++))
                    p=1
                fi
            done
            #log "@$LINENO: check_firewall_rules $ipset_name > f: $f r: $r p: $p"
            [[ "$f" == 0 ]] && return 1 # no rule found
            [[ "$r" == 1 ]] && [[ "$p" == 1 ]] && return 0 # fwD both found
            [[ "$r" == 1 ]] && return 3 # fwD runtime found
            [[ "$p" == 1 ]] && return 4 # fwD permanent found
            return $f                   # x too many found??
        elif [[ "$FIREWALL" == "ufw" ]]; then
            ufw status | grep -q "$ipset_name" && return 0 || return 1
        else
            log "@$LINENO: CRITICAL: Unknown firewall $FIREWALL"
            return 1
        fi
    else    # look for the standard VIPB-rulesets
        check_firewall_rules $VIPB_IPSET_NAME
        VIPB_FW_STATUS=$?
        check_firewall_rules $MANUAL_IPSET_NAME
        USER_FW_STATUS=$?
    fi

    #log "@$LINENO: check_firewall_rules $ipset_name > FW_RULES $FW_RULES"

    if [[ "$FW_RULES" == "true" ]]; then
        return 0
    else
        return 1
    fi

}

function find_vipb_rules() { # for check_vipb_rules
    local vipb_indexes=()

    if [[ ${#FW_RULES_LIST[@]} -eq 0 ]]; then
        debug_log "No firewall rules to look into."
        return 1
    fi

    for i in "${!FW_RULES_LIST[@]}"; do
        if [[ "${FW_RULES_LIST[$i]}" =~ "vipb-" ]]; then
            vipb_indexes+=("$i")
            debug_log "Found VIPB rule at index $i: ${FW_RULES_LIST[$i]}"
        fi
    done

    if [[ ${#vipb_indexes[@]} -gt 0 ]]; then
        echo "${vipb_indexes[@]}"
        return 0
    else
        debug_log "No VIPB rules found"
        return 1
    fi
}

function check_vipb_rules() { #2do refactor
    FOUND_VIPB_RULES=($(find_vipb_rules))
    local ret=$?

    case $ret in
        0)  echo -ne "${GRN}Found ${#FOUND_VIPB_RULES[@]} "
            [[ ${#FOUND_VIPB_RULES[@]} == 1 ]] &&  echo -ne "VIPB rule ${YLW}(1 missing)${NC}" || echo -ne "VIPB rules${NC} ";
            echo
            for idx in "${FOUND_VIPB_RULES[@]}"; do
                rule_num=$((idx + 1))
                echo -e "${BLU} #${rule_num} ${NC}" # ${FW_RULES_LIST[$idx]}
            done
            ;;
        1)  echo -e "${RED}No VIPB rules found in $FIREWALL ruleset${NC}"
            ;;
        *)  echo -e "${RED}Error checking VIPB rules${NC}" >&2
            echo "Check logs."
            ;;
    esac

    return $ret
}

function reload_firewall() {
    #lg "*" "reload_firewall"

    if [[ "$FIREWALL" == "firewalld" ]]; then
        echo -ne "Reloading ${ORG}$FIREWALL${NC}... "
        firewall-cmd --reload
        log "$FIREWALL reloaded"
    fi

    if [[ "$FIREWALL" == "iptables" ]]; then
        echo -e "No reload needed. "
    fi
    RELOAD=0
    METAERRORS=0
}

function save_iptables_rules() { #2do
    #if command -v netfilter-persistent >/dev/null 2>&1; then
    #    return $?
    #    echo "#2do netfilter-persistent save"
    #else
    #    log "netfilter-persistent not found, falling back to manual save" >&2
    #
       # iptables-save > "$SCRIPT_DIR/iptables-rules.v4"
        return 1
    #fi
    #if ! iptables -S > "$SCRIPT_DIR/vipb-iptables.v4" 2>/dev/null; then
    #    log "Error: Failed to backup iptables -S rules" >&2
    #fi

}

function restore_iptables_rules() { #2do
    iptables-restore < "$SCRIPT_DIR/iptables-rules.v4"
    return $?
}

function add_firewall_rules() {
    lg "*" "add_firewall_rules FIREWALL = $FIREWALL : $*"

    local ipset=${1}
    err=0
    echo -ne "Adding $FIREWALL rule... "
    check_ipset "$ipset" &>/dev/null;
    check_status="$?"
    case $check_status in
        0 | 3 | 4 | 5 | 7 | 8 | 9)
                if [[ "$FIREWALL" == "firewalld" ]]; then
                    if firewall-cmd ${PERMANENT:+$PERMANENT} --zone=drop --add-source=ipset:"$ipset"  &>/dev/null; then
                        case "$?" in
                            0)  echo "added"
                                log "added $ipset to --zone=drop";;
                            11) echo "already enabled";;
                            127) echo "command not found";;
                            *)  echo "error $?"
                                log "@$LINENO:$?";;
                        esac
                    else
                        log "@$LINENO: caannot add '$ipset' to --zone=drop (error: $?)"
                        echo -n "error"
                        err=1
                    fi
                elif [[ "$FIREWALL" == "iptables" ]]; then
                    if ! iptables -se INPUT -m set --match-set "${ipset}" src -j DROP &>/dev/null; then
                        iptables -I INPUT 1 -m set --match-set "${ipset}" src -j DROP
                        log "@$LINENO:$?"
                    else
                        log "@$LINENO:$?"
                        err=1
                    fi
                elif [[ "$FIREWALL" == "ufw" ]]; then
                    echo "ufw 2do"
                    err=1
                fi
                ;;
            *)  log "@$LINENO: $check_status"
                err=1
                ;;
    esac
    #log "@$LINENO:$err"
    return $err
}

function remove_firewall_rules() { # BY IPSETNAME
    lg "*" "remove_firewall_rules FIREWALL = $FIREWALL : $*"
    local ipset=${1:-"$VIPB_IPSET_NAME"}
    err=0

    echo -ne "Removing rules... ${NC}"
    if [[ "$FIREWALL" == "iptables" ]]; then
        if iptables -C INPUT -m set --match-set "$ipset" src -j DROP >/dev/null 2>&1; then
            iptables -D INPUT -m set --match-set "$ipset" src -j DROP >/dev/null 2>&1;
        else
            err="$?"
        fi
    elif [[ "$FIREWALL" == "firewalld" ]]; then
        echo
        for zone in $(firewall-cmd --get-zones); do
            echo -ne "zone ${BG}$zone${NC}... "
            if firewall-cmd ${PERMANENT:+$PERMANENT} --zone="$zone" --query-source=ipset:"$ipset" >/dev/null 2>&1; then
                firewall-cmd ${PERMANENT:+$PERMANENT} --zone="$zone" --remove-source=ipset:"$ipset"
                echo "  ${SLM}removed ${PERMANENT:-'runtime'}${NC}"
            else
                echo "not found"
            fi
        done
    elif [[ "$FIREWALL" == "ufw" ]]; then
        echo "2do"
        err=1
    fi

    return $err
}

function remove_firewall_rule() { #SINGLE RULE BY NUMBER
    lg "*" "remove_firewall_rule FIREWALL = $FIREWALL # $*"
    err=0
    if [[ "$FIREWALL" == "iptables" ]]; then
        if ! iptables -D INPUT "$1"; then
            err=1
        fi
    fi
    return $err
}

function fw_rule_move_to_top() {
    lg "*" "fw_rule_move_to_top FIREWALL = $FIREWALL # $*"
    err=0
    if [[ "$FIREWALL" == "iptables" ]]; then
        echo "hello"
    fi
    return $err
}

# ============================
# Section: ipsets
# ============================

function count_ipset() {
 #lg "*" "count_ipset $*"

    local ipset_name="$1"
    local query="${2:-$FIREWALL}"
    local total_ipset=0

    if [[ "$IPSET" == "true" ]] && [[ -n "$ipset_name" ]]; then
        if [[ "$query" == "firewalld" ]]; then
            check_ipset "$ipset_name" &>/dev/null;
            check_status="$?"
            f=1
            case $check_status in
                3 | 7)  if run_entries=$(firewall-cmd --ipset="$ipset_name" --get-entries); then
                            if [[ -n "$run_entries" ]]; then
                                RUN_BANS=$(echo "$run_entries" | wc -l)
                                PERM_BANS="n/a"
                            fi
                            f=0
                        fi
                        ;;
                4 | 8)  if perm_entries=$(firewall-cmd --permanent --ipset="$ipset_name" --get-entries); then
                            if [[ -n "$perm_entries" ]]; then
                                PERM_BANS=$(echo "$perm_entries" | wc -l)
                                RUN_BANS="n/a"
                            fi
                            f=0
                        fi
                        ;;
                5 | 9)  if run_entries=$(firewall-cmd --ipset="$ipset_name" --get-entries); then
                            if [[ -n "$run_entries" ]]; then
                                RUN_BANS=$(echo "$run_entries" | wc -l)
                            fi
                            f=0
                        fi
                        if perm_entries=$(firewall-cmd --permanent --ipset="$ipset_name" --get-entries); then
                            if [[ -n "$perm_entries" ]]; then
                                PERM_BANS=$(echo "$perm_entries" | wc -l)
                            fi
                            f=0
                        fi
                        ;;
                0 | 1 | 2 | 6) RUN_BANS="-"
                        PERM_BANS="-"
                        ;;
                    *)  log "@$LINENO: count: $total_ipset ($RUN_BANS --$PERM_BANS) check: $check_status"
                        echo -n "err"
                        return 1
                        ;;
            esac
            total_ipset="$RUN_BANS \t--$PERM_BANS"
            echo -n "$total_ipset"
            if [[ "$f" == 0 ]]; then
                [[ "$ipset_name" == "$VIPB_IPSET_NAME" ]] && VIPB_BANS="$total_ipset";
                [[ "$ipset_name" == "$MANUAL_IPSET_NAME" ]] && USER_BANS="$total_ipset";
            fi
        elif [[ "$query" == "iptables" ]]; then
            if ! ipset list "$ipset_name" &>/dev/null; then
                echo -n "n/a "
                return 1
            fi
            total_ipset=$(ipset list "$ipset_name" | grep -c '^[0-9]')
            echo -n "$total_ipset"
            [[ "$ipset_name" == "$VIPB_IPSET_NAME" ]] && VIPB_BANS="$total_ipset";
            [[ "$ipset_name" == "$MANUAL_IPSET_NAME" ]] && USER_BANS="$total_ipset";
        elif [[ "$query" == "ufw" ]]; then
            echo -n "UFW 2do"
        fi
        #debug_log "@$LINENO: count $ipset_name query: $query f: $f | total_ipset: $total_ipset | $RUN_BANS --$PERM_BANS"
        return 0
    else
        echo -n "err"
        return 1
    fi
}

function setup_ipset() {
    lg "*" "setup_ipset $*"

    local ipset_name="$1"
    err=0

    if ! [[ "$IPSET" == "true" ]]; then
        echo -e "${RED}IPSET is not enabled!${NC}"
        return 1
    fi

    if [[ -n "$ipset_name" ]]; then
        if [[ "$ipset_name" == "$MANUAL_IPSET_NAME" ]]; then
            maxelem=254
        else
            maxelem=99999
        fi

        check_ipset "$ipset_name" &>/dev/null;
        check_status="$?"
        case $check_status in
            1 | 6 | 7 | 8 | 9)
                echo -ne "Creating '${BG}$ipset_name${NC}' in system ipset... "
                if ipset list "$ipset_name" &>/dev/null; then
                    echo -e "${ORG}already exists${NC}"
                    log "$ipset_name already exists"
                    err=2
                else
                    if ipset create "$ipset_name" hash:net maxelem "$maxelem"; then
                        echo -e "${GRN}created${NC}"
                        log "$ipset_name created ($?)"
                    else
                        echo "${RED}$?${NC}"
                        err=1
                    fi
                fi
                ;;
            *)  log "$ipset_name exists"
                echo -e "ipset '${BG}$ipset_name${NC}' ${ORG}already exists${NC}"
                err=0
        esac

        if [[ "$FIREWALL" == "firewalld" ]]; then
            #Only the creation and removal of IP sets is limited to the permanent environment, all other IP set options can be used also in the runtime environment without the –permanent option.
            echo -ne "Adding '${BG}$ipset_name${NC}' reference in $FIREWALL... "
            case $check_status in
                2 | 6 | 3 | 4 )
                    if firewall-cmd ${PERMANENT:+$PERMANENT} --new-ipset="$ipset_name" --type=hash:net --option=maxelem="$maxelem" &>/dev/null; then
                        echo -e "${GRN}success${NC}"
                        log "$ipset_name created"
                        err=0
                    else
                        case "$?" in
                            26) echo -e "${ORG}already exists${NC}"
                                err=2
                                log "@$LINENO: [NAME_CONFLICT]"
                                ;;
                            *)  echo "@$LINENO:$?"
                                err=1
                                ;;
                        esac
                        err=1
                    fi
                    ;;
                7 | 8 | 9 ) echo -e "${SLM}already exists${NC} orphaned"
                            echo -e "${DM}Destroy the orphaned ipset chain!${NC}"
                            err=2
                    ;;
                5 ) echo -e "${GRN}OK (exists)${NC}"
                    err=0
                    ;;
            esac
            log "$ipset_name linked"
        fi
    else
        echo "ipset name error"
        debug_log "@$LINENO ipset name error!" #2do
        return 1
    fi

    return $err
}

function destroy_ipset() {
    lg "*" "destroy_ipset $*"

    local ipset_name="$1"
    err=0

    if [[ "$IPSET" == "true" ]]; then
        if [[ "$FIREWALL" == "firewalld" ]]; then
            echo -ne "Removing ipset '${BG}$ipset_name${NC}' ${PERMANENT:-'runtime'} reference from $FIREWALL... "
            check_ipset "$ipset_name" &>/dev/null;
            case $check_status in
                0 | 3 | 4 | 5 | 7 | 8| 9)  firewall-cmd --permanent --delete-ipset="$ipset_name"
                            log "$ipset_name --permanent reference unlinked";;
                        *)  echo -e "${ORG}none found!${NC}";;
            esac
        fi
        echo -ne "Removing ipset '${BG}$ipset_name${NC}' from system... "
        if ipset list "$ipset_name" &>/dev/null; then
            if ipset destroy "$ipset_name" &>/dev/null; then
                echo -e "${GRN}destroyed${NC}"
                log "$ipset_name destroyed"
            else
                log "@$LINENO: Error: destroy_ipset failed $?"
                echo -e "${RED}Error!${NC}\n Checking..."
                err=1
                check_ipset "$ipset_name" &>/dev/null;
                check_status="$?"
                echo
                case $check_status in
                    0) echo -e "ok";;
                    1) echo -e "not found ";;
                    2) echo -e "ipset but no references";;
                    3) echo -e "ok runtime";;
                    4) echo -e "ok permanent";;
                    5) echo -e "ok both";;
                    6) echo -e "no ipset and no references";;
                    7) echo -e "orph runtime";;
                    8) echo -e "orph permanent";;
                    9) echo -e "orph both";;
                    *) echo "${check_status}";;
                esac
            fi
        else
            echo -e "${ORG}not found!${NC}"
            err=1
        fi
    else
        echo "ipset not true"
        debug_log "@$LINENO #2do!" #2do
        err=1
    fi

    return $err
}

function clear_ipset() {
    lg "*" "clear_ipset $*"

    local ipset_name="$1"
    err=0

    if [[ "$IPSET" == "true" ]]; then
        if ipset flush "$ipset_name" &>/dev/null; then
            echo -e "System ipset content ${GRN}flushed${NC}"
        else
            echo -e "System ipset ${RED}not found!${NC}"
            err=1
        fi
    fi

    if [[ "$FIREWALL" == "ufw" ]]; then
        echo "2do!"
        debug_log "#2do!" #2do
        err=1
    fi

    return $err
}

function check_vipb_ipsets {
    log "Checking VIPB ipsets..."
    #echo "Checking VIPB ipsets"
    check_ipset "$VIPB_IPSET_NAME" &>/dev/null;
    VIPB_STATUS="$?"
    echo -n "."
    VIPB_BANS=$(count_ipset "$VIPB_IPSET_NAME")
    echo -n "."
    check_ipset "$MANUAL_IPSET_NAME" &>/dev/null;
    USER_STATUS="$?"
    echo -n "."
    USER_BANS=$(count_ipset "$MANUAL_IPSET_NAME")
    log "$VIPB_IPSET_NAME [$VIPB_STATUS] | VIPB_BANS: $VIPB_BANS | $MANUAL_IPSET_NAME [$USER_STATUS] | USER_BANS: $USER_BANS"
}

# ============================
# Section: IPs
# ============================

function ask_IPS() {
    IPS=()
    while true; do
        read -rp "Insert IP (↵ to continue): " ip
        if [[ -z "$ip" ]]; then
            break
        fi
        if validate_ip "$ip"; then
            IPS+=("$ip")
        else
            echo -e "${RED}Invalid IP address.${NC}"
            #return 1
        fi
    done
    lg "*" "ask_IPS ${IPS[*]}"
}

function geo_ip() {
    lg "*" "geo_ip $*"
    if [ "$#" -gt 0 ]; then
        IPS=("$@") #intended to be used by default after ask_IPS()
    fi
    if command -v geoiplookup >/dev/null 2>&1; then
        for ip in "${IPS[@]}"; do
            echo -e "Looking up IP: ${S16}$ip${S24}"
            geoiplookup "$ip"
            echo -ne "${NC}"
        done
    elif command -v whois >/dev/null 2>&1; then
        for ip in "${IPS[@]}"; do
            echo -e "Looking up IP: ${S16}$ip${NC}"
            sleep 3
            whois "$ip" | grep -E "country|Country|City|address|Organization|phone|route:|CIDR" 2>/dev/null
        done
    else
            echo -e "${RED}Geo IP not available."
            echo -e "Install ${BG}geoiplookup${NC} or ${BG}whois${NC}."
    fi
}

function ban_ip() {
    if [ $# -lt 2 ]; then
        echo "ERR@$LINENO  ${BG}ban_ip ipset_name 192.168.1.1:${NC} $*"
        return 1
    fi

    local ipset_name="$1"
    local ip="$2"

    local ban_ip_result=0
    # 0 OK - 1 ERROR - 2 ALREADY BANNED

    [[ "$CLI" == "false" || "$DEBUG" == "true" ]] && echo -ne "Ban IP: $ip \r"

    if validate_ip "$ip"; then
        if [[ "$FIREWALL" == "firewalld" ]]; then
            if firewall-cmd ${PERMANENT:+$PERMANENT} --ipset="${ipset_name}" --query-entry="$ip" &>/dev/null; then
                ban_ip_result=2
            else
                outcome=$(firewall-cmd ${PERMANENT:+$PERMANENT} --ipset="${ipset_name}" --add-entry="$ip" 2>&1)
                case "$?" in
                    0)
                        ban_ip_result=0
                        ;;
                    13)
                        # 13 = COMMAND_FAILED
                        # it's already in the ipset, so possible conflict in cross use
                        log "@$LINENO Warning [$?] > $outcome"
                        ban_ip_result=2
                        ((METAERRORS++))
                        METAERROR="found rules in other firewall"
                        ;;
                    135)
                        # 136 = INVALID IPSET
                        log "@$LINENO Error: $? INVALID IPSET. ipset_name:$ipset_name ip:$ip"
                        ban_ip_result=1
                        ;;
                    136)
                        # 136 = INVALID_ENTRY
                        log "@$LINENO Error: INVALID_ENTRY. err# $? ip:$ip"
                        ban_ip_result=1
                        ;;
                    *)
                        log "@$LINENO Error: $? Unexpected result from firewalld. ipset_name:$ipset_name ip:$ip > $outcome"
                        ban_ip_result=1
                        ;;
                esac
            fi

        elif [[ "$FIREWALL" == "iptables" ]]; then
            if [[ "$IPSET" == "true" ]]; then
                if ipset test "$ipset_name" "$ip" &>/dev/null; then
                    ban_ip_result=2
                elif [[ $? -ne 1 ]]; then
                    ban_ip_result=1
                else
                    ipset add "$ipset_name" "$ip"
                    ban_ip_result=0
                fi
            else
                # use iptables only, ban on single ip (not optimized) 2do
                if ! iptables -C INPUT -s "$ip" -j DROP &>/dev/null; then
                    if iptables -I INPUT -s "$ip" -j DROP &>/dev/null; then
                        iptables -I INPUT -s "$ip" -j DROP
                        ban_ip_result=0
                    else
                        ban_ip_result=1
                    fi
                else
                    ban_ip_result=2
                fi
            fi
        elif [[ "$FIREWALL" == "ufw" ]]; then
            echo -e "${YLW}IN DEVELOPMENT: ufw not supported yet!${NC} " #2do
            return 1
        else # should not happen
            echo -e "${RED}Error: No firewall system found!${NC}"
            log "@$LINENO: Error: No firewall system found."
            return 1
        fi
        [[ "$CLI" == "false" || "$DEBUG" == "true" ]] && echo -ne "\r\033[K" # Clear the line
    else
        echo -e "${RED}Invalid IP/CIDR address!${NC}"
        ban_ip_result=1
    fi

    #BAN RESULT OUTPUT
    case $ban_ip_result in
        0)  debug_log "IP $ip added to $FIREWALL in $ipset_name"
            ((ADDED_IPS++))
            if  [ "$INFOS" == "true" ] || [ "$DEBUG" == "true" ]; then
                echo -ne "✓ ${GRN}IP $ip \t"
                if [ "$PERSISTENT" == "true" ]; then
                    echo -ne "permanently "
                fi
                echo -e "added${NC}" # to ${BG}$ipset_name${NC}
            else
                [ "$DEBUG" == "true" ] && echo -ne "${GRN}✓${NC}";
            fi
            ;;
        1)  debug_log "IP $ip ban error"
            ((ERRORS++))
            if [ "$INFOS" == "true" ] || [ "$DEBUG" == "true" ]; then
                echo -e "✗ ${RED}IP $ip \tban error${NC}"
            else
                [ "$DEBUG" == "true" ] && echo -ne "${RED}⊗${NC}";
            fi
            ;;
        2)  debug_log "IP $ip already banned in $ipset_name"
            ((ALREADYBAN_IPS++))
            if [ "$INFOS" == "true" ] || [ "$DEBUG" == "true" ]; then
                echo -e "○ ${ORG}IP $ip \talready banned${NC}"
            else
                [ "$DEBUG" == "true" ] && echo -ne "${ORG}○${NC}";
            fi
            ;;
        *)  debug_log "?? ban_ip_result: $ban_ip_result";;
    esac

    return $ban_ip_result
}

function add_ips() {
    #lg "*" "add_ips $1 $2 $3 ..."
    #add_ips ipset_name [ip.ad.re.s16]

    local ipset="$1"

    if [ "$IPSET" == "false" ]; then
        #2do
        echo "@$LINENO: Critical Error: cannot use ipset."
        log "@$LINENO: Critical Error: cannot use ipset."
        if [ ! "$DEBUG" == "true" ]; then
            exit 1
        fi
        return 1

    else
        log "Adding IPs into ipset '$ipset'..."
        shift
        local ips=("$@")

        echo -e "Adding ${GRN}${#ips[@]} IPs${NC} into ipset ${BG}'$ipset'${NC}..."
        ADDED_IPS=0
        ALREADYBAN_IPS=0
        err=0
        ERRORS=0
        start_time=$(date +%s)
        for ip in "${ips[@]}"; do
            ban_ip "$ipset" "$ip"
            err=$?
            if [[ "$err" == "1" ]]; then
                ((ERRORS++))
            fi
            #echo -ne "\t > $err \r"
        done
        log "Done in $(($(date +%s) - start_time)) seconds. Added $ADDED_IPS IPs, $ALREADYBAN_IPS already banned, $ERRORS errors."
        echo -ne "Ban done in $(($(date +%s) - start_time)) seconds"
        if [ "$ERRORS" -gt 0 ]; then
            echo -e " with ${RED}$ERRORS errors${NC}."
            return 1
        else
            echo -e "."
            return 0
        fi
    fi
}

function unban_ip() {
    lg "*" "unban_ip $*"
    if [ $# -lt 2 ]; then
        echo "You must provide ONE name for the ipset and ONE IP address. ERR@$LINENO unban_ip ipset_name 192.168.1.1 /" "$@"
        return 1
    fi
    local ipset_name="$1"
    local ip="$2"
    if [[ "$FIREWALL" == "firewalld" ]]; then
        if firewall-cmd ${PERMANENT:+$PERMANENT} --ipset="${ipset_name}" --query-entry="$ip" &>/dev/null; then
            if ! firewall-cmd ${PERMANENT:+$PERMANENT} --ipset="${ipset_name}" --remove-entry="$ip" 2>/dev/null; then
                err=$?
                echo -e "X ${RED}IP $ip \tban error${NC}"
                #error_msg=$(firewall-cmd ${PERMANENT:+$PERMANENT} --ipset="${ipset_name}" --remove-entry="$ip" 2>&1)
                log "Failed to remove IP $ip from ipset $ipset_name: $err $error_msg"
                return $err
            else
                ((REMOVED_IPS++))
                log "Unban IP $ip"
                echo -e "- ${GRN}IP $ip \tremoved${NC}"
                return 0
            fi
        else
            echo -e "? ${ORG}IP $ip \tnot found${NC}"
            log "unban_ip NOT FOUND"
            return 1
        fi
    elif [[ "$FIREWALL" == "iptables" ]]; then
        if ipset test "$ipset_name" "$ip" &>/dev/null; then
            ipset del "$ipset_name" "$ip"
            ((REMOVED_IPS++))
            log "Unban IP $ip"
            echo -e "- ${GRN}IP $ip \tremoved${NC}"
            return 0
        else
            echo -e "? ${ORG}IP $ip \tnot found${NC}"
            lg "*" "unban_ip NOT FOUND"
            return 1
        fi
    elif [[ "$FIREWALL" == "ufw" ]]; then
        echo -e "${YLW}IN DEVELOPMENT: ufw not supported yet!${NC} " #2do
        return 1
    fi

    lg "*" "unban_ip OK"
    return 0
}

function remove_ips() {
    lg "*" "remove_ips $*"
    #ipset ip1 ip2 ip3 ip4 ip5...
    if [ $# -lt 2 ]; then
        echo "You must provide ONE name for the ipset and AT LEAST one IP address."
        echo "ERR@$LINENO remove_ips ipset_name 192.168.1.1 192.168.1.2 192.168.1.3"
        echo "$@"
        return 1
    fi
    local ipset_name="$1"
    shift
    local ips=("$@")
    REMOVED_IPS=0
    for ip in "${ips[@]}"; do
        unban_ip "$ipset_name" "$ip"
    done
    echo -n $REMOVED_IPS
    return $REMOVED_IPS
}

function log2ips() {
    # New! Extract IPs from the last tail of log
    local log_file="$1"
    local grep="$2"
    #lg "*" "log2IPs $*"
    if [[ -z "$log_file" || -z "$grep" ]] || [[ $IPSET == "false" ]]; then
        [[ -z "$log_file" ]] && echo -e "${RED}Error: Log file parameter 1 is missing${NC}"
        [[ -z "$grep" ]] && echo -e "${RED}Error: Grep pattern parameter 2 is missing${NC}"
        [[ $IPSET == "false" ]] && echo -e "${RED}Critical Error: IPSET is not enabled${NC}"
        return 1
    fi

    local extracted_ips=()
    if [[ -f "$log_file" ]]; then
        loglen=$(wc -l < "$log_file")
        extracted_ips=($(tail -n "$loglen" "$log_file" | grep "$grep" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort -u))
        if [[ ${#extracted_ips[@]} -eq 0 ]]; then
            echo -e "${SLM}No IPs found in log $log_file matching ${BG}'$grep'${NC}"
        else
            echo -e "${SLM}${#extracted_ips[@]} IPs extracted ${NC}from the last $loglen loglines matching ${BG}'$grep'${NC}"
            if $DEBUG; then
                for ip in "${extracted_ips[@]}"; do
                    echo -e "$ip "
                done
                echo
            fi
            echo -e "${YLW}Should we export them in a file?"
            select_opt "No" "Yes"
            select_yesno=$?
            echo -ne "${NC}"
            case $select_yesno in
                0)  echo "Nothing to do."
                    ;;
                1)  echo "Sure!"
                    local base_log_file=$(basename "$log_file")
                    local output_file="${base_log_file}-$(date +%Y%m%d_%H%M%S).ipb"
                    if ! printf '%s\n' "${extracted_ips[@]}" > "$SCRIPT_DIR/$output_file"; then
                        echo -e "${RED}: Failed to write to file ${BG}'$SCRIPT_DIR/$output_file'${NC}"
                        return 1
                    fi
                    echo -e "Saved to ${BG}${BLU}$SCRIPT_DIR/$output_file${NC}"
                    echo -e "${DM}You can proceed to 3. Ban >> 5. Ban from *.ipb files${NC}"
                    ;;
            esac
        fi
    else
        echo -e "${RED}Log file not found at ${BG}$log_file.${NC}"
        return 1
    fi
    return 0

}

# ============================
# Section: Lists & Files
# ============================

function check_blacklist_file() {
    #lg "*" "check_blacklist_file $*"
    #if [ $# -lt 1 ]; then
        #echo "You must provide one file. ERR@$LINENO check_blacklist_file(): $*"; return 1
    #fi

    local file_size=""
    local line_count=""

    if [ "${2:-}" == "infos" ]; then
        echo -ne "${NC}"
        if [ ! -f "$1" ]; then
            echo -ne "${RED}not found ${NC} $1"
        else
            file_size=$(du -k "$1" | cut -f1)
            line_count=$(wc -l < "$1")
            MODIFIED=$(stat -c "%y" "$1" | cut -d. -f1)
            if [ "$line_count" == "0" ]; then
                echo -ne "${ORG}empty ${NC}\t\t$line_count lines \t$file_size KB\t$MODIFIED"
                # \n${BG}$1${NC}
            else
                echo -ne "${GRN}found ${NC}\t\t$line_count lines   \t$file_size KB\t$MODIFIED"
            fi
        fi
    else
        if [ ! -f "$1" ]; then
            echo -ne "${RED}not found${NC}"
        else
            line_count=$(wc -l < "$1")
            if [ "$line_count" == "0" ]; then
                echo -ne "${ORG}found empty${NC}"
            else
                echo -ne "${NC}found "
                echo -ne "${GRN}$line_count sources${NC}"
            fi
        fi
    fi
    return 0
}

function set_blacklist_level() {
    lg "*" "set_blacklist_level $*"
    BLACKLIST_LV=${1:-4}
    while [[ ! "$BLACKLIST_LV" =~ ^[2-8]$ ]]; do
        echo "Select IPsum Blacklist level (2 more strict -- less strict 7)"
        echo
        select_lv=$(($(select_opt "2" "3" "4" "5" "6" "7") + 2))
        BLACKLIST_LV=${select_lv:-4}
    done
    BLACKLIST_URL="$BASECRJ${BLACKLIST_LV}.txt"

    # Update vipb-globals.sh with the new level
    sed -i "s/^BLACKLIST_LV=.*/BLACKLIST_LV=$BLACKLIST_LV/" "$SCRIPT_DIR/vipb-core.sh"
    log "Level set to $BLACKLIST_LV"

}

function download_blacklist() {
    #lg "*" "download_blacklist $1"

    local level=${1:-$BLACKLIST_LV}
    BLACKLIST_URL="$BASECRJ$level.txt"

    echo -e "Downloading IPsum [${VLT}LV $level${NC}] blacklist..."
    echo -e "${BG}$BLACKLIST_URL${NC}"

    if ! curl -# -o "$BLACKLIST_FILE" "$BLACKLIST_URL"; then
        echo -e "${RED}Error: Failed to download the IPsum Blacklist file.${NC}"
        log "@$LINENO: Error: Failed download"
        return 1
    fi
    line_count=$(wc -l < "$BLACKLIST_FILE")
    echo -e "${GRN}OK.${NC} New IPsum blacklist contains ${VLT}$line_count${NC} suspicious IPs."
    log "Downloaded IPsum Blacklist @ LV $level ($line_count IPs)"
    return 0
}

# ============================
# Section: Check and Repair
# ============================
function vipb_repair() {
    repair_ipsets=()
    repair_verdicts=()
    repair_statuses=()

    for i in "${!ipsets_verdicts[@]}"; do
        if [[ ${ipsets_verdicts[i]} -ne 0 ]]; then
            repair_ipsets+=("${select_ipsets[$i]}")
            repair_verdicts+=("${ipsets_verdicts[$i]}")
            repair_statuses+=("${repair_statuses[$i]}")
        fi
    done
    select_opt "${NC}${DM}« Back${NC}" "${repair_ipsets[@]}"
    ipsets_select=$?
    case $ipsets_select in
        0)  debug_log " $ipsets_select. < Back"
            back
            ;;
        *)  debug_log " $ipsets_select. ipset"
            idx=$((ipsets_select - 1))
            current_ipset="${repair_ipsets[$idx]}"
            current_verdict="${repair_verdicts[$idx]}"
            current_status="${repair_statuses[$idx]}"
            options=("Details")
            case $current_verdict in
                1)  cv="No Ipset / Orphaned";;
                2)  cv="No firewall rule";; #
                3)  cv="Entries mismatch";;
            esac
            if [[ "$current_ipset" == vipb-* ]]; then
                options+=("${BD}${SLM}Repair ${NC} ($cv)")
            fi
            echo
            select_opt "${NC}${DM}« Back${NC}" "${options[@]}"
            ipset_opt=$?
            while true; do
            case $ipset_opt in
                0)  debug_log " $ipset_opt. < Back"
                    handle_check_repair
                    ;;
                1)  debug_log " $ipset_opt. Details"
                    subtitle "$current_ipset"
                    count=$(count_ipset "$current_ipset")
                    check_ipset "$current_ipset"
                    echo -e "${VLT}$count entries${NC} in set"
                    case $current_verdict in
                        0 | 2 | 3)    desc=$(ipset list "$current_ipset" | grep "Name:" | awk '{print $2}')
                                        type=$(ipset list "$current_ipset" | grep "Type:" | awk '{print $2}')
                                        maxelem=$(ipset list "$current_ipset" | grep -o "maxelem [0-9]*" | awk '{print $2}')
                                        echo -e "description: ${BD}$desc${NC}"
                                        echo "ipset type: $type"
                                        echo "maxelements: $maxelem";;
                        1 ) echo -e "${RED}ORPHANED IPSET${NC}"
                            echo "ipset not found";;
                    esac
                    break
                    next
                    handle_check_repair
                    ;;
                2)  debug_log " $ipset_opt. Repair"
                    subtitle "$current_ipset Repair"
                    case $current_verdict in
                        1)  echo -e "${SLM}ORPHANED IPSET${NC}" #   1 no ipset / orphaned
                            echo -e "Setting up new ipset... "
                            if setup_ipset "$current_ipset"; then
                                echo -e "${GRN}OK${NC}"
                            fi
                            ;;
                        2)  echo -e "${SLM}NO FIREWALL RULE FOUND${NC}" #   2 no rule
                            if add_firewall_rules "$current_ipset" ; then
                                echo -e "${GRN}OK${NC}"
                            else
                                echo -e "${RED}failed${NC}"
                            fi
                            ;;
                        3)  echo -e "${SLM}ENTRIES UNSYNCED${NC}" #   3 entries diff
                            case $current_status in
                                3 | 5 | 7 | 9) PERMANENT="";;
                                4 | 5 | 8 | 9) PERMANENT="--permanent";;
                            esac
                            sync_ipsets() {
                                local current_ipset="$1"
                                local temp_file1=$(mktemp)
                                local temp_file2=$(mktemp)
                                local temp_file3=$(mktemp)

                                ipset list "$current_ipset" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$' > "$temp_file1"
                                firewall-cmd ${PERMANENT:+$PERMANENT} --ipset="$current_ipset" --get-entries > "$temp_file2"
                                echo "჻ system ipset..."
                                check_blacklist_file "$temp_file1"
                                IPS=()
                                while IFS= read -r ip; do
                                    if ! grep -q "^$ip$" "$temp_file1"; then
                                        IPS+=("$ip")
                                        echo -ne "."
                                        ipset add "$current_ipset" "$ip"
                                    fi
                                done < "$temp_file2"
                                total_read=${#IPS[@]}
                                echo -e "\n჻ ${VLT}${total_read} IPs synced${NC}"
                                echo "჻ into firewalld set..."
                                check_blacklist_file "$temp_file2"
                                grep -vxFf "$temp_file2" "$temp_file1" > "$temp_file3"
                                total_read=$(wc -l < "$temp_file3")
                                echo -ne "\n჻ ${VLT}${total_read} IPs to sync${NC} "
                                fw=$FIREWALL
                                FIREWALL="firewalld"
                                if ! firewall-cmd ${PERMANENT:+$PERMANENT} --ipset="$current_ipset" --add-entries-from-file="$temp_file3"; then
                                    ((ERRORS++))
                                    err=$?
                                    cat "$temp_file3" > "$SCRIPT_DIR/DUPLICATE-$current_ipset-$(date +%Y%m%d_%H%M%S).ipb"
                                    echo -e "ERROR: duplicate list file saved."
                                    log "@$LINENO: firewall-cmd $err"
                                fi
                                err=$?
                                FIREWALL=$fw

                                #ban_core "$temp_file1" "$current_ipset"
                                rm -f "$temp_file1" "$temp_file2" "$temp_file3"
                                echo "Done."
                            }
                            sync_ipsets "$current_ipset"
                            ;;
                    esac
                    break
                    handle_check_repair
                    ;;
            esac
            done
            ;;
    esac
}

function check_and_repair() { #2do
    #echo -e "${BD}CHECKLIST${NC}"

        # check_and_repair STATUS CODES: verdict (stored in $ipsets_verdicts[i])
        #
        #   0 ok
        #   1 no ipset / orphaned       > (destroy_ipset) + setup_ipset
        #   2 no rule                   > add_firewall_rules
        #   3 entries diff              > bkp entries + destroy_ipset + setup_ipset + add_IPs
        #
        #   9                           ???
    echo
    select_ipsets=()
    if [[ "$IPSET" == "true" ]]; then
        select_ipsets=($(ipset list -n))
    fi
    if [[ "$FIREWALLD" == "true" ]]; then
        #select_ipsets=($(sudo firewall-cmd ${PERMANENT:+$PERMANENT} --get-ipsets)
        select_ipsets+=($( (firewall-cmd --permanent --get-ipsets; firewall-cmd --get-ipsets | tr ' ' '\n') | sort -u))
        #select_ipsets=($( printf "%s\n" "${select_ipsets[@]}" | awk '!seen[$0]++'))
    fi
    ipsets_verdicts=()
    ipsets_statuses=()

    echo -ne "\t\t\t┌── ipset ───┬───────┐"

    if [[ "$FIREWALLD" == "true" ]] || [[ "$FIREWALL" == "firewalld" ]]; then
        [[ "$FIREWALL" != "firewalld" ]] && echo -ne "${DM}"
        echo -ne "\t┌───── firewalld ─────┐"
    fi
    echo
    echo -ne "${GRY}${BD}IPSETS\t\t\t│${BG} set\t#\trule${NC} │"

    if [[ "$FIREWALLD" == "true" ]] || [[ "$FIREWALL" == "firewalld" ]]; then
        [[ "$FIREWALL" != "firewalld" ]] && echo -ne "${DM}"
        echo -ne "\t│${BG}refer\trunt\t--perm${NC}│"
    fi
    echo -e "\t  ${VLT}${BD}✚${NC}"
    echo -ne "${GRY}${BD}═══════                 ╘════════════════════╛"

    if [[ "$FIREWALLD" == "true" ]] || [[ "$FIREWALL" == "firewalld" ]]; then
        [[ "$FIREWALL" != "firewalld" ]] && echo -ne "${DM}"
        echo -ne "  ╘═════════════════════╛"
    fi

    echo -e "${NC}\t ════"

    if [[ ${#select_ipsets[@]} -eq 0 ]]; then
        echo -e "${RED}No ipsets found.${NC}"
    else
        for i in "${!select_ipsets[@]}"; do
            current_ipset="${select_ipsets[$i]}"
            local verdict=0
            [[ "$current_ipset" != vipb-* ]] && echo -ne "${BLU}" ||echo -ne "${VLT}";
            printf "%-*.*s" "20" "20" " $current_ipset"
            check_ipset "$current_ipset" &>/dev/null;
            check_status="$?"
            ipsets_statuses[i]=$check_status
            echo -ne "\t  "
            case $check_status in                               #ipset
                0 | 2 | 3 | 4 | 5)  echo -ne "${GRN}OK${NC}";;      # set OK
                *) echo -ne "${RED}NO${NC}";;                       # set ERROR
            esac
            case $check_status in                               #first verdict
                1 ) verdict=1 ;;
                2 ) [[ "$FIREWALL" == "firewalld" ]] && verdict=1 ;;
                6 | 7 | 8 | 9) [[ "$FIREWALL" == "firewalld" ]] && verdict=1 ;;
                #0 | 3 | 4 | 5 ) verdict=0 ;;
                10 ) verdict=9 ;;
            esac
            count=$(count_ipset "$current_ipset" "iptables")
            case $check_status in                               #system ipset entries
                0 | 2 | 3 | 4 | 5)
                    total_ipset=$(ipset list "$current_ipset" | grep -c '^[0-9]')
                    echo -ne "\t${GRY}$total_ipset${NC}"
                    ;;
                *) total_ipset="n/a"
                    echo -ne "\t-" ;;
            esac
            echo -ne "\t"
            check_firewall_rules "$current_ipset" &>/dev/null;
            check_rules="$?"
            case $check_rules in                                #fw rule
                0)  echo -ne "${GRN}OK${NC}";;                     #fw rule OK
                1)  echo -ne "${RED}NO${NC}"
                    [[ "$verdict" != 1 ]] && verdict=2 ;;
                3)  echo -ne "${S24}OK${NC}";;                      # rule ok (fwD runtime)
                4)  echo -ne "${BLU}OK${NC}";;                      # rule ok (fwD perm)
                *)  echo -ne "${RED}KO ($check_rules)${NC}"
                    verdict=9 ;;
            esac

            if [[ "$FIREWALLD" == "true" ]] || [[ "$FIREWALL" == "firewalld" ]]; then
                [[ "$FIREWALL" != "firewalld" ]] && echo -ne "${DM}"
                case $check_status in                               #fwD reference
                    2)  echo -ne "\t ${YLW}NO${NC}";;
                    3)  echo -ne "\t ${S24}YES${NC}";;
                    4)  echo -ne "\t ${BLU}YES${NC}";;
                    5)  echo -ne "\t ${GRN}BOTH${NC}";;
                    7 | 8 | 9)  echo -ne "\t ${SLM}ORPH${NC}";;
                    *)  echo -e "\t"
                        log "@$LINENO:\t ${RED}NO ($check_status)${NC}";;
                esac
                [[ "$FIREWALL" != "firewalld" ]] && echo -ne "${DM}"
                count=$(count_ipset "$current_ipset" "firewalld")
                IFS=$' \t--' read -r RUN_BANS PERM_BANS <<< "$count"
                echo -ne "\t$RUN_BANS"                              #fwD runtime entries
                if [[ "$RUN_BANS" =~ ^[0-9]+$ ]]; then
                    if [ "$total_ipset" -ne "$RUN_BANS" ] && [[ "$FIREWALLD" == "true" ]]; then
                        echo -ne "${RED}!${NC}"
                        [[ "$verdict" == 0 ]] && verdict=3
                        [[ "$FIREWALL" != "firewalld" ]] && echo -ne "${DM}"

                    fi
                fi
                echo -ne "$PERM_BANS"                               #fwD perm entries
                if [[ "$PERM_BANS" =~ ^[0-9]+$ ]] ; then
                    if [ "$total_ipset" -ne "$PERM_BANS" ] && [[ "$FIREWALLD" == "true" ]]; then
                        echo -ne "${RED}!${NC}"
                        [[ "$verdict" == 0 ]] && verdict=3
                    fi
                fi
                echo -ne "${NC}"
            fi
            ipsets_verdicts[i]=$verdict
            case $verdict in
                0) echo -e "\t  ${GRN}✦${NC}" ;;
                1) echo -e "\t  ${RED}✚${NC}" ;; # 1 no ipset / orphaned
                2) echo -e "\t  ${SLM}✚${NC}" ;; # 2 no rule
                3) echo -e "\t  ${YLW}✧${NC}" ;; # 3 entries diff
                *) echo -e "\t  ${VLT}✧${ipsets_verdicts[$i]}${NC}" ;; #2d0?
            esac
        done
    fi
    echo

}

# ============================
# Section: Compressor & Ban Wrapper
# ============================

function compressor() {
    #lg "*" "compressor [CLI=$CLI] $*"

    list_file=${1:-"$BLACKLIST_FILE"}
    c24=${2:-3}
    c16=${3:-4}

    log "=========================================="
    log " Start VIPB-Compressor"

    echo -e "${CYN}■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■"
    echo -e "\t\tVIPB-Compressor Start"
    echo -e "■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■${NC}"
    echo -e "${BLU}≡${NC} $list_file "
    modified=$(stat -c "%y" "$list_file" | cut -d. -f1)
    echo -e "${BLU}≡${NC} $modified "
    echo -ne "${BLU}჻ "

    if check_blacklist_file "$list_file"; then
        total_ips=$(wc -l < "$list_file")

        temp_files=()
        compression=0
        temp_file=$(mktemp) && temp_files+=("$temp_file")
        subnet_temp=$(mktemp) && temp_files+=("$subnet_temp")
        temp_16_file=$(mktemp) && temp_files+=("$temp_16_file")
        remaining_24_temp=$(mktemp) && temp_files+=("$remaining_24_temp")
        cleanup() {
            for tf in "${temp_files[@]}"; do
                [ -f "$tf" ] && rm -f "$tf"
            done
        }
        trap cleanup EXIT
        echo

        if [ "$CLI" == "false" ]; then
            echo
            echo -e "${NC}${YLW}Set occurrence tolerance levels [2-9] ${DM}[Exit with 0]${NC}"
            echo
            while true; do
                echo -ne "${NC}  for ${S24}/24 subnets${NC} (#.#.#.${BG}0${NC}): ${YLW}"
                read -r ip_occ
                if [[ "$ip_occ" =~ ^[2-9]$ ]]; then
                    c24="$ip_occ"
                    break
                elif [[ "$ip_occ" =~ ^[0]$ ]]; then
                    back
                else
                    echo -e "${NC}Invalid input. Please enter a number between 2 and 9. Exit with 0."
                fi
            done
            while true; do
                echo -ne "${NC}  for ${S16}/16 subnets${NC} (#.#.${BG}0.0${NC}): ${YLW}"
                read -r ip_occ
                if [[ "$ip_occ" =~ ^[2-9]$ ]]; then
                    c16="$ip_occ"
                    break
                elif [[ "$ip_occ" =~ ^[0]$ ]]; then
                    back
                else
                    echo -e "${NC}Invalid input. Please enter a number between 2 and 9. ${DM}Exit with 0.${NC}"
                fi
            done
            echo
        fi

        log "=========================================="
        log "Start compression > /16 @ $c16 | /24 @ $c24"
        echo
        #echo "◣ Start validation..."
        echo -ne "${VLT}◣ Validating IPs list     ${NC}"

        # Extract subnets

        awk -F'.' '{print $1"."$2"."$3".0/24 " $0}' "$list_file" | \
            sort > "$temp_file"
        awk -F'[ .]' -v c="$c24" '{print $1"."$2"."$3".0/24"}' "$temp_file" | \
            sort | uniq -c | awk -v c="$c24" '$1 >= c {print $2}' > "$SUBNETS24_FILE"
        sed 's/\([0-9]\+\.[0-9]\+\)\.[0-9]\+\.0\/24/\1.0.0\/16/' "$SUBNETS24_FILE" | \
            sort | uniq -c | \
            awk -v c="$c16" '$1 >= c {print $2}' > "$SUBNETS16_FILE"
        echo -e "${GRN}Done. ${VLT}$total_ips IPs${NC}"

        # Create  optimized list
        # /16 #.#.0.0
        cat "$SUBNETS16_FILE" > "$OPTIMIZED_FILE"
        subnet16_count=$(wc -l < "$SUBNETS16_FILE")

        # /24 #.#.#.0
        echo -ne "${S24}◣ /24 subnets${NC} (#.#.#.${BG}0${NC})   ${NC}"
        while read -r subnet16; do
            prefix16=$(echo "$subnet16" | cut -d'/' -f1 | sed 's/\.0\.0$//')
            grep -v "^$prefix16" "$SUBNETS24_FILE" > "$remaining_24_temp"
            mv "$remaining_24_temp" "$SUBNETS24_FILE"
        done < "$SUBNETS16_FILE"
        cat "$SUBNETS24_FILE" >> "$OPTIMIZED_FILE"
        subnet24_count=$(wc -l < "$SUBNETS24_FILE")

        # IPs #.#.#.#
        while read -r subnet24; do
            subnet_prefix=$(echo "$subnet24" | cut -d'/' -f1 | sed 's/\.0$//')
            grep -v "^$subnet_prefix" "$temp_file" > "$subnet_temp"
            mv "$subnet_temp" "$temp_file"
        done < "$SUBNETS24_FILE"
        echo -e "${GRN}Done. ${S24}$subnet24_count subnets @ x$c24${NC}"
        echo -ne "${S16}◣ /16 subnets${NC} (#.#.${BG}0.0${NC})   ${NC}"
        while read -r subnet16; do
            prefix16=$(echo "$subnet16" | cut -d'/' -f1 | sed 's/\.0\.0$//')
            grep -v "^$prefix16" "$temp_file" > "$subnet_temp"
            mv "$subnet_temp" "$temp_file"
        done < "$SUBNETS16_FILE"
        echo -e "${GRN}Done. ${S16}$subnet16_count subnets @ x$c16${NC}"

        echo -ne "${BLU}◣ Writing to file...      ${NC}"
        awk '{print $2}' "$temp_file" >> "$OPTIMIZED_FILE"
        echo -ne "${GRN}Done. "

        optimized_count=$(wc -l < "$OPTIMIZED_FILE")
        single_count=$((optimized_count - subnet16_count - subnet24_count))
        subs_count=$((subnet24_count + subnet16_count))
        cut_count=$((total_ips - single_count))
        prog_ips=$((single_count * 100 / total_ips))
        prog_nets=$(((subnet24_count + subnet16_count) * 100 / total_ips))
        compression=$((prog_ips + prog_nets))
        uncompressed=$((100 - prog_ips))

        echo -e "${BLU}$optimized_count sources${NC}"

        log "Compression Done!"
        log "========================"
        log "$total_ips total IPs processed"
        log "$cut_count IPs reduced to $subs_count subnets | $subnet24_count /24subnets (x$c24) + $subnet16_count /16subnets (x$c16)"
        log "$single_count uncompressed IPs"
        log "======"
        log "$optimized_count compressed sources ($compression%)"
        log "========================"

        function compression_bar() {
            ratio=2  # 100 / ratio = 50 bars
            filips=$((prog_ips / ratio))
            filnets=$((prog_nets / ratio))
            filled=$((compression / ratio))
            fullbar=100/ratio
            empty=$((fullbar - filled))
            barips=$(printf "%0.s▓" $(seq 1 $filips))
            barnets=$(printf "%0.s▓" $(seq 1 $filnets))
            spaces=$(printf "%0.s░" $(seq 1 $empty))
            label_position=$((filled - 1))
            compression_bar=$(printf "%0.s " $(seq 1 $label_position))
            cut_perc=$((100 - compression))
            echo -e "${compression_bar}${S16}$((compression - prog_ips))%       ${CYN}${BD}-${cut_perc}%${NC}"
            echo -e "${VLT}${barips}${S16}${barnets}${CYN}${spaces}${NC}"
        }

        echo
        compression_bar
        echo
        echo -e "${S16}  ◔ $subs_count subnets${NC} from ${CYN}$cut_count IPs${NC}\t$uncompressed% to $((compression - prog_ips))%"
        echo -e "${VLT}  ◕ $single_count IPs${NC} uncompressed \t$prog_ips%"
        #echo -e "${CYN}==================================================${NC}"
        echo -e "${BD}${CYN}  = $optimized_count sources ${NC}optimized \t$compression%"
        echo -e "${CYN}■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■"
        echo -e "\t\tCompression done! "
        echo -e "==================================================${NC}"
        echo
        return 0
    else
        echo -e "${RED}ERROR: no blacklist${NC} $list_file"
        echo -e "${CYN}==================================================${NC}"
        echo
        log "@$LINENO: ERROR: no blacklist"
        return 1
    fi
}

ban_core_start(){
    echo -e "${VLT}■■■■■■■■■■■■■■■■■■■■■■■■■"
    echo -e "   VIPB-Ban started!"
    echo -e "■■■■■■■■■■■■■■■■■■■■■■■■■${NC}"
    log "=========================================="
    log " Start VIPB-Ban"

    local modified=""
    blacklist="$1"
    ipset=${2:-"$VIPB_IPSET_NAME"}
    ERRORS=0
    ALREADYBAN_IPS=0
    ADDED_IPS=0
    if [ -f "$blacklist" ]; then
        modified=$(stat -c "%y" "$blacklist" | cut -d. -f1)
        log "Source  $blacklist ($modified)"
        echo -e "${BLU}≡${NC} $blacklist"
        echo -e "${BLU}≡${NC} $modified"
        echo -ne "${BLU}≡${NC} "
        check_blacklist_file "$blacklist";
        echo
        IPS=()
        while IFS= read -r ip; do
            [[ "$CLI" == "false" ]] && echo -ne "IP? $ip \r"
            if [[ -n "$ip" && "$ip" != "#"* ]]; then
                if validate_ip "$ip"; then
                    IPS+=("$ip")
                else
                    echo -e "[" "$ip" "] ${ORG}invalid IP address${NC}"
                    ((ERRORS++))
                fi
            fi
        done < "$blacklist"
            [[ "$CLI" == "false" ]] && echo -ne "\r\033[K" # Clear the line after the loop
        BAN_IPS=()
        # Also write the valid IPS to a fixed temp file for modular (i.e. firewalld) use in ban_core_end()
        temp_ips_file="$SCRIPT_DIR/ban_core_ips.tmp"
        : > "$temp_ips_file"
        for valid_ip in "${IPS[@]}"; do
            if [ "$FIREWALL" == "firewalld" ]; then
                echo -ne "IP: $valid_ip \r"
                echo "$valid_ip" >> "$temp_ips_file"
            fi
            BAN_IPS+=("$valid_ip")
            [[ "$CLI" == "false" ]] && echo -ne "\r\033[K" # Clear the line after the loop
        done
        total_blacklist_read=${#BAN_IPS[@]}
        echo -e "჻ validated ${VLT}${total_blacklist_read} IPs${NC}"
        log "Loaded $total_blacklist_read sources"
    else
        echo -e "${NC}Error: Blacklist file."
        log "@$LINENO: Error: Blacklist file"
        return 1
    fi

    if [ "$total_blacklist_read" -eq 0 ]; then
        echo -e "${RED}No valid IPs found in list.${NC}"
        log "@$LINENO: No valid IPs found in list."
        ((ERRORS++))
        err=1
    else
        echo -ne "≡ "
        check_ipset "$ipset"
        check_status=$?
        count=$(count_ipset "$ipset")
        echo -e "with ${VLT}$count entries${NC}"

        if [[ $check_status =~ ^(1|2|6|7|8|9)$ ]]; then
            echo
            if ! setup_ipset "$ipset"; then
                echo -e "${RED}ipset error!${NC} $outcome"
                log "@$LINENO: Error: Failed to set up ipset. $outcome"
                ((ERRORS++))
                err=1
            fi
        fi

        echo -ne "⇄ ${ORG}$FIREWALL${NC} rule for ipset "
        if check_firewall_rules "$ipset" ; then
            echo -e "${GRN}OK${NC}"
        else
            echo -e "${ORG}not found${NC}"
            add_firewall_rules "$ipset"
            echo
        fi
    fi
}

ban_core_end(){
    blacklist="$1"
    ipset=${2:-"$VIPB_IPSET_NAME"}
    count=$(count_ipset "$ipset")

    echo
    echo -e "${VLT}■■■■■■■■■■■■■■■■■■■■■■■■■"
    echo -e "   VIPB-Ban finished "
    echo -e "========================="
    if [ $err -ne 0 ]; then
        echo -e "${RED} X${YLW} Errors:  $ERRORS check logs!${NC}"
    fi
    echo -e "${VLT}  V Loaded:  ${#BAN_IPS[@]}"
    echo -e "${ORG}  =  Known:  $ALREADYBAN_IPS"
    echo -e "${GRN}  +  Added:  $ADDED_IPS"
    echo -e "${VLT}=========================${NC}"
    echo -e "${BD}  ≡  TOTAL:  $count bans${VLT}"
    echo -e "■■■■■■■■■■■■■■■■■■■■■■■■■${NC}"

    log "VIPB-Ban done!"
    if [ $err -ne 0 ]; then
        log "WITH $ERRORS ERRORS! f($err)"
    fi
    log "========================"
    log " Loaded V ${#BAN_IPS[@]}"
    log "  Known = $ALREADYBAN_IPS"
    log "  Added + $ADDED_IPS"
    log "  TOTAL ≡ $count IPs/sources banned in ipset"
    log "========================"
}

function ban_core() {
    #lg "*" "ban_core $*"
    # ban_core blacklist.ipb [ipset_name]

    ban_start_time=$(date +%s)
    blacklist="$1"
    ipset_name="$2"

    ban_core_start $*

    if [ "$FIREWALL" == "firewalld" ] && [ -f "$blacklist" ] ; then
        echo -ne "Adding entries to '${BG}$ipset${NC}' from list... " # here since firewalld-cmd supports files #2do move into add_ips() function!!
        firewall-cmd ${PERMANENT:+$PERMANENT} --ipset="$ipset" --add-entries-from-file="$blacklist" 2>/dev/null
        err=$?
        if [ $err -ne 0 ]; then
            ((ERRORS++))
            log "@$LINENO: firewall-cmd $err"
            echo "error: $err"
        fi
    else
        add_ips "$ipset" "${BAN_IPS[@]}"
        err=$?
    fi

    temp_ips_file="$SCRIPT_DIR/ban_core_ips.tmp"
    [ -f "$temp_ips_file" ] && rm -f "$temp_ips_file"

    ban_core_end $*
    log "  ban_core time:   $(($(date +%s) - ban_start_time)) seconds"
    return $err
}

log "▤ vipb-core.sh  $( echo -e "${GRN}LOADED${NC}")"
log "▤ CLI [$CLI]   DEBUG [$DEBUG]"