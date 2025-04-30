#!/bin/bash
set -o pipefail

# Variables & Logging
# set the blacklisted IPsum level (2-8, default 3)
BLACKLIST_LV=3
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
ADDED_IPS=0
ALREADYBAN_IPS=0
REMOVED_IPS=0
METAERRORS=0
IPS=()
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
        elif [[ "$IPTABLES" == "true" ]]; then
            FIREWALL="iptables"
        elif [[ "$FIREWALLD" == "true" ]]; then
            FIREWALL="firewalld"
        elif [[ "$UFW" == "true" ]]; then
            FIREWALL="ufw"
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
            log "@$LINENO: CRITICAL ERROR: No firewall system found."
            echo -e "${RED}CRITICAL ERROR: No firewall system found?!${NC}"
            if [ ! "$DEBUG" == "true" ]; then
                echo "Exit."
                exit 1
            fi
        fi

        return $err    
    }

    CRON=$(check_service "crontab")
    debug_log "▤ CRON: $CRON"

    CURL=$(check_service "curl") #no fallback
    debug_log "▤ CURL: $CURL"
    
    IPSET=$(check_service "ipset")
    debug_log "▤ IPSET: $IPSET"

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
    err=0
    # 0 found in system - 1 not found - 2 found in system with errors

    if [[ "$IPSET" == "true" ]] && [[ -n "$ipset_name" ]] ; then
        echo -ne "ipset ${BG}'$ipset_name'${NC} "

        if ! ipset list "$ipset_name" &>/dev/null; then
            echo -ne "${RED}not "
            err=1
        else
            echo -ne "${GRN}"
        fi
        echo -e "found in system ${NC}"

        if [[ "$FIREWALL" == "firewalld" ]]; then
            echo -ne "in ${ORG}${BG}firewalld${NC}: "
            if firewall-cmd --get-ipsets | grep -q "$ipset_name"; then
                echo -ne "${S16}found --runtime${NC} "
                ((f++))
            fi
            
            if firewall-cmd --permanent --get-ipsets | grep -q "$ipset_name"; then
                echo -ne "${BLU}--permanent${NC} "
                ((f++))
            fi

            if [[ "$err" == 1 ]] && [[ "$f" > 0 ]]; then      # 4 - no ipset, orphaned firewalld reference
                echo -ne "\n${RED}UNLINKED ${NC}"
                err=4
            elif [[ "$f" == 2 ]]; then                        # 3 - firewalld --permanent is synced with runtime
                echo -ne "\n${GRN}SYNC ${NC}"
                err=3
            elif [[ "$err" == 0 ]] && [[ "$f" == 0 ]]; then   # 2 - ipset has no reference in firewalld
                echo -ne "\n${RED}NO REFERENCE ${NC}"
                err=2   
            elif [[ "$f" == 0 ]]; then                        # 1 - not found (for firewalld)
                echo -ne "\n${RED}not found ${NC}"
                err=1
            fi
        fi
    else
        err=1
    fi
    log "@$LINENO: check $ipset_name > err $err (f $f)"
    return "$err"
}

# ============================
# Section: Firewall
# ============================

