#!/bin/bash
set -o pipefail

# Variables & Logging
# set the blacklisted IPsum level (2-8, default 3)
BLACKLIST_LV=4
# set the default files names and path
BLACKLIST_FILE="$SCRIPT_DIR/vipb-blacklist.ipb"
OPTIMIZED_FILE="$SCRIPT_DIR/vipb-optimised.ipb"
SUBNETS24_FILE="$SCRIPT_DIR/vipb-subnets24.ipb"
SUBNETS16_FILE="$SCRIPT_DIR/vipb-subnets16.ipb"
# set the name of the ipsets used by VIPB
IPSET_NAME='vipb-blacklist'
MANUAL_IPSET_NAME='vipb-manualbans'
# environment variables, DO NOT CHANGE
BASECRJ='https://raw.githubusercontent.com/stamparm/ipsum/master/levels/'
BLACKLIST_URL="$BASECRJ${BLACKLIST_LV}.txt" 
FIREWALL='iptables'
#NOF2B=false
INFOS=false
ADDED_IPS=0
ALREADYBAN_IPS=0
REMOVED_IPS=0
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

        if [[ -n "$FIREWALL" ]]; then
            FIREWALL="$FIREWALL"
        elif [[ "$IPTABLES" == "true" ]]; then
            FIREWALL="iptables"
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

    PERSISTENT=$(check_service "netfilter-persistent")
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
    #2do not checking proper ipset
    if [[ "$FIREWALL" == "firewalld" ]]; then
        if ! firewall-cmd --permanent --get-ipsets | grep -q "$ipset_name"; then
            echo -e "ipset ${BG}$ipset_name${NC} ${RED}does not exist${NC}"
            return 1
        else
            echo -e "ipset ${BG}$ipset_name${NC} ${GRN}OK${NC}"
            return 0
        fi
    elif [[ "$FIREWALL" == "iptables" && "$IPSET" == "true" ]]; then
        if ! ipset list "$ipset_name" >/dev/null; then
            echo -e "ipset ${BG}$ipset_name${NC} ${RED}does not exist${NC}"
            return 1
        else
            echo -e "ipset ${BG}$ipset_name${NC} ${GRN}OK${NC}"
            return 0
        fi
    else
        echo "2do!"
        return 1
    fi
}

# ============================
# Section: Firewall
# ============================

function reload_firewall() {
    lg "*" "reload_firewall"
    if [[ "$FIREWALL" == "firewalld" ]]; then
        echo -ne "Reloading ${ORG}$FIREWALL${NC}... "
        firewall-cmd --reload
        log "$FIREWALL reloaded"
    fi

    if [[ "$FAIL2BAN" == "true" ]]; then
        echo -e "${YLW}Fail2Ban... (disabled #2do)${NC}"
        #systemctl reload fail2ban
        #echo -e "Fail2Ban ${GRN}reloaded.${NC}"
        #log "Fail2Ban reloaded"a
    fi
}

function add_firewall_rules() {
    lg "*" "add_firewall_rules FIREWALL = $FIREWALL : $*"
    
    local ipset=${1:-"$IPSET_NAME"}
    err=0

    if check_ipset "$ipset"; then
        if [[ "$FIREWALL" == "firewalld" ]]; then        
            if firewall-cmd --permanent --zone=drop --add-source=ipset:"$ipset" &>/dev/null; then
                echo "reload_firewall"
            else
                echo -e "$?"
                err=1
            fi
        elif [[ "$FIREWALL" == "iptables" ]]; then

            function save_iptables_rules() {

                if command -v netfilter-persistent >/dev/null 2>&1; then
                    netfilter-persistent save
                    return $?
                else
                    echo "netfilter-persistent not found, falling back to manual save" >&2
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
            }

            if ! iptables -C INPUT -m set --match-set "${ipset}" src -j DROP &>/dev/null; then
                iptables -I INPUT -m set --match-set "${ipset}" src -j DROP  
                if save_iptables_rules; then
                    echo "Info: Rules added and saved to /etc/iptables/rules.v4"
                else
                    echo "Warning: Rules added but permanent save failed" >&2
                fi
            else
                echo -e "$?"
                err=1
            fi

        elif [[ "$FIREWALL" == "ufw" ]]; then
            echo "ufw 2do"
            err=1
        fi
    else
        echo -e "${RED}Error: ipset $ipset not found!${NC} Create it first."
        err=1
    fi


    return $err
}

