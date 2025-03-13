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
IPSET_NAME='vipb-blacklist'
MANUAL_IPSET_NAME='vipb-manualbans'
# environment variables, do not change
BASECRJ='https://raw.githubusercontent.com/stamparm/ipsum/master/levels/'
BLACKLIST_URL="$BASECRJ${BLACKLIST_LV}.txt" 
RED='\033[31m'
GRN='\033[32m'
NC='\033[0m'
FIREWALL=''
NOF2B=false
INFOS=false
ADDED_IPS=0
ALREADYBAN_IPS=0
REMOVED_IPS=0
IPS=()

# VIPB Core functions

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

        #if [[ "$FIREWALLD" = "true" ]]; then
        #    FIREWALL="firewalld"
        if [[ "$IPTABLES" == "true" ]]; then
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

    CRON=$(check_service "cron")
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

function check_ipset() { #CLI
    lg "*" "check_ipset $*"
    if [ $# -lt 1 ]; then
        echo "You must provide ONE name for the ipset. > check_ipset ipset_name @$LINENO : $*"
        return 1 
    fi
    local ipsetname="$1"
    if ! ipset list "$1" >/dev/null; then
        echo -e "ipset ${BG}$1${NC} ${RED}does not exist${NC}"
    else
        echo -e "ipset ${BG}$1${NC} ${GRN}OK${NC}"
    fi
}

function reload_firewall() {
    lg "*" "reload_firewall"
    if [[ "$FIREWALL" == "firewalld" ]]; then
        echo -e "${YLW}Reloading $FIREWALL...${NC}"
        firewall-cmd --reload
        echo -e "Firewalld ${GRN}reloaded.${NC}"
        log "$FIREWALL reloaded"
    fi

    if [[ "$FAIL2BAN" == "true" ]]; then
        echo -e "${YLW}Fail2Ban detected. Reloading...${NC}"
        systemctl reload fail2ban
        echo -e "Fail2Ban ${GRN}reloaded.${NC}"
        log "Fail2Ban reloaded"a
    fi
}

function add_firewall_rules() { #2do
    lg "*" "add_firewall_rules FIREWALL = $FIREWALL : $*"
    
    local ipset=${1:-"$IPSET_NAME"}
    if [[ "$FIREWALL" = "firewalld" ]]; then
        # Firewalld
        if ! firewall-cmd --query-ipset="${ipset}" &>/dev/null; then
            echo "${YLW}Creating new firewalld ipset (permanent)...${NC}"
            firewall-cmd --permanent --new-ipset="${ipset}" --type=hash:net
            firewall-cmd --reload
        else
            echo -e "Firewalld${GRN} permanent ipset ${ipset} already exists.${NC}"
        fi
        
        if ! firewall-cmd --query-rich-rule="rule family='ipv4' source ipset='${ipset}' drop" &>/dev/null; then
            echo -e "${YLW}Adding firewalld rich-rule (permanent)...${NC}"
            firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source ipset='${ipset}' drop"
            firewall-cmd --reload
        else
            echo -e "Firewalld${GRN} permanent rich-rule for ${ipset} already exists.${NC}"
        fi
    fi
    # Iptables
    if ipset list "${ipset}" &>/dev/null; then
        if ! iptables -C INPUT -m set --match-set "${ipset}" src -j DROP &>/dev/null; then
            echo -e "${YLW}Adding iptables rule for ipset '${ipset}'...${NC}"
            #iptables -D INPUT -m set --match-set ipsum src -j DROP 2>/dev/null
            iptables -I INPUT -m set --match-set "${ipset}" src -j DROP
            # Salva le regole per salvarle, per renderle  persistenti vs netfilter-persistent
            # iptables-save > /etc/iptables/rules.v4
            echo -e "${GRN}iptables rule for ipset '${ipset}' added.${NC}"
        else
            echo -e "${GRN}iptables rule for ipset '${ipset}' already exists.${NC}"
        fi
    else
        echo -e "${RED}Error: ipset '${ipset}' does not exist${NC}"
        log "@$LINENO: Error: ipset '${ipset}' does not exist"
        exit 1
    fi
}

function setup_ipset() {
    lg "*" "setup_ipset $*"
    if [ $# -lt 1 ]; then
        echo "You must provide ONE name for the ipset. ERR@$LINENO setup_ipset(): $*"; return 1
    fi
    
    local ipsetname="$1"
   
    if ! ipset list "$ipsetname" >/dev/null; then
        echo -e "ipset ${BG}$ipsetname${NC} ${ORG}does not exist!${NC}"
        echo -e "${YLW}Creating ipset '${BG}$ipsetname${NC}'..."
        if [[ "$ipsetname" == "$MANUAL_IPSET_NAME" ]]; then
            ipset create "$ipsetname" hash:net maxelem 254
            echo -e "${BG}ipset create $ipsetname hash:net maxelem 254${NC} > ${GRN}OK"
        else
            ipset create "$ipsetname" hash:net maxelem 99999
            echo -e "${BG}ipset create $ipsetname hash:net maxelem 99999${NC} > ${GRN}OK"
        fi
        echo -e "ipset ${BG}$ipsetname ${GRN}created${NC}"
        log "$ipsetname created"
    else
        echo -e "ipset ${BG}$ipsetname ${GRN}exists${NC}"
        log "$ipsetname exists"
   fi
}

function ask_IPS() {
    IPS=()
    while true; do
        read -p "Insert IP (↵ to continue): " ip
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
    lg "*" "ask_IPS ${IPS[@]}"
}

function geo_ip() {
    lg "*" "geo_ip $*"
    if [ "$#" -gt 0 ]; then
        IPS=("$@") #intended to be used by default after ask_IPS()
    fi
    if command -v geoiplookup >/dev/null 2>&1; then
        #echo -e "Using ${S24}${BG}geoiplookup${NC} for IP geolocation${NC}"
        for ip in "${IPS[@]}"; do
            echo -e "Looking up IP: ${S16}$ip${S24}"
            geoiplookup "$ip"
            echo -ne "${NC}"
        done
    else
        echo -ne "geoiplookup not found,"
        if command -v geoiplookup >/dev/null 2>&1; then
            echo -e "using ${GRN}whois${NC} instead${NC}"
            for ip in "${IPS[@]}"; do
                echo -e "Looking up IP: $ip${NC}"
                whois "$ip" | grep -E "Country|city|address|organization|OrgName|NetName" 2>/dev/null
            done
        else
            echo -e "${ORG}whois not found.${NC}"
            echo -e "${RED}Geo IP not available."
        fi
    fi
}

function ban_ip() {  
    if [ $# -lt 2 ]; then
        echo "ERR@$LINENO  ${BG}ban_ip ipset_name 192.168.1.1:${NC} $*"
        return 1 
    fi
    
    local ipset_name="$1"
    local ip="$2" 
    debug_log "$FIREWALL" "$ipset_name" "$ip"
    
    local ban_ip_result=0
    
    if [[ "$FIREWALL" == "firewalld" ]]; then
        if ! firewall-cmd --query-ipset="${ipset_name}" &>/dev/null; then
            echo -e "${RED}Error: ipset ${BG}${ipset_name}${NC} does not exist.${NC} Please create one."
            log "@$LINENO: Error: ipset ${ipset_name} does not exist."
            return 1
        fi
        if firewall-cmd --ipset="${ipset_name}" --query-source="$ip" &>/dev/null; then
            ban_ip_result=2
        else
            firewall-cmd --permanent --ipset="${ipset_name}" --add-entry="$ip"
            # 2do EMEMBER TO RELOAD! (but not in this function)
            #   firewall-cmd --reload
            ban_ip_result=0
        fi
    elif [[ "$FIREWALL" == "iptables" ]]; then
        if [[ "$IPSET" == "true" ]]; then
            # ipset_path=$(which ipset)
            if ! ipset test "$ipset_name" "$ip" &>/dev/null; then
                ipset add "$ipset_name" "$ip"
                ban_ip_result=0
            else
                ban_ip_result=2
            fi
        else
            # use iptables only
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
    else
        echo -e "${RED}Error: No firewall system found!${NC}"
        log "@$LINENO: Error: No firewall system found."
        return 1
    fi

    case $ban_ip_result in
        0)  debug_log "IP $ip added to $FIREWALL in $ipset_name"
            ((ADDED_IPS++))
            if  [ "$INFOS" == "true" ]; then
                echo -ne "✚ ${GRN}IP $ip \t"
                if [ "$PERSISTENT" == "true" ]; then
                    echo -ne "permanently "
                fi
                echo -e "added${NC}" # to ${BG}$ipset_name${NC}
            else
                echo -ne "${GRN}✚${NC}"
            fi
            ;;
        1)  debug_log "IP $ip ban error"
            if [ "$INFOS" == "true" ]; then
                echo -e "⊗ ${RED}IP $ip \tban error${NC}"
            else
                echo -ne "${RED}⊗${NC}"
            fi
            ;;
        2)  debug_log "IP $ip already banned in $ipset_name"
            ((ALREADYBAN_IPS++))
            if [ "$INFOS" == "true" ]; then
                echo -e "◌ ${ORG}IP $ip \talready banned${NC}"
            else
                echo -ne "${ORG}◌${NC}"
            fi
            ;;
        *)  debug_log "? ban_ip_result: $ban_ip_result"
            ;;
    esac

    return $ban_ip_result
}