function get_fw_rules {
    local err=0
    
    function get_iptables_rules() {
        if [[ "$FIREWALL" == "iptables" ]]; then
            FW_RULES_LIST=()
            #iptables -L INPUT -n --line-numbers | awk 'NR>2 {print $1, $2, $3, $7, $8, $9, $10, $11, $12}' | column -t
            #iptables -L INPUT -n --line-numbers | grep -q "match-set vipb-" && echo -e "${GRN}VIPB ipsets found in iptables rules.${NC}" || echo -e "${RED}No VIPB ipsets found in iptables rules.${NC}"
            while IFS= read -r line; do
                FW_RULES_LIST+=("$line")
            done < <(iptables -L INPUT -n --line-numbers | tail -n +3) # Skip first two lines (table header and column names)
        fi
        echo "Found ${#FW_RULES_LIST[@]} rules in iptables"
    }

    function get_firewalld_rules() {
        FW_RULES_LIST=()
        if [[ "$FIREWALL" == "firewalld" ]]; then
            #firewall-cmd --list-all
            firewall-cmd --list-all | grep -q "vipb-" && echo -e "${GRN}VIPB --runtime rules found in firewalld.${NC}" || echo -e "${ORG}No VIPB --runtime rules found in firewalld.${NC}"
            #firewall-cmd --permanent --list-all
            firewall-cmd --permanent --list-all | grep -q "vipb-" && echo -e "${GRN}VIPB --permanent rules found in firewalld.${NC}" || echo -e "${ORG}No VIPB --permanent rules found in firewalld.${NC}"
            
            echo -ne "Looking in firewalld zones "
            for zone in $(firewall-cmd --get-zones); do
                echo -ne "."
                while IFS= read -r source; do
                    [[ -z "$source" ]] && continue            
                    FW_RULES_LIST+=("$((${#FW_RULES_LIST[@]}+1)) DROP all -- $source 0.0.0.0/0")
                done < <(firewall-cmd --zone="$zone" --list-sources)
                firewall-cmd --zone="$zone" --list-sources | grep -q "vipb-" && echo -e "${GRN}VIPB rules found in firewalld zone $zone.${NC}" 
            done
            if [[ "${#FW_RULES_LIST[@]}" == 0 ]] ; then
                echo -e " ${ORG}no rule found${NC}"
            fi
            log "Found ${#FW_RULES_LIST[@]} firewalld rules"
 
            #check for other fw rules
            if firewall-cmd --direct --get-all-rules | grep -q "vipb-" ; then
                echo -e "${S16}VIPB --direct rules (iptables) found.${NC} " 
                ((METAERRORS++))
                echo -e "${YLW}WARNING: Possible firewall conflict!${NC}${BG}"
                firewall-cmd --direct --get-all-rules
                echo -e "${NC}"
            else
                echo -e "${S16}No VIPB --direct rules found.${NC}"
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

function get_fw_ruleNUM() {
    #Access specific rule
    local rule_num=$1
    if [[ $rule_num -gt 0 && $rule_num -le ${#FW_RULES_LIST[@]} ]]; then
        echo "${FW_RULES_LIST[$((rule_num-1))]}"
    else
        echo "Invalid rule #" >&2
        return 1
    fi
}

function check_firewall_rules() {
    lg "*" "check_firewall_rules $*"
    local ipset_name="$1"
    
    if [[ -n "$ipset_name" ]]; then
        if [[ "$FIREWALL" == "iptables" ]]; then
            iptables -L INPUT -n --line-numbers | grep -q "match-set $ipset_name" && return 0 || return 1
        elif [[ "$FIREWALL" == "firewalld" ]]; then #2do permanent?
            firewall-cmd --zone=drop --list-sources | grep -q "$ipset_name" && return 0 || return 1
        elif [[ "$FIREWALL" == "ufw" ]]; then
            ufw status | grep -q "$ipset_name" && return 0 || return 1
        fi
    else
        FW_RULES="false"
        if [[ "$FIREWALL" == "iptables" ]]; then
            iptables -L INPUT -n --line-numbers | grep -q "match-set vipb-" && FW_RULES="true" || FW_RULES="false"
        elif [[ "$FIREWALL" == "firewalld" ]]; then
            firewall-cmd --zone=drop --list-sources | grep -q "vipb-" && FW_RULES="true" || FW_RULES="false"
            if [[ "$FW_RULES" == "true" ]]; then
                firewall-cmd --direct --get-all-rules | grep -q "vipb-" && ((METAERRORS++))
            fi
        elif [[ "$FIREWALL" == "ufw" ]]; then
            ufw status | grep -q "vipb-" && FW_RULES="true" || FW_RULES="false"
        fi
    fi
    

    if [[ "$FW_RULES" == "true" ]]; then
        return 0
    else
        return 1
    fi  
}

function find_vipb_rules {
    local vipb_indexes=()
    
    # Check if array exists and is not empty
    if [[ ${#FW_RULES_LIST[@]} -eq 0 ]]; then
        debug_log "No firewall rules to look into."
        return 1
    fi

    # Iterate through array and find VIPB rules
    for i in "${!FW_RULES_LIST[@]}"; do
        if [[ "${FW_RULES_LIST[$i]}" =~ "vipb-" ]]; then
            vipb_indexes+=("$i")
            debug_log "Found VIPB rule at index $i: ${FW_RULES_LIST[$i]}"
        fi
    done

    # Return results
    if [[ ${#vipb_indexes[@]} -gt 0 ]]; then
        echo "${vipb_indexes[@]}"
        return 0
    else
        debug_log "No VIPB rules found"
        return 1
    fi
}

function check_vipb_rules {
    FOUND_FW_RULES=($(find_vipb_rules))
    local ret=$?

    case $ret in
        0)  echo -e "${GRN}Found ${#FOUND_FW_RULES[@]} VIPB rules:${NC}"
            for idx in "${FOUND_FW_RULES[@]}"; do
                rule_num=$((idx + 1))
                echo -e "${BLU} #${rule_num}:${NC} ${FW_RULES_LIST[$idx]}"
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

function reload_firewall {
    lg "*" "reload_firewall"

    if [[ "$FIREWALL" == "firewalld" ]]; then
        echo -ne "Reloading ${ORG}$FIREWALL${NC}... "
        firewall-cmd --reload
        log "$FIREWALL reloaded"
    fi

    if [[ "$FIREWALL" == "iptables" ]]; then
        echo -e "No reload needed. "
    fi

    #if [[ "$FAIL2BAN" == "true" ]]; then
    #    echo -ne "${YLW}Fail2Ban... ${NC}"
    #    systemctl reload fail2ban
    #    echo -e "${GRN}reloaded.${NC}"
        #log "Fail2Ban reloaded"a
    #fi
    METAERRORS=0
}

function save_iptables_rules {
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save
        return $?
    else
        log "netfilter-persistent not found, falling back to manual save" >&2
        if ! iptables-save | grep -q "^-A INPUT.*match-set.*${ipset}"; then
            echo "Error: Expected rule not found before save" >&2
            return 1
        fi
        local rules_file="/etc/iptables/rules.v4"
        local backup_file="${rules_file}.bak.$(date +%Y%m%d_%H%M%S)"
        local temp_file="${rules_file}.tmp"

        if [[ -f "$rules_file" ]]; then
            cp "$rules_file" "$backup_file"
        fi
        if ! iptables-save > "$temp_file"; then
            echo "Error: Failed to save iptables rules" >&2
            return 1
        fi

        if ! iptables-restore < "$temp_file"; then
            echo "Error: Invalid rules detected, recovering from backup" >&2
            if [[ -f "$backup_file" ]]; then
                # Restore from backup
                if iptables-restore < "$backup_file"; then
                    cp "$backup_file" "$rules_file"
                    echo "Successfully restored from backup" >&2
                else
                    echo "Critical: Backup restoration failed!" >&2
                fi
            fi
            rm -f "$temp_file"
            return 1
        fi

        if ! mv "$temp_file" "$rules_file"; then
            echo "Error: Failed to update rules file" >&2
            if [[ -f "$backup_file" ]]; then
                iptables-restore < "$backup_file"
                cp "$backup_file" "$rules_file"
            fi
            return 1
        fi

        chmod 640 "$rules_file" || {
            echo "Warning: Failed to set permissions on rules file" >&2
        }
        rm -f "$backup_file"
        return 0
        
    fi
    if ! iptables -S > "$SCRIPT_DIR/vipb-iptables.v4" 2>/dev/null; then
        log "Error: Failed to backup iptables -S rules" >&2
    fi

}

function add_firewall_rules() {
    lg "*" "add_firewall_rules FIREWALL = $FIREWALL : $*"
    
    local ipset=${1:-"$VIPB_IPSET_NAME"}
    err=0
    echo -ne "Adding $FIREWALL rule... " 
    if check_ipset "$ipset" &>/dev/null; then
        if [[ "$FIREWALL" == "firewalld" ]]; then 
            if firewall-cmd ${PERMANENT:+$PERMANENT} --zone=drop --add-source=ipset:"$ipset"  &>/dev/null; then
                case "$?" in
                    0) echo "added";;
                    11) echo "already enabled";;
                    *);;
                esac
                log "added $ipset to --zone=drop"
                #
                # future usage/direct interaction with iptables would be the
                # --permanent --direct combination:
                # firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -m set --match-set vipb-blacklist src -j DROP
                # firewall-cmd --reload
            else
                log "$?"
                err=1
            fi
        elif [[ "$FIREWALL" == "iptables" ]]; then
            if ! iptables -C INPUT -m set --match-set "${ipset}" src -j DROP &>/dev/null; then
                iptables -I INPUT 1 -m set --match-set "${ipset}" src -j DROP
            else
                err="$?"
            fi
        elif [[ "$FIREWALL" == "ufw" ]]; then
            echo "ufw 2do"
            err=1
        fi
    else
        echo -e "${RED}Error: ipset '$ipset' not found!${NC}"
        err=1
    fi

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
            echo -ne "zone $zone... "
            if firewall-cmd --permanent --zone="$zone" --query-source=ipset:"$ipset" >/dev/null 2>&1; then
                firewall-cmd --permanent --zone="$zone" --remove-source=ipset:"$ipset"
                echo "  removed --permanent"
                #reload_firewall
            elif firewall-cmd --zone="$zone" --query-source=ipset:"$ipset" >/dev/null 2>&1; then
                firewall-cmd --zone="$zone" --remove-source=ipset:"$ipset"
                echo "  removed --runtime"
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
        if ! iptables -D INPUT $1; then
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
    # lg "*" "count_ipset $*"
    
    local ipset_name="$1"
    local total_ipset=0

    if [[ "$IPSET" == "true" ]] && [[ -n "$ipset_name" ]]; then
        if [[ "$FIREWALL" == "firewalld" ]]; then
            # For runtime configuration
            #firewall-cmd --ipset="$ipset_name" --get-entries
            f=1
            if run_entries=$(firewall-cmd --ipset="$ipset_name" --get-entries); then 
                run_count=0
                if [[ -n "$run_entries" ]]; then
                    run_count=$(echo "$run_entries" | wc -l)
                fi
                f=0
            fi
            # For permanent configuration
            #firewall-cmd --permanent --ipset="$ipset_name" --get-entries
            if perm_entries=$(firewall-cmd --permanent --ipset="$ipset_name" --get-entries); then
                perm_count=0
                if [[ -n "$perm_entries" ]]; then
                    perm_count=$(echo "$perm_entries" | wc -l)
                fi
                f=0
            fi

            if [[ "$f" == 0 ]]; then
                if [[ "$perm_count" == 0 ]]; then
                    total_ipset="$run_count"
                else
                    total_ipset="$run_count --$perm_count"
                fi
                echo -n "$total_ipset"
                [[ "$ipset_name" == "$VIPB_IPSET_NAME" ]] && VIPB_BANS="$total_ipset";
                [[ "$ipset_name" == "$MANUAL_IPSET_NAME" ]] && USER_BANS="$total_ipset";
            else
                echo -n "n/a"
            fi
            log "@$LINENO: count $ipset_name f: $f TOTAL: $run_count --$perm_count"
            return $f
        elif [[ "$FIREWALL" == "iptables" ]]; then
            if ! ipset list "$ipset_name" &>/dev/null; then
                echo -n "n/a"
                return 1
            fi
            total_ipset=$(ipset list "$ipset_name" | grep -c '^[0-9]')
            echo -n "$total_ipset"
            [[ "$ipset_name" == "$VIPB_IPSET_NAME" ]] && VIPB_BANS="$total_ipset";
            [[ "$ipset_name" == "$MANUAL_IPSET_NAME" ]] && USER_BANS="$total_ipset";
            log "@$LINENO: count $ipset_name TOTAL: $total_ipset"
            return 0
        elif [[ "$FIREWALL" == "ufw" ]]; then
                echo -n "2do"
                return 1
        fi
    else
        echo -n "err"
        return 1
    fi
}

function setup_ipset() { 
    lg "*" "setup_ipset $*"
    
    local ipset_name="$1"
    err=0

    if [[ "$IPSET" == "true" ]] && [[ -n "$ipset_name" ]]; then
        if [[ "$ipset_name" == "$MANUAL_IPSET_NAME" ]]; then
            maxelem=254
        else
            maxelem=99999
        fi

        if ! check_ipset "$ipset_name" &>/dev/null; then
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
        else
            log "$ipset_name exists"
            echo -e "ipset '${BG}$ipset_name${NC}' ${ORG}already exists${NC}"
            err=2
        fi

        if [[ "$FIREWALL" == "firewalld" ]]; then
            if [ $err -ne 0 ]; then
                ((METAERRORS++))
                echo -e "${YLW}WARNING: Possible firewall conflict!${NC}"
            fi
            echo -ne "Adding '${BG}$ipset_name${NC}' reference in $FIREWALL... "                       
            if firewall-cmd --permanent --new-ipset="$ipset_name" --type=hash:net --option=maxelem="$maxelem" &>/dev/null; then
                echo -e "${GRN}success${NC}"
                log "$ipset_name created"
            else
                case "$?" in
                    26) echo -e "${RED}already exists${NC}"
                        echo -e "${DM}Destroy the orphaned ipset chain!${NC}"
                        log "@$LINENO: [NAME_CONFLICT]"
                        ;;
                    *)  echo "@$LINENO:$?"
                        ;;
                esac
                err=1
            fi
            log "$ipset_name linked"
        fi
    else
        echo "ipset error"
        debug_log "@$LINENO #2do!" #2do
        return 1
    fi    

    return $err
}

function destroy_ipset() {
    lg "*" "destroy_ipset $*"
    
    local ipset_name="$1"
    err=0

    if [[ "$IPSET" == "true" ]]; then
        echo -ne "Removing ipset '${BG}$ipset_name${NC}' from system... "
        if ipset list "$ipset_name" &>/dev/null; then
            if ipset destroy "$ipset_name" &>/dev/null; then
                echo -e "${GRN}destroyed${NC}"
                log "$ipset_name destroyed"
            else
                log "@$LINENO: Error: destroy_ipset failed $?"
                echo -e "${RED}Error!${NC} Checking..."
                check_ipset "$ipset_name"
                check_status="$?"
                echo
                case $check_status in
                    0) echo -e "ipset ok";;         #OK
                    1) echo -e "no ipset found";;      #not found
                    2) echo -e "no reference";;      #firewalld: no reference
                    3) echo -e "no reference";;      #firewalld: OK sync --permanent
                    4) echo -e "no ipset";;      #firewalld: no ipset linked
                    *) echo "${check_status}";;
                esac
                ((METAERRORS++))
                err=1
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

    if [[ "$FIREWALL" == "firewalld" ]]; then
        echo -ne "Removing ipset '${BG}$ipset_name${NC}' reference from $FIREWALL... "
        if check_ipset "$ipset_name" &>/dev/null; then
            firewall-cmd --permanent --delete-ipset="$ipset_name"
            #echo -e "${GRN}unlinked${NC}"
            log "$ipset_name unlinked"
            #reload_firewall
        else
            echo -e "${ORG}none found!${NC}"
            err=1
        fi
    fi

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
    echo -n "Checking VIPB ipsets.."
    check_ipset "$VIPB_IPSET_NAME" &>/dev/null;
    VIPB_STATUS="$?"
    echo -n "."
    VIPB_BANS=$(count_ipset "$VIPB_IPSET_NAME")
    echo -n "."
    check_ipset "$MANUAL_IPSET_NAME" &>/dev/null;
    USER_STATUS="$?"
    echo -n ".. "
    USER_BANS=$(count_ipset "$MANUAL_IPSET_NAME")
    echo "OK"
    log "VIPB_STATUS $VIPB_STATUS | USER_STATUS $USER_STATUS"
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
    
    if validate_ip "$ip"; then
        if [[ "$FIREWALL" == "firewalld" ]]; then
            PERSISTENT="false" #2do
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
                        ((ERRORS++))
                        ((METAERRORS++))
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
        else #fallback should not happen
            echo -e "${RED}Error: No firewall system found!${NC}"
            log "@$LINENO: Error: No firewall system found."
            return 1
        fi
    else
        echo -e "${RED}Invalid IP/CIDR address!${NC}"
        ban_ip_result=1
    fi

    #BAN RESULT OUTPUT
    case $ban_ip_result in
        0)  debug_log "IP $ip added to $FIREWALL in $ipset_name"
            ((ADDED_IPS++))
            if  [ "$INFOS" == "true" ]; then
                echo -ne "✓ ${GRN}IP $ip \t"
                if [ "$PERSISTENT" == "true" ]; then
                    echo -ne "permanently "
                fi
                echo -e "added${NC}" # to ${BG}$ipset_name${NC}
            else
                echo -ne "${GRN}✓${NC}"
            fi
            ;;
        1)  debug_log "IP $ip ban error"
            if [ "$INFOS" == "true" ]; then
                echo -e "✗ ${RED}IP $ip \tban error${NC}"
            else
                echo -ne "${RED}⊗${NC}"
            fi
            ;;
        2)  debug_log "IP $ip already banned in $ipset_name"
            ((ALREADYBAN_IPS++))
            if [ "$INFOS" == "true" ]; then
                echo -e "○ ${ORG}IP $ip \talready banned${NC}"
            else
                echo -ne "${ORG}○${NC}"
            fi
            ;;
        *)  debug_log "?? ban_ip_result: $ban_ip_result";;
    esac

    return $ban_ip_result
}