function remove_firewall_rules() { 
    lg "*" "remove_firewall_rules FIREWALL = $FIREWALL : $*"
    
    local ipset=${1:-"$IPSET_NAME"}
    err=0

    if [[ "$FIREWALL" == "iptables" ]]; then
        if iptables -C INPUT -m set --match-set "$ipset" src -j DROP 2>/dev/null; then
            iptables -D INPUT -m set --match-set "$ipset" src -j DROP
            return 0
        else
            err=1
        fi
    elif [[ "$FIREWALL" == "firewalld" ]]; then
        for zone in $(firewall-cmd --get-zones); do
            echo -ne "zone $zone... "
            if firewall-cmd --permanent --zone="$zone" --query-source=ipset:"$ipset" >/dev/null 2>&1; then
                firewall-cmd --permanent --zone="$zone" --remove-source=ipset:"$ipset"
                echo "found"
                #reload_firewall
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

# ============================
# Section: IPs & sets
# ============================

function setup_ipset() { 
    lg "*" "setup_ipset $*"
    
    local ipset_name="$1"
    err=0

    if [[ "$IPSET" == "true" ]]; then
        if [[ "$ipset_name" == "$MANUAL_IPSET_NAME" ]]; then
            maxelem=254
        else
            maxelem=99999
        fi

        if ! check_ipset "$ipset_name" &>/dev/null; then
            echo -ne "Creating '${BG}$ipset_name${NC}' in system ipset... "
            if ipset create "$ipset_name" hash:net maxelem "$maxelem"; then
                echo -e "${GRN}created${NC}"
                log "$ipset_name created"
            else
                echo "$?"
                err=1
            fi

        else
            log "$ipset_name exists"
        fi

        if [[ "$FIREWALL" == "firewalld" ]]; then

            echo -ne "ipset '${BG}$ipset_name${NC}' reference in $FIREWALL... "                       
            if firewall-cmd --permanent --new-ipset="$ipset_name" --type=hash:net --option=maxelem="$maxelem" ; then
                echo -e "${GRN}created${NC}"
                log "$ipset_name created"
            else
                echo "$?"
                err=1
            fi
            
            
            log "$ipset_name linked"
        fi
    else
        echo "ipset not true"
        debug_log "@$LINENO #2do!" #2do
        return 1
    fi    

    return $err
}

function destroy_ipset() {
    lg "*" "remove_ipset $*"
    
    local ipset_name="$1"
    err=0

    if [[ "$IPSET" == "true" ]]; then
        echo -ne "Destroying ipset '${BG}$ipset_name${NC}' in system... "
        if check_ipset "$ipset_name" &>/dev/null; then
            ipset destroy "$ipset_name"
            echo -e "${RED}destroyed${NC}"
            log "$ipset_name destroyed"
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

function remove_ipset() {
    lg "*" "remove_ipset $*"
    
    local ipset_name="$1"
    err=0

    if [[ "$FIREWALL" == "firewalld" ]]; then
        echo -ne "Removing ipset '${BG}$ipset_name${NC}' reference from $FIREWALL... "
        if check_ipset "$ipset_name" &>/dev/null; then
            firewall-cmd --permanent --delete-ipset="$ipset_name"
            echo -e "${GRN}OK${NC}"
            log "$ipset_name unlinked"
            #reload_firewall
        else
            echo -e "${ORG}none found!${NC}"
            err=1
        fi
    fi

    if [[ "$FIREWALL" == "iptables" ]]; then
        destroy_ipset "$ipset_name"
    elif [[ "$FIREWALL" == "ufw" ]]; then
        echo "2do!"
        debug_log "#2do!" #2do
        return 1
    fi

    return $err
}

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
            
            if firewall-cmd --permanent --ipset="${ipset_name}" --query-entry="$ip" &>/dev/null; then
                ban_ip_result=2
            else
                firewall-cmd --permanent --ipset="${ipset_name}" --add-entry="$ip" &>/dev/null
                case "$?" in #2check
                    0)
                        ban_ip_result=0
                        ;;
                    135)
                        # 136 = INVALID IPSET 
                        log "@$LINENO Error: INVALID IPSET. err# $? ip:$ip"
                        ban_ip_result=1
                        ;;
                    136)
                        # 136 = INVALID_ENTRY 
                        log "@$LINENO Error: INVALID_ENTRY. err# $? ip:$ip"
                        ban_ip_result=1
                        ;;
                    *)
                        log "@$LINENO Error: Unexpected result from firewalld command. err# $? ip:$ip"
                        ban_ip_result=1
                        ;;
                esac
            fi
                
        elif [[ "$FIREWALL" == "iptables" ]]; then
            if [[ "$IPSET" == "true" ]]; then
                if ! ipset test "$ipset_name" "$ip" &>/dev/null; then
                    ipset add "$ipset_name" "$ip"
                    ban_ip_result=0
                else
                    ban_ip_result=2
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
            echo -e "${YLW}DEVELOPMENT: ufw not supported yet!${NC} " #2do
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
    #add_ips ipset_name [ip.ad.re.ss]
    
    local ipset="$1"

    if [ "$IPSET" == "false" ]; then
        #2do
        echo "@$LINENO: Critical Error: cannot use ipset - not installed."
        log "@$LINENO: Critical Error: cannot use ipset - not installed."
        if [ ! "$DEBUG" == "true" ]; then
            exit 1
        fi
        return 1

    else
        log "Adding IPs into ipset $ipset..."
        shift 
        local ips=("$@")  
        echo -e "Adding ${GRN}${#ips[@]} IPs${NC} into ipset ${BG}$ipset${NC}..."
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

        if [ $ERRORS -gt 0 ]; then
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