function add_ips() { 
    lg "*" "add_ips $@"
    #ipset ip1 ip2 ip3 ip4 ip5...
    if [ $# -lt 2 ]; then
        echo "You must provide one name for the ipset and AT LEAST one IP address. ERR@$LINENO add_ips(): $*"; return 1
    fi
    local ipset="$1"

    if [ "$IPSET" == "false" ]; then
        if [ "$FIREWALL" == "iptables" ]; then
            for ip in "${IPS[@]}"; do
                ban_ip "$MANUAL_IPSET_NAME" "$ip"
            done
        else
            echo "@$LINENO: Critical Error: cannot use ipset - not installed."
            log "@$LINENO: Critical Error: cannot use ipset - not installed."
            if [ ! "$DEBUG" == "true" ]; then
                exit 1
            fi
            return 1
        fi
    else
        log "Adding IPs into ipset $ipset..."
        echo -e "Adding ${GRN}${#IPS[@]} IPs${NC} into ipset ${BG}$ipset${NC}..."
        shift 
        local ips=("$@")  
        ADDED_IPS=0
        ALREADYBAN_IPS=0
        err=0
        ERRORS=0
        for ip in "${ips[@]}"; do
            ban_ip "$ipset" "$ip"
            err=$?
            if [[ "$err" == "1" ]]; then
                (($ERRORS++))
            fi
        done

        if [ $ERRORS -gt 0 ]; then
            return 1
        else
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
    if ipset test "$ipset_name" "$ip" &>/dev/null; then
        ipset del "$ipset_name" "$ip"
        ((REMOVED_IPS++))
        log "Unban IP $ip"
        echo -e "- ${GRN}IP $ip \tremoved${NC}"
    else
        echo -e "? ${ORG}IP $ip \tnot found${NC}"
        return 1
    fi
    return 0
}

function remove_ips () { 
    lg "*" "remove_ips $*"    
    #ipset ip1 ip2 ip3 ip4 ip5...
    if [ $# -lt 2 ]; then
        echo "You must provide ONE name for the ipset and AT LEAST one IP address."
        echo "ERR@$LINENO remove_ips ipset_name 192.168.1.1 192.168.1.2 192.168.1.3"
        echo "$@"
        return 1 
    fi
    local ipset_name="$1"
    shift                       # removes the first arg and shifts the others to the left
    local ips=("$@")  
    REMOVED_IPS=0
    for ip in "${ips[@]}"; do
        unban_ip "$ipset_name" "$ip"
    done
    echo -n $REMOVED_IPS
    return $REMOVED_IPS
}

function count_ipset() {
    lg "*" "count_ipset $*"
    if [ $# -lt 1 ]; then
        echo "You must provide ONE name for the ipset. ERR@$LINENO count_ipset ipset_name: $*" >&2
        return 1 
    fi
    
    local total_ipset=0
    
    if /usr/sbin/ipset list "$1" >/dev/null 2>&1; then
        total_ipset=$(/usr/sbin/ipset list "$1" | grep -c '^[0-9]')  
        echo -n "$total_ipset"
        return 0
    else
        echo -n "err"
        return 1
    fi
}

function check_blacklist_file() {
    lg "*" "check_blacklist_file $*"
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
        BLACKLIST_LV=${$select_lv:-4}
    done
    BLACKLIST_URL="$BASECRJ${BLACKLIST_LV}.txt" 

    # Update vipb-globals.sh with the new level
    sed -i "s/^BLACKLIST_LV=.*/BLACKLIST_LV=$BLACKLIST_LV/" "$SCRIPT_DIR/vipb-globals.sh"
    log "Level set to $BLACKLIST_LV"

}

function download_blacklist() {
    lg "*" "download_blacklist $1"

    local level=${1:-$BLACKLIST_LV}
    BLACKLIST_URL="$BASECRJ$level.txt"
    
    echo -e "${ORG}Downloading ${VLT}IPsum LV $level ${ORG}blacklist...${NC}"
    echo -e "${BG}$BLACKLIST_URL${NC}"
    echo
    
    if ! curl -o "$BLACKLIST_FILE" "$BLACKLIST_URL"; then
        echo -e "${RED}Error: Failed to download the IPsum Blacklist file.${NC}"
        log "@$LINENO: Error: Failed download"
        return 1
    fi

    echo
    echo -e "${GRN}IPsum Blacklist file [${VLT}LV $level${GRN}] downloaded successfully.${NC}"
    line_count=$(wc -l < "$BLACKLIST_FILE")
    echo -e "New IPsum Blacklist contains ${VLT}$line_count${NC} suspicious/malicious IPs."
    log "Downloaded IPsum Blaclist @ LV $level ($line_count IPs)"
    return 0
}
 
function compressor() {                                     
    lg "*" "compressor [CLI=$CLI] $@"
   
    list_file=${1:-"$BLACKLIST_FILE"}
    
    echo -ne "≡ VIPB-Blacklist file ${BG}${BLU}$list_file${NC}... "

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
            #echo -e "${GRN}$total_ips IPs in list. ${NC}"
            echo

            # Default occurrence tolerance levels
            c24=3
            c16=4
            
            if [ "$CLI" == "false" ]; then
                echo -e "${NC}Set occurrence tolerance levels [2-9] ${DM}[Exit with 0]${NC}"
                while true; do
                    echo -ne "${NC}  for ${S24}/24 subnets${NC} (#.#.#.\e[37m0${NC}): ${S24}" 
                    read ip_occ
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
                    echo -ne "${NC}  for ${S16}/16 subnets${NC} (#.#.\e[37m0.0${NC}): ${S16}" 
                    read ip_occ
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
            echo -e "${CYN}START PROCESSING ..."
            log "====================="
            log "Start compression > /16 @ $c16 | /24 @ $c24"

            awk -F'.' '{print $1"."$2"."$3".0/24 " $0}' "$list_file" | \
                sort > "$temp_file"
            awk -F'[ .]' -v c="$c24" '{print $1"."$2"."$3".0/24"}' "$temp_file" | \
                sort | uniq -c | awk -v c="$c24" '$1 >= c {print $2}' > "$SUBNETS24_FILE"
            sed 's/\([0-9]\+\.[0-9]\+\)\.[0-9]\+\.0\/24/\1.0.0\/16/' "$SUBNETS24_FILE" | \
                sort | uniq -c | \
                awk -v c="$c16" '$1 >= c {print $2}' > "$SUBNETS16_FILE"

            # Create  optimized list
            # /16 #.#.0.0
            echo -ne "${S16}◣ /16 subnets${NC} (#.#.\e[37m0.0${NC})...   ${NC}"
            cat "$SUBNETS16_FILE" > "$OPTIMIZED_FILE"
            subnet16_count=$(wc -l < "$SUBNETS16_FILE")
            echo -e "${GRN}Done. ${NC}"
            
            # /24 #.#.#.0
            echo -ne "${S24}◣ /24 subnets${NC} (#.#.#.\e[37m0${NC})...   ${NC}"
            while read -r subnet16; do
                prefix16=$(echo "$subnet16" | cut -d'/' -f1 | sed 's/\.0\.0$//')
                grep -v "^$prefix16" "$SUBNETS24_FILE" > "$remaining_24_temp"
                mv "$remaining_24_temp" "$SUBNETS24_FILE"
            done < "$SUBNETS16_FILE"
            cat "$SUBNETS24_FILE" >> "$OPTIMIZED_FILE"
            subnet24_count=$(wc -l < "$SUBNETS24_FILE")
            echo -e "${GRN}Done. ${NC}"
            
            # IPs #.#.#.#    
            echo -ne "${BLU}◣ Single IPs...              ${NC}"
            while read -r subnet24; do
                subnet_prefix=$(echo "$subnet24" | cut -d'/' -f1 | sed 's/\.0$//')
                grep -v "^$subnet_prefix" "$temp_file" > "$subnet_temp"
                mv "$subnet_temp" "$temp_file"
            done < "$SUBNETS24_FILE"
            while read -r subnet16; do
                prefix16=$(echo "$subnet16" | cut -d'/' -f1 | sed 's/\.0\.0$//')
                grep -v "^$prefix16" "$temp_file" > "$subnet_temp"
                mv "$subnet_temp" "$temp_file"
            done < "$SUBNETS16_FILE"
            awk '{print $2}' "$temp_file" >> "$OPTIMIZED_FILE"
            optimized_count=$(wc -l < "$OPTIMIZED_FILE")
            echo -e "${GRN}Done. ${NC}"
            
            single_count=$((optimized_count - subnet16_count - subnet24_count))
            cut_count=$((total_ips - single_count))
            log "====================="
            log "Compression finished!"
            log "====================="
            log "$total_ips Total IPs processed to"
            log "$optimized_count compressed sources."
            log "$single_count single IPs"
            log "$cut_count source IPs compressed into"
            log "$subnet24_count /24 subnets (@ $c24 ) and"
            log "$subnet16_count /16 subnets (@ $c16 )"
            log "====================="
            #echo 
            #echo "•  ┏  ";
            #echo "┓┏┓╋┏┓";
            #echo "┗┛┗┛┗┛ ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰";
            echo -e "${GRN}IPs to Subnets aggregation finished!${NC}"
            echo
            echo -e "    Total processed:\t ${VLT}$total_ips IPs ${NC}  \t  100% ◕ "
            echo -e "         ${CYN}reduced to:\t${NC}╔${CYN}$optimized_count sources${NC} \t   $((optimized_count * 100 / total_ips))% ◔ "
            echo -e "                    \t║"
            echo -e "         single IPs:\t╟${CYN}$single_count IPs${NC} \t[  \e[3m$((single_count * 100 / total_ips))%${NC} ]"
            echo -e "       ╔ aggregated:\t║${ORG}$cut_count IPs${NC}\t[  \e[3m$((100-(single_count * 100 / total_ips)))%${NC} ]"
            echo -e "       ╙ reduced to:\t╙${CYN}$((subnet24_count + subnet16_count)) subnets ${NC}"
            echo -e "${S24}          /24 @ x$c24 :\t $subnet24_count subnets${NC}\t(#.#.#.\e[37m0${NC})"
            echo -e "${S16}          /16 @ x$c16 :\t $subnet16_count subnets${NC}\t(#.#.\e[37m0.0${NC})"
            
            list_ips(){
            if [ "$2" -lt "$3" ]; then
                while read -r subnet; do
                    echo -e "\t\t\t$subnet"
                done < "$1"
            fi
            }
            
            if [ "$subnet24_count" -lt "15" ]; then 
                echo -e "${S24}  subs /24 shortist:${NC}"
                list_ips "$SUBNETS24_FILE" "$subnet24_count" 14
            fi

            if [ "$subnet16_count" -lt "15" ]; then 
                echo -e "${S16}  subs /16 shortist:${NC}"
                list_ips "$SUBNETS16_FILE" "$subnet16_count" 14
            fi
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
    echo -e "${VLT}▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰"
    echo -e "      VIPB-Ban started!"
    echo -e "▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰${NC}"
    
    # ban_core blacklist (ipset_name)

    local modified=""
    blacklist="$1"
    ipset=${2:-"$IPSET_NAME"}
    ERRORS=0
    if [ -f "$blacklist" ]; then
        modified=$(stat -c "%y" "$blacklist" | cut -d. -f1)
        echo -e "Reading from ${BLU}${BG}$blacklist${NC} [$modified]..."
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
        echo -e "Loaded ${VLT}${total_blacklist_read} IPs${NC} from list." 
        log "Loaded $total_blacklist_read IPs."
    else
        echo -e "${NC}Error: Blacklist file."
        log "@$LINENO: Error: Blacklist file" 
        exit 1
    fi

    if [ "$total_blacklist_read" -eq 0 ]; then
        echo -e "${RED}Error: No IPs found in file.${NC}"
        log "@$LINENO: Error: No IPs found in file."
        err=1
    else
        setup_ipset "$ipset"
        add_ips "$ipset" "${IPS[@]}"   
        err=$? 
        echo
    fi

    count=$(count_ipset "$ipset")
    
    echo -e "${GRN}▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰"
    echo -e "      VIPB-Ban finished "
    if [ $err -ne 0 ]; then
        echo -e " ⊗ ${YLW}with $ERRORS errors.. check logs!"
    fi
    echo -e "▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰${NC}"
    echo -e "${VLT}   Loaded:   $total_blacklist_read"
    echo -e "${ORG} ◌ Listed:   $ALREADYBAN_IPS"
    echo -e "${GRN} ✚  Added:   $ADDED_IPS"
    echo -e "${GRN}    TOTAL:   $count banned${NC}"
    echo "▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰"
    log "▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰"
    log " VIPB-Ban finished!"
    if [ $err -ne 0 ]; then
        log "WITH $ERRORS ERRORS!"
        log "Function add_ipset() failed: $err"
    fi
    log "▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰"
    log "         Source:   $blacklist ($modified)"
    log "         Loaded:   $total_blacklist_read"
    log "          Added:   $ADDED_IPS"
    log "Already present:   $ALREADYBAN_IPS"
    log "          TOTAL:   $count IPs/sources banned in ipset"
    log "▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰"
    
    return $err
}

debug_log "vipb-core.sh $( echo -e "${GRN}OK${NC}")"
log "▤ [CLI $CLI / DEBUG $DEBUG]"