function add_ips() { 
    lg "*" "add_ips $1 $2 $3 ..." 
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
        log "Adding IPs into ipset $ipset..."
        shift 
        local ips=("$@")  
        echo -e "Adding ${GRN}${#ips[@]} IPs${NC} into ipset ${BG}'$ipset'${BG}..."
        ADDED_IPS=0
        ALREADYBAN_IPS=0
        err=0
        ERRORS=0
        for ip in "${ips[@]}"; do
            ban_ip "$ipset" "$ip"
            err=$?
            if [[ "$err" == "1" ]]; then
                ((ERRORS++))
            fi
        done

        if [ "$ERRORS" -gt 0 ]; then
            return 1
        else
            return 0
        fi
    fi
}

function unban_ip() { #2do firewalld
    lg "*" "unban_ip $*"
    if [ $# -lt 2 ]; then
        echo "You must provide ONE name for the ipset and ONE IP address. ERR@$LINENO unban_ip ipset_name 192.168.1.1 /" "$@"
        return 1 
    fi
    local ipset_name="$1"
    local ip="$2" 
    if ipset test "$ipset_name" "$ip" &>/dev/null; then
        ipset del "$ipset_name" "$ip"
        ((REMOVED_IPS++))
        log "Unban IP $ip"
        echo -e "- ${GRN}IP $ip \tremoved${NC}"
    else
        echo -e "? ${ORG}IP $ip \tnot found${NC}"
        lg "*" "unban_ip ERROR"
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
        extracted_ips=($(tail -n $loglen "$log_file" | grep "$grep" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort -u))    
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
                echo -ne "${GRN}found${NC} "
                echo -ne "$line_count sources"
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
    lg "*" "download_blacklist $1"

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
    log "Downloaded IPsum Blaclist @ LV $level ($line_count IPs)"
    return 0
}
 
# ============================
# Section: Compressor & Ban Wrapper
# ============================

function compressor() {                                     
    lg "*" "compressor [CLI=$CLI] $*"
   
    list_file=${1:-"$BLACKLIST_FILE"}
    
    echo -ne "${BLU}≡${NC} Blacklist file ${BG}${BLU}$list_file${NC}... "

    if ! check_blacklist_file "$list_file"; then
        echo -e "${RED}ERROR: no blacklist${NC} $list_file"
        log "@$LINENO: ERROR: no blacklist"
    else
        if [ -f "$list_file" ]; then
            total_ips=$(wc -l < "$list_file")

            temp_files=()
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

            # Default occurrence tolerance levels
            c24=3
            c16=4
            
            if [ "$CLI" == "false" ]; then
                echo -e "${NC}${YLW}Set occurrence tolerance levels [2-9] ${DM}[Exit with 0]${NC}"
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
            fi

            # Extract subnets
            echo
            echo -e "${CYN}■■■■■■■■■■■■■■■■■■■■■■■■"
            echo -e " VIPB-Compressor Start "
            echo -e "========================"
            echo -ne "${VLT}◣ IPs list                ${NC}"
            log "========================"
            log "Start compression > /16 @ $c16 | /24 @ $c24"

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
            optimized_count=$(wc -l < "$OPTIMIZED_FILE")
            single_count=$((optimized_count - subnet16_count - subnet24_count))            
            cut_count=$((total_ips - single_count))
            echo -e "${GRN}Done. ${BLU}$optimized_count sources${NC}"

            function compression_bar() {
                ratio=3
                full=100
                fullbar=full/ratio
                prog_ips=$((single_count * full / total_ips))
                prog_nets=$(((subnet24_count + subnet16_count) * full / total_ips))
                progress=$((prog_ips + prog_nets))
                filips=$((prog_ips / ratio))
                filnets=$((prog_nets / ratio))
                filled=$((progress / ratio))
                empty=$((fullbar - filled))
                barips=$(printf "%0.s■" $(seq 1 $filips))
                barnets=$(printf "%0.s■" $(seq 1 $filnets))
                spaces=$(printf "%0.s□" $(seq 1 $empty))     
                fill=$((filled - 2))
                progress_bar=$(printf "%0.s " $(seq 1 $fill))
                echo -e "${progress_bar}${CYN}${BD}${progress}%${NC}"
                echo -e "${VLT}${barips}${CYN}${barnets}${CYN}${spaces}${NC}"
            }
            echo
            compression_bar

            log "====================="
            log "Compression finished!"
            log "====================="
            log "$total_ips Total IPs processed to"
            log "$optimized_count compressed sources."
            log "$single_count single IPs"
            log "$cut_count source IPs compressed into"
            log "$subnet24_count /24 subnets (x$c24) and"
            log "$subnet16_count /16 subnets (x$c16)"
            log "====================="
            echo -e "${CYN}◔ $cut_count IPs ${NC}($((100-(single_count * 100 / total_ips)))%) reduced to ${S16}$((subnet24_count + subnet16_count)) subnets${NC}" # "($((progress - (single_count * 100 / total_ips)))%)"
            echo -e "${VLT}◕ $single_count IPs ${NC}($((single_count * 100 / total_ips))%) uncompressed"
            echo
            echo -e "${BD}${CYN}≡ $optimized_count sources${NC} detected"
            
            #echo -e "    Total processed\t100% ◕  ${VLT}$total_ips IPs ${NC}"
            #echo -e "         ${CYN}reduced to${NC}\t $progress% ◔  ${CYN}$optimized_count sources${NC}"
            #echo -e "   "
            #echo -e "               from\t ${BG}$((100-(single_count * 100 / total_ips)))%${NC}  ╔ ${VLT}$cut_count IPs${NC}"
            #echo -e "                 to\t ${BG} $((progress - (single_count * 100 / total_ips)))%${NC}  ╙ ${S16}$((subnet24_count + subnet16_count)) subnets +${NC}"
            #echo -e "       uncompressed\t ${BG}$((single_count * 100 / total_ips))%${NC}    ${CYN}$single_count IPs${NC}"
            
            #list_ips(){ # why here? 2do
            #if [ "$2" -lt "$3" ]; then
                #while read -r subnet; do
                #    echo -e "\t$subnet"
                #done < "$1"
            #fi
            #}
            
            #if [ "$subnet24_count" -lt "15" ] && [ "$subnet24_count" -ne "0" ]; then 
                #echo            
                #echo -e "${NC}${S24} /24 shortlist:"
                #list_ips "$SUBNETS24_FILE" "$subnet24_count" 14
            #fi
            #if [ "$subnet16_count" -lt "15" ] && [ "$subnet16_count" -ne "0" ]; then 
                #echo
                #echo -e "${NC}${S16} /16 shortlist:"
                #list_ips "$SUBNETS16_FILE" "$subnet16_count" 14
            #fi

            echo -e "${NC}${CYN}========================"
            echo -e " VIPB-Compressor Done. "
            echo -e "■■■■■■■■■■■■■■■■■■■■■■■■${NC}"

        else
            echo
            echo -e "${RED}ERROR reading blacklist:${NC} $1"
            log "ERROR reading blacklist $1"
            return 1
        fi
    fi
}

function ban_core() { 
    lg "*" "ban_core $*"
    # ban_core blacklist.ipb [ipset_name]

    echo -e "${VLT}■■■■■■■■■■■■■■■■■■■■■■■■"
    echo -e "   VIPB-Ban started!"
    echo -e "■■■■■■■■■■■■■■■■■■■■■■■■${NC}"
    
    local modified=""
    blacklist="$1"
    ipset=${2:-"$VIPB_IPSET_NAME"}
    ERRORS=0
    ALREADYBAN_IPS=0
    ADDED_IPS=0
    if [ -f "$blacklist" ]; then
        modified=$(stat -c "%y" "$blacklist" | cut -d. -f1)
        echo -e "≡ Reading ${BLU}${BG}$blacklist${NC} [$modified]..."
        IPS=()
        while IFS= read -r ip; do
            if [[ -n "$ip" && "$ip" != "#"* ]]; then
                 if validate_ip "$ip"; then
                    IPS+=("$ip")
                else
                    echo -e "[" "$ip" "] ${ORG}invalid IP address${NC}"
                    ((ERRORS++))
                fi
            fi
        done < "$blacklist"
        total_blacklist_read=${#IPS[@]}
        echo -e "჻ Loaded ${VLT}${total_blacklist_read} sources${NC}." 
        log "Loaded $total_blacklist_read sources."
    else
        echo -e "${NC}Error: Blacklist file."
        log "@$LINENO: Error: Blacklist file" 
        exit 1
    fi

    if [ "$total_blacklist_read" -eq 0 ]; then
        echo -e "${RED}Error: No IPs found in list.${NC}"
        log "@$LINENO: Error: No IPs found in list."
        ((ERRORS++))
        err=1
    else
        echo -ne "  "
        if ! check_ipset "$ipset"; then
            if ! setup_ipset "$ipset"; then
                outcome="$?"
                echo -e "${RED}ipset error!${NC} $outcome"
                log "@$LINENO: Error: Failed to set up ipset. $outcome"
                ((ERRORS++))
                err=1
            fi
        fi

        echo -ne "  $FIREWALL ⇄ ipset rule "
        if check_firewall_rules "$ipset" ; then
            echo -e "${GRN}OK${NC}"
        else
            echo -e "${ORG}not found${NC}"
            echo -ne "  "
            add_firewall_rules "$ipset"
        fi
        echo
        if [ "$FIREWALL" == "firewalld" ] && [ -f "$blacklist" ] ; then
            echo -ne "  Adding entries to $FIREWALL from file... "
            if ! firewall-cmd --permanent --ipset="$ipset" --add-entries-from-file="$blacklist"; then
                err=$?
            fi
        else
            add_ips "$ipset" "${IPS[@]}"
            err=$? 
        fi
    fi
    count=$(count_ipset "$ipset")
    echo
    echo -e "${VLT}■■■■■■■■■■■■■■■■■■■■■■■■"
    echo -e "   VIPB-Ban finished "
    echo -e "========================"
    echo -e "${VLT} ჻ Loaded:  $total_blacklist_read"
    if [ $err -ne 0 ]; then
        echo -e "${RED} ✗${YLW} Errors:  $ERRORS check logs!${NC}"
    fi
    echo -e "${ORG} ◌  Known:  $ALREADYBAN_IPS"
    echo -e "${GRN} ✓  Added:  $ADDED_IPS"
    echo -e "${VLT}========================${NC}"
    echo -e "${BD} ≡  TOTAL:  $count banned${VLT}"
    echo -e "■■■■■■■■■■■■■■■■■■■■■■■■${NC}"

    log "========================"
    log " VIPB-Ban finished!"
    if [ $err -ne 0 ]; then
        log "WITH $ERRORS ERRORS!"
        log "a function failed ($err)"
    fi
    log "         Source:   $blacklist ($modified)"
    log "         Loaded:   $total_blacklist_read"
    log "          Added:   $ADDED_IPS"
    log "  Already known:   $ALREADYBAN_IPS"
    log "          TOTAL:   $count IPs/sources banned in ipset"
    
    return $err
}

debug_log "vipb-core.sh $( echo -e "${GRN}OK${NC}")"
log "▤ [CLI $CLI / DEBUG $DEBUG]"