function count_ipset() {
    # lg "*" "count_ipset $*"
    
    local ipset_name="$1"
    local total_ipset=0
    
    if [[ "$FIREWALL" == "firewalld" ]]; then
        if check_ipset "$ipset_name" &>/dev/null; then       
            list_ipset_entries() {
                local ipset_name="$1"
                # For permanent configuration
                #firewall-cmd --permanent --ipset="$ipset_name" --get-entries
                local perm_entries=$(firewall-cmd --permanent --ipset="$ipset_name" --get-entries)
                local perm_count=0
                if [[ -n "$perm_entries" ]]; then
                    perm_count=$(echo "$perm_entries" | wc -l)
                fi

                # For runtime configuration
                #firewall-cmd --ipset="$ipset_name" --get-entries
                local run_entries=$(firewall-cmd --ipset="$ipset_name" --get-entries)
                local run_count=0
                if [[ -n "$run_entries" ]]; then
                    run_count=$(echo "$run_entries" | wc -l)
                fi


                echo  "$perm_count | $run_count"
            }

            list_ipset_entries "$ipset_name"
            return 0
        else
            echo -n "n/a"
            return 1
        fi
    elif [[ "$FIREWALL" == "iptables" ]]; then
        if [[ "$IPSET" == "true" ]]; then
            if check_ipset "$ipset_name" &>/dev/null; then
                total_ipset=$(/usr/sbin/ipset list "$ipset_name" | grep -c '^[0-9]')  
                echo -n "$total_ipset"
                return 0
            else
                echo -n "n/a"
                return 1
            fi
        else
            echo -n "2do"
            return 1
        fi
    elif [[ "$FIREWALL" == "ufw" ]]; then
            echo -n "2do"
            return 1
    fi
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
            echo -e "${CYN}■■■■■■■■■■■■■■■■■■■■■■■■■■"
            echo -e "   VIPB-Compressor Start "
            echo -e "=========================="
            echo -ne "${VLT}◣ IPs list                ${NC}"
            log "====================="
            log "Start compression > /16 @ $c16 | /24 @ $c24"

            awk -F'.' '{print $1"."$2"."$3".0/24 " $0}' "$list_file" | \
                sort > "$temp_file"
            awk -F'[ .]' -v c="$c24" '{print $1"."$2"."$3".0/24"}' "$temp_file" | \
                sort | uniq -c | awk -v c="$c24" '$1 >= c {print $2}' > "$SUBNETS24_FILE"
            sed 's/\([0-9]\+\.[0-9]\+\)\.[0-9]\+\.0\/24/\1.0.0\/16/' "$SUBNETS24_FILE" | \
                sort | uniq -c | \
                awk -v c="$c16" '$1 >= c {print $2}' > "$SUBNETS16_FILE"
            echo -e "${GRN}Done. ${VLT}($total_ips IPs)${NC}"

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
            echo -e "${GRN}Done. ${S24}($subnet24_count subnets x$c24)${NC}"
            echo -ne "${S16}◣ /16 subnets${NC} (#.#.${BG}0.0${NC})   ${NC}"
            while read -r subnet16; do
                prefix16=$(echo "$subnet16" | cut -d'/' -f1 | sed 's/\.0\.0$//')
                grep -v "^$prefix16" "$temp_file" > "$subnet_temp"
                mv "$subnet_temp" "$temp_file"
            done < "$SUBNETS16_FILE"
            echo -e "${GRN}Done. ${S16}($subnet16_count subnets x$c16)${NC}"

            echo -ne "${BLU}◣ Writing to file...      ${NC}"
            awk '{print $2}' "$temp_file" >> "$OPTIMIZED_FILE"
            optimized_count=$(wc -l < "$OPTIMIZED_FILE")
            single_count=$((optimized_count - subnet16_count - subnet24_count))            
            cut_count=$((total_ips - single_count))
            
            prog_ips=$((single_count * 100 / total_ips))
            prog_nets=$(((subnet24_count + subnet16_count) * 100 / total_ips))
            progress=$((prog_ips + prog_nets))
            
            filips=$((prog_ips / 2))
            filnets=$((prog_nets / 2))
            filled=$((progress / 2))
            empty=$((50 - filled))
            barips=$(printf "%0.s■" $(seq 1 $filips))
            barnets=$(printf "%0.s■" $(seq 1 $filnets))
            spaces=$(printf "%0.s□" $(seq 1 $empty))     

            echo -e "${GRN}Done. ${BLU}($total_ips sources)${NC}"

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
            
            echo
            echo -e "${GRN}Blacklist aggregation finished!${NC}"
            echo -e "${CYN}[${barips}${S16}${barnets} ${progress}% ${CYN}${spaces}]${NC}"
            echo
            echo -e "    Total processed\t100% ◕  ${VLT}$total_ips IPs ${NC}"
            echo -e "         ${CYN}reduced to${NC}\t $progress% ◔  ${CYN}$optimized_count sources${NC}"
            echo -e "   "
            echo -e "               from\t ${BG}$((100-(single_count * 100 / total_ips)))%${NC}  ╔ ${VLT}$cut_count IPs${NC}"
            echo -e "                 to\t ${BG} $((progress - (single_count * 100 / total_ips)))%${NC}  ╙ ${CYN}$((subnet24_count + subnet16_count)) subnets +${NC}"
            echo -e "       uncompressed\t ${BG}$((single_count * 100 / total_ips))%${NC}    ${CYN}$single_count IPs${NC}"
            echo            
            list_ips(){
            if [ "$2" -lt "$3" ]; then
                while read -r subnet; do
                    echo -e "\t\t\t$subnet"
                done < "$1"
            fi
            }
            
            if [ "$subnet24_count" -lt "15" ]; then 
                echo -e "${S24}       /24 shortist:"
                list_ips "$SUBNETS24_FILE" "$subnet24_count" 14
            fi

            if [ "$subnet16_count" -lt "15" ]; then 
                echo -e "${NC}${S16}       /16 shortist:"
                list_ips "$SUBNETS16_FILE" "$subnet16_count" 14
            fi
            echo -e "${NC}"
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

    echo -e "${VLT}■■■■■■■■■■■■■■■■■■■■■■■■■■"
    echo -e "    VIPB-Ban started!"
    echo -e "■■■■■■■■■■■■■■■■■■■■■■■■■■${NC}"
    
    local modified=""
    blacklist="$1"
    ipset=${2:-"$IPSET_NAME"}
    ERRORS=0
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
        echo -e "${RED}Error: No IPs found in file.${NC}"
        log "@$LINENO: Error: No IPs found in file."
        ((ERRORS++))
        err=1
    else
        echo -ne "  "
        if setup_ipset "$ipset"; then
            echo
            add_ips "$ipset" "${IPS[@]}"
            err=$? 
        else
            echo -e "${RED}Error: Failed to set up ipset.${NC}"
            log "@$LINENO: Error: Failed to set up ipset."
            ((ERRORS++))
            err=1
        fi
        echo
    fi

    count=$(count_ipset "$ipset")
    
    echo -e "${VLT}■■■■■■■■■■■■■■■■■■■■■■■■■■"
    echo -e "    VIPB-Ban finished "
    echo -e "=========================="
    echo -e "${VLT} ჻ Loaded:  $total_blacklist_read"
    if [ $err -ne 0 ]; then
        echo -e "${RED} ✗${YLW} Errors:  $ERRORS check logs!${NC}"
    fi
    echo -e "${ORG} ◌  Known:  $ALREADYBAN_IPS"
    echo -e "${GRN} ✓  Added:  $ADDED_IPS"
    echo -e "${VLT}==========================${NC}"
    echo -e "${BD} ≡  TOTAL:  $count banned${VLT}"
    echo -e "■■■■■■■■■■■■■■■■■■■■■■■■■■${NC}"

    log "■■■■■■■■■■■■■■■■■■■■■■■■■■"
    log " VIPB-Ban finished!"
    if [ $err -ne 0 ]; then
        log "WITH $ERRORS ERRORS!"
        log "Function add_ipset() failed: $err"
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