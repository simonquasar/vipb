#!/bin/bash

# VIPB Core functions

# Call core vars & settings
source "$SCRIPT_DIR/vipb-globals.sh" "$@"

# VIPB Core functions

function check_dependencies() { #needs rewrite 
    err=0
    
    #   1. Check Services check_service
    #       - list.. (for glob vars?)
    #   2. Check Firewalls check_firewall (uses check_service & global vars)
    #   3. Checks ipset / cron / curl global vars(???)
    #   mhh
    #   

    check_service() {
        local service_name=$1
        
        if [ -f /.dockerenv ] || [ -f /run/.containerenv ] || grep -q container=lxc /proc/1/environ 2>/dev/null; then
            if pgrep -f "$service_name" >/dev/null; then
                return 0
            else
                return 1
            fi
        fi

        if command -v systemctl &>/dev/null; then
            if systemctl is-active --quiet "$service_name" 2>/dev/null; then
                return 0
            fi
            if systemctl status "$service_name" 2>/dev/null | grep -q "active (exited)"; then
                return 0
            fi
            return 1
        fi

        if command -v service &>/dev/null; then
            service "$service_name" status &>/dev/null
            return $?
        fi

        log "check_service $1 fail"
        return 1
    }

    function check_firewall() { #??
        if command -v firewall-cmd &> /dev/null && check_service firewalld; then
            USE_FIREWALLD=true
            FIREWALL="firewalld"
        elif [ -x "/sbin/iptables" ]; then
            USE_FIREWALLD=false
            FIREWALL="iptables"
        else
            echo -e "${RED}@$LINENO: Critical Error: No firewall system found?!${NC} ${FIREWALL}"
            log "@$LINENO: Critical Error: No firewall system found."
            FIREWALL="ERROR"
            err=1
            if [ ! "$DEBUG" == "true" ]; then
                exit 1
            fi
        fi
        return $err    
    }

    check_firewall

    IPSET=true
    if ! command -v ipset &> /dev/null; then
        if [ "$CLI" == "false" ]; then
            echo -e "\033[31mError: ipset is not installed!\033[0m"
        fi
        log "@$LINENO: Error: ipset is not installed."
        IPSET=false
        err=0
    fi

    CRON=true
    if ! command -v cron &> /dev/null && ! command -v crond &> /dev/null; then
        if [ "$CLI" == "false" ]; then
            echo -e "\033[38;5;11mWarning: cron/crond not found!\033[0m"
        fi
        log "@$LINENO: Warning: cron/crond not found."
        CRON=false
    fi

    CURL=true
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: curl is not installed!"
        log "@$LINENO: Error: curl is not installed."
        CURL=false
    fi
    
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
    log "check_ipset $*"
    if [ $# -lt 1 ]; then
        echo "You must provide ONE name for the ipset. > check_ipset ipset_name @$LINENO : $*"
        return 1 
    fi
    local ipsetname="$1"
    if ! ipset list "$1" >/dev/null; then
        echo -e "${RED}ipset ${BG}$1${NC} does not exist.${NC}"
    else
        echo -e "${GRN}ipset ${BG}$1${NC} OK${NC}"
    fi
}

function reload_firewall() {
    log "reload_firewall"
    if [[ "$USE_FIREWALLD" == "true" ]]; then
        echo -e "${YLW}Restarting Firewalld...${NC}"
        firewall-cmd --reload
        echo -e "${GRN}Firewalld reloaded.${NC}"
        log "$FIREWALL reloaded"
    fi
    
    if systemctl is-active --quiet fail2ban; then
        echo -e "${YLW}Fail2Ban detected. Reloading...${NC}"
        systemctl reload fail2ban
        echo -e "${GRN}Fail2Ban reloaded.${NC}"
        log "Fail2Ban reloaded"
    else
        echo -e "${ORG}Fail2Ban not running or not installed.${NC}"
    fi
}

function add_firewall_rules() {
    log "add_firewall_rules USE_FIREWALLD = $USE_FIREWALLD : $*"
    
    local ipset=${1:-"$IPSET_NAME"}
    if [[ "$USE_FIREWALLD" = "true" ]]; then
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
            # Salva le regole per renderle persistenti
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
    log "setup_ipset $*"
    if [ $# -lt 1 ]; then
        echo "You must provide ONE name for the ipset. ERR@$LINENO setup_ipset(): $*"; return 1
    fi
    
    local ipsetname="$1"
   
    if ! ipset list "$ipsetname" >/dev/null; then
        echo -e "ipset ${BG}$ipsetname${NC} ${ORG}does not exist.${NC}"
        echo -e "${YLW}Creating ipset '${BG}$ipsetname${NC}'..."
        ipset create "$ipsetname" hash:net maxelem 99999
        echo -e "ipset ${BG}$ipsetname hash:net maxelem 99999${NC} > ${GRN}done"
        #echo -e "${YLW}Adding firewall rules ${NC}..."
        add_firewall_rules "$ipsetname"
        echo -e "$FIREWALL rules for ${BG}$ipsetname ${GRN}added${NC}"
        reload_firewall
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
            return 1
        fi
    done
}

function ban_ip() { #2do  better ban and fw checks 
    if [ $# -lt 2 ]; then
        echo "ERR@$LINENO  ${BG}ban_ip ipset_name 192.168.1.1:${NC} $*"
        return 1 
    fi
    
    local ipset_name="$1"
    local ip="$2" 
    debug_log "$USE_FIREWALLD" "$IPSET" "$ipset_name" "$ip" "$FIREWALL"
    
    local ban_ip_result=0
    
    if [[ "$USE_FIREWALLD" == "true" ]]; then
        if ! firewall-cmd --query-ipset="${ipset_name}" &>/dev/null; then
            echo -e "${RED}Error: ipset ${BG}${ipset_name}${NC} does not exist.${NC} Please create one."
            log "@$LINENO: Error: ipset ${ipset_name} does not exist."
            return 1
        fi
        if firewall-cmd --ipset="${ipset_name}" --query-source="$ip" &>/dev/null; then
            ban_ip_result=2
        else
            firewall-cmd --permanent --ipset="${ipset_name}" --add-entry="$ip"
            # REMEMBER TO RELOAD! (but not in this function)
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
                echo -ne "+ ${GRN}IP $ip \t"
                if [[ "$USE_FIREWALLD" == "true" ]]; then
                    echo -ne "permanently"
                fi
                echo -e "added${NC} $ipset_name"
            else
                echo -ne "${GRN}+${NC}"
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
    #log "add_ips $@"
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
        echo -e "${YLW}Adding IPs into ipset ${VLT}$ipset${NC}${YLW}...${NC}"
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
        if [[ "$USE_FIREWALLD" == "true" ]]; then
            reload_firewall
        fi
        echo
        if [ $ERRORS -gt 0 ]; then
            return 1
        else
            return 0
        fi
    fi
}

function unban_ip() {
    if [ $# -lt 2 ]; then
        echo "You must provide ONE name for the ipset and ONE IP address. ERR@$LINENO unban_ip ipset_name 192.168.1.1 / $@"
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
    if [ $# -lt 1 ]; then
        echo "You must provide ONE name for the ipset. ERR@$LINENO count_ipset ipset_name: $@" >&2
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
                echo -ne "${ORG}empty ${NC}\t\t$line_count lines\t$file_size KB\t$MODIFIED \t${BG}$1"
            else
                echo -ne "${GRN}found ${NC}\t\t$line_count lines\t$file_size KB\t$MODIFIED \t${BG}$1"
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
    log "set_blacklist_level $1"
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
    log "download_blacklist $1"

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
    log "Downloaded IPsum Blaclist @ LV $BLACKLIST_LV ($line_count)"
    return 0
}

function compressor() {                                     
    log "compressor [CLI=$CLI] $@"
   
    list_file=${1:-"$BLACKLIST_FILE"}
    
    echo -ne "Loading Blacklist file ${BG}$list_file${NC}... "

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
            echo -e "${VLT}$total_ips IPs in list. ${NC}"

            # Default occurrence tolerance levels
            c24=3
            c16=4
            
            echo
            if [ "$CLI" == "false" ]; then
                echo -e "${NC}Set occurrence tolerance levels (2-9)${NC}"
                while true; do
                    echo -ne "${NC}  for ${S24}/24 subnets${NC} (#.#.#.\e[37m0${NC}): ${S24}" 
                    read ip_occ
                    if [[ "$ip_occ" =~ ^[2-9]$ ]]; then
                        c24="$ip_occ"
                        break
                    else
                        echo -e "${NC}Invalid input. Please enter a number between 2 and 9."
                    fi
                done
                while true; do
                    echo -ne "${NC}  for ${S16}/16 subnets${NC} (#.#.\e[37m0.0${NC}): ${S16}" 
                    read ip_occ
                    if [[ "$ip_occ" =~ ^[2-9]$ ]]; then
                        c16="$ip_occ"
                        break
                    else
                        echo -e "${NC}Invalid input. Please enter a number between 2 and 9."
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
            echo
            
            single_count=$((optimized_count - subnet16_count - subnet24_count))
            cut_count=$((total_ips - single_count))
            log "====================="
            log "Compression finished!"
            log "====================="
            log "$total_ips Total IPs processed to"
            log "$optimized_count compressed sources."
            log "$single_count single IPs"
            log "$cut_coun source IPs compressed into"
            log "$subnet24_count /24 subnets (@ $c24 ) and"
            log "$subnet16_count /16 subnets (@ $c16 )"
            log "====================="
            echo 
            echo "•  ┏  ";
            echo "┓┏┓╋┏┓";
            echo "┗┛┗┛┗┛ ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰";
            echo -e "${GRN}IPs to Subnets aggregation finished!${NC}"
            echo
            echo -e "    Total processed:\t${VLT}$total_ips IPs ${NC}  \t  100% ◕ "
            echo -e "         reduced to:\t${CYN}$optimized_count sources${NC} \t   $((optimized_count * 100 / total_ips))% ◔ "
            echo
            echo -e "         single IPs:\t${CYN}$single_count IPs${NC} \t[  \e[3m$((single_count * 100 / total_ips))%${NC} ]"
            echo -e "       ╔ aggregated:\t${ORG}$cut_count IPs${NC}\t[  \e[3m$((100-(single_count * 100 / total_ips)))%${NC} ]"
            echo -e "       ╙ reduced to:\t${CYN}$((subnet24_count + subnet16_count)) subnets ${NC}"
            echo -e "${S24}          /24 @ x$c24 :\t$subnet24_count subnets${NC}\t(#.#.#.\e[37m0${NC})"
            echo -e "${S16}          /16 @ x$c16 :\t$subnet16_count subnets${NC}\t(#.#.\e[37m0.0${NC})"
            
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

function ban_core() { #has to be refactored - missing check if iptable exists (now in ) 
    log "ban_core"
    echo "▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰"
    echo "Start VIPB ban"
    # ban_core blacklist (ipset_name)

    local modified=""
    blacklist="$1"
    ipset=${2:-"$IPSET_NAME"}

    if [ -f "$blacklist" ]; then
        modified=$(stat -c "%y" "$blacklist" | cut -d. -f1)
        echo -e "Reading ${VLT}${BG}$blacklist${NC} ... ($modified)"
        IPS=()
        while IFS= read -r ip; do
            if [[ -n "$ip" && "$ip" != "#"* ]]; then
                IPS+=("$ip")
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

    setup_ipset "$ipset"
    add_ips "$ipset" "${IPS[@]}"   
    err=$? 

    count=$(count_ipset $ipset)

    log "▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱"
    log " VIPB-Ban finished!"
    if [ $err -ne 0 ]; then
        log "WITH $ERRORS ERRORS!"
        log "Function add_ipset() failed: $err"
    fi
    log "▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰"
    log "      Blacklist:   $blacklist ($modified)"
    log "         Loaded:   $total_blacklist_read IPs"
    log "          Added:   $ADDED_IPS IPs"
    log "Already present:   $ALREADYBAN_IPS IPs"
    log "          TOTAL:   $count IPs banned by VIPB"
    log "▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰"
    if [ "$CLI" == "false" ]; then 
            echo 
            echo "•  ┏  ";
            echo "┓┏┓╋┏┓";
            echo "┗┛┗┛┗┛ ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰";
    fi
    if [ $err -ne 0 ]; then
        echo -e "Finished with $ERRORS errors.. check logs!"
        echo
    fi
    echo -e "${NC}      Blacklist:   $blacklist ($modified)"
    echo -e "${VLT}         Loaded:   $total_blacklist_read IPs"
    echo -e "${GRN}          Added:   $ADDED_IPS IPs"
    echo -e "${ORG}Already present:   $ALREADYBAN_IPS IPs"
    echo -e "${GRN}          TOTAL:   $count IPs ${VLT}${BG}banned by VIPB${NC}"
    echo
    return $err
}

log "vipb-core.sh loaded / CLI $CLI / DEBUG $DEBUG"