#!/bin/bash

# VIPB User Interface
# A simple, versatile and efficient IP ban script for Linux servers

# Check if the script is running from CLI
if [ "$CLI" == "true" ]; then
    log "*** VIPB ${VER} *** CLI interface not supported here."
    if [ "$DEBUG" == "true" ]; then
        echo ">> but we are developers..."
    else
        exit 1
    fi
else
    log "Loading UI interface..."
    echo -e "▩▩▩ Hello Human! ▩▩▩"
    BD='\033[1m' # bold
    DM='\033[2m' # dim color
    ############################## TERMINAL DEBUG ##############################
    if [ "$DEBUG" == "true" ]; then
        debug_log "≡≡ TERMINAL PROPERTIES ≡≡"
        debug_log "≡ Terminal type: $(echo -e "${BG}$TERM${NC}")" 
        debug_log "≡ Number of colors supported: $(tput colors 2>/dev/null || echo "unknown")"
        debug_log "≡ Can clear screen: $(tput clear >/dev/null 2>&1 && echo -e "${GRN}Yes${NC}" || echo -e "${RED}No${NC}")"
        debug_log "≡ Can position cursor: $(tput cup 0 0 >/dev/null 2>&1 && echo -e "${GRN}Yes${NC}" || echo -e "${RED}No${NC}")"
        debug_log "≡ Can move cursor: $(tput cup 1 1 >/dev/null 2>&1 && echo -e "${GRN}Yes${NC}" || echo -e "${RED}No${NC}")"
        debug_log "≡ Can set foreground color: $(tput setaf 1 >/dev/null 2>&1 && echo -e "${GRN}Yes${NC}" || echo -e "${RED}No${NC}")"
        debug_log "≡ Can set background color: $(tput setab 1 >/dev/null 2>&1 && echo -e "${GRN}Yes${NC}" || echo -e "${RED}No${NC}")"
    fi
    ############################################################################
    # UI then define COLORS!
    # Check if terminal supports 256 colors
    if tput colors | grep -q '256' && ! [ "$DEBUG" == "true" ]; then
        VLT='\033[38;5;183m'    # plum 
        BLU='\033[38;5;81m'     # steelblue
        CYN='\033[38;5;44m'     # darkturquoise
        S24='\033[38;5;79m'     # aquamarine 
        S16='\033[38;5;194m'    # honeydew
        GRN='\033[38;5;191m'    # darkolivegreen
        YLW='\033[38;5;11m'     # lightyellow
        ORG='\033[38;5;222m'    # goldenrod 
        SLM='\033[38;5;210m'    # lightcoral
        RED='\033[38;5;196m'    # red
        GRY='\033[38;5;7m'      # grey
        #   Activate advanced menu
        function select_opt() {
            select_option "$@" 1>&2
            local result=$?
            return $result
        } 
    else
        # .. or fallback to 8 colors
        VLT='\033[35m' # magenta
        BLU='\033[34m' # blue
        CYN='\033[36m' # cyan
        S24='\033[36m' # cyan
        S16='\033[32m' # cyan
        GRN='\033[32m' # green
        YLW='\033[33m' # yellow
        ORG='\033[33m' # yellow
        SLM='\033[33m' # yellow
        RED='\033[31m' # red
        GRY='\033[90m' # gray if too dark use 37
        #   Use simple numbered menu 
        function select_opt() {
            local options=("$@")
            local selected=""
            local i=0
            echo -ne "${DM}"
            for option in "${options[@]}"; do
                echo -ne "$i. $option"
                echo -e "${NC}"
                ((i++))
            done
            while true; do
                echo -ne "${YLW}"
                read -p "_ " selected
                echo -e "${NC}"
                case $selected in
                    [0-9]) return "$selected"; break;;
                    *) echo -e "${YLW}Invalid option. ${BG}[0-$((${#options[@]} - 1))]${NC}" ;;
                esac
            done      
        } 
    fi
    echo -e "VIPB-UI ${GRN}LOADED${NC} + ${RED}c${VLT}o${ORG}l${YLW}o${S16}r${CYN}s${BLU}!${NC}"
fi

### UI-CORE functions

function back {
    header
    menu_main
}

function next() {
    echo -e "${NC}"
    echo -ne "${YLW}${DM}↵ to continue "
    read -p "_ " p
    echo -e "${NC}"
}

function vquit {
    echo -e "${VLT}"
    subtitle "ViPB end."
    log "▩▩▩▩▩▩▩▩ VIPB END.  ▩▩▩▩"
    exit 0
}

### UI-OPT functions

function center() {
    text="$1"
    #width=${2:-$(tput cols)}
    width=${2:-80}
    textlen=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g' | wc -m)
    padding=$(( (width - textlen) / 2 ))
    printf "%*s%b%*s\n" $padding '' "$text" $padding ''
}

function subtitle {
    if command -v figlet >/dev/null 2>&1 && [ "$DEBUG" == "false" ] && [ -f "$SCRIPT_DIR/tmplrREMOVE.flf" ]; then
        figlet -f "$SCRIPT_DIR/tmplr.flf" "$@"
    else
        echo
        echo -e "\033[47;7;1m -=≡≡ $* ≡≡=- \033[0m"
        echo
    fi
}

function level_bar(){
    for ((i=0; i<$1; i++)); do
        echo -ne "${GRN}▗${NC}"
    done
    for ((i=0; i<(8-$1); i++)); do
        echo -n "_"
    done
}

### UI-Handlers functions

# (Menu 1) IPsum blacklist download  download_blacklist
function handle_ipsum_download() {
    debug_log "1. Download IPsum Blacklist" 
    header
    echo -ne "${VLT}"
    subtitle "Download IPsum Blacklist"
    echo -e "${BG}IPsum${NC} is a feed based on 30+ publicly available lists of suspicious and/or malicious IP addresses. The provided list is made of IP addresses matched with a number of (black)lists occurrences. "
    echo -e "more infos at ${BG}https://github.com/stamparm/ipsum${NC}"
    echo
    echo -ne "${VLT}≡ IPsum list "
    check_blacklist_file $BLACKLIST_FILE infos
    echo
    echo
    echo -e "${YLW}Select level #, where # means IP appears on at least # blacklists"
    echo -e "${BD}${YLW}[2] more strict ${BG}(caution big list!)${NC}${BD}${YLW} <--> [8] less strict ${NC}"
    echo -e "${DM}[suggested 3-4, exit with 0]${NC}"
    echo -e "${YLW}"
	echo -ne "[LV 2-8${DM}|0${NC}${YLW}]: "
	read -p "" select_lv
	echo -e "${NC}"
    case $select_lv in
        [2-8]) 
            download_blacklist $select_lv
            #echo -e "${GRY}Proceed to the Aggregator (2.) or Ban (3.) the whole list!${NC}"
            next
            ;;
    esac
    back
} 

# (Menu 2) Aggregator blacklist compression
function handle_aggregator() {
    debug_log "2. VIPB-aggregator"
    header
    echo -ne "${CYN}"
    subtitle "VIPB-aggregator"
    echo "Aggregator is a script that compresses the IPsum blacklist into a smaller set of sources (subnetworks)."
    compressor
    next
    back
}

# (Menu 3) blacklist banning  
function handle_blacklist_ban() {
    debug_log "3. Ban Blacklists"
    header
    echo -ne "${BLU}"
    subtitle "Blacklists banning"
	
    ipb_files=()
    while IFS= read -r -d '' file; do
        if [[ -f "$file" && ! "$file" =~ vipb- ]]; then
            ipb_files+=("$file")
        fi
    done < <(find "$SCRIPT_DIR" -maxdepth 1 -name '*.ipb' -print0)
    if ! [ ${#ipb_files[@]} -eq 0 ]; then
        echo -e "${BG}Custom blacklists:${NC}"
        for ipb_file in "${ipb_files[@]}"; do
            echo -ne "${BLU}≡ $ipb_file " 
            check_blacklist_file "$ipb_file"
            echo
        done
        echo
    fi
    
    if [[ $IPSET == "false" ]]; then
        echo -e "${RED}ipset not found. No option available."
        next
    else
        INFOS="false"
        #check_ipset $IPSET_NAME
        #check_ipset $MANUAL_IPSET_NAME
        echo -e "${YLW}All ready. What do you want to do?${NC}" 
        echo
        echo -e "\t${BD}${CYN}1. Ban aggregated list ✓${NC}  \t${CYN}$(wc -l < "$OPTIMIZED_FILE") sources${NC}"
        echo -e "\t${VLT}2. Ban source IPsum list${NC} \t${VLT}$(wc -l < "$BLACKLIST_FILE") IPs${NC}"
        echo -e "\t3. Only ${S24}/24 subnets${NC} #.#.#.${BD}0${NC} \t${S24}$(wc -l < "$SUBNETS24_FILE") networks${NC}"
        echo -e "\t4. Only ${S16}/16 subnets${NC} #.#.${BD}0.0${NC} \t${S16}$(wc -l < "$SUBNETS16_FILE") networks${NC}"
        echo -e "\t5. Ban ${BLU}from ${BG}*.ipb${NC} files \t${DM}>>${NC}"
        echo -e "\t6. ${ORG}Clear ${BLU}blacklists${NC} files \t${DM}>>${NC}"
        echo
        echo -e "\t${DM}0. <<" 
        echo -e "\e[0m"
        echo
        while true; do
            echo -ne "${YLW}"
            read -p "_ " blacklist_choice
            echo -e "${NC}"
            case $blacklist_choice in
                1)  debug_log " $blacklist_choice. OPTIMIZED_FILE"
                    subtitle "${CYN}Ban aggregated list"
                    ban_core "$OPTIMIZED_FILE"
                    next
                    break
                    ;;
                2)  debug_log " $blacklist_choice. BLACKLIST_FILE"
                    subtitle "${VLT}Ban original blacklist" 
                    ban_core "$BLACKLIST_FILE"
                    next
                    break
                    ;;    
                3)  debug_log " $blacklist_choice. SUBNETS24_FILE"
                    subtitle "${S24}Ban /24 subnets (#.#.#.0)"
                    ban_core "$SUBNETS24_FILE"
                    next
                    break
                    ;;
                4)  debug_log " $blacklist_choice. SUBNETS16_FILE"
                    subtitle "${S16}Ban /16 subnets (#.#.0.0)"
                    INFOS="true"
                    ban_core "$SUBNETS16_FILE"
                    next
                    break
                    ;;
                5)  debug_log " $blacklist_choice. IPB_FILE"
                    subtitle "${VLT}Import *.ipb list"
                    echo
                    echo -e "${YLW}Select with [space] the lists to import and ban into ${BG}$IPSET_NAME${NC}, press ↵ to continue."
                    echo
                    
                    multiselect result ipb_files false

                    idx=0
                    for selected in "${ipb_files[@]}"; do
                        if [[ "${result[idx]}" == "true" ]]; then
                            selected_ipbf+=("$selected")
                        fi
                        ((idx++))
                    done

                    if [[ ${#selected_ipbf[@]} -eq 0 ]]; then
                        echo -e "${RED}No files selected.${NC}"
                    else
                        echo -e "The selected files will be loaded into ${YLW}${BG}$IPSET_NAME${NC}."
                        for ipb_file in "${selected_ipbf[@]}"; do
                            echo -e "Banning from file ${BLU}$ipb_file${NC} ... "
                            INFOS="true"
                            ban_core "$ipb_file" "$IPSET_NAME"
                            echo -e "${BLU}${BG}$ipb_file${NC} parsed."
                            echo
                        done
                        echo -e "${GRN}All files parsed in ${YLW}${BG}$IPSET_NAME${NC}."
                    fi
                    next
                    break
                    ;;
                6)  debug_log " $blacklist_choice. Clear blacklist files"
                    subtitle "Clear blacklist files"
                    echo -e "${YLW}Select with [space] the blacklists to clear${NC}, press ↵ to continue."
                    echo

                    select_lists=("IPsum Blacklist" "Optimized Blacklist" "/24 subnets" "/16 subnets" )

                    multiselect result select_lists false

                    selected_lists=()
                    idx=0
                    for selected in "${select_lists[@]}"; do
                        if [[ "${result[idx]}" == "true" ]]; then
                            selected_lists+=("$selected")
                            case $idx in
                                0)  > "$BLACKLIST_FILE"
                                    echo -n "$BLACKLIST_FILE"
                                    ;;
                                1)  > "$OPTIMIZED_FILE"
                                    echo -n "$OPTIMIZED_FILE"
                                    ;;
                                2)  > "$SUBNETS24_FILE"
                                    echo -n "$SUBNETS24_FILE"
                                    ;;
                                3)  > "$SUBNETS16_FILE"
                                    echo -n "$SUBNETS16_FILE"
                                    ;;
                            esac
                            log "*** deleted ${select_lists[idx]}"
                            echo -e " ${ORG}deleted${NC}"
                        fi                                    
                    ((idx++))
                    done

                    if [[ ${#selected_lists[@]} -eq 0 ]]; then
                        echo -e "${RED}No Blacklist selected.${NC}"
                    fi
                    next
                    handle_blacklist_ban
                    ;;
                0)  debug_log " $blacklist_choice. << Back to Menu"
                    back
                    ;;
            esac
        done
    fi
    back
}

# (Menu 4) manual banning 
function handle_manual_ban() {
    debug_log "5. Manual ban IPs"
    header
    echo -ne "${YLW}"
    subtitle "Manual ban IPs"
    
    echo -e "User bans are stored in ipset ${YLW}${BG}$MANUAL_IPSET_NAME${NC}. Max 244 sources allowed."
    echo -e "You can use the ${YLW}ban${NC} command to add IPs to the manual ipset via CLI."
    echo
    echo -e "${YLW}Last 10 banned IPs:${NC}"
    if [[ "$FIREWALL" == "firewalld" ]]; then
        last_banned_ips=$(firewall-cmd --list-all --zone=drop | grep -E '^[0-9]+\.' | tail -n 10)
    elif [[ "$FIREWALL" == "iptables" ]]; then
        last_banned_ips=$(ipset list "$MANUAL_IPSET_NAME" | grep -E '^[0-9]+\.' | tail -n 10)
    fi
    
    if [[ -n "$last_banned_ips" ]]; then
        echo -e "$last_banned_ips"
    else
        echo -e "${BG}No manually banned IPs found.${NC}"
    fi
    echo

    manual_options=()
    if [[ "$FIREWALL" == "iptables" ]] || [[ "$FIREWALL" == "firewalld" ]]; then
        manual_options+=("${YLW}Ban IPs${NC}")
    fi
    if [[ "$IPSET" == "true" ]]; then
        manual_options+=("${ORG}View all / Unban IPs${NC}" "${BLU}Export to file ${BG}$MANUAL_IPSET_NAME.ipb${NC}")
    fi
    echo -e "${YLW}"
    select_opt "${NC}${DM}<< Back${NC}" "${manual_options[@]}"
    manual_choice=$?
    case $manual_choice in
        0)  debug_log " $manual_choice. < Back to Menu"
            back
            ;;
        1)  debug_log " $manual_choice. Manual Ban"
            ask_IPS
            echo
            if [[ ${#IPS[@]} -eq 0 ]]; then
                echo -e "${ORG}No IP entered.${NC}"
            else
                if [[ "$IPSET" == "true" ]]; then
                    setup_ipset "$MANUAL_IPSET_NAME"
                fi
                echo
                geo_ip
                INFOS="true"
                add_ips "$MANUAL_IPSET_NAME" "${IPS[@]}"
                echo -e "${GRN}$ADDED_IPS IPs added ${NC}($ALREADYBAN_IPS already banned).${GRN}"
                count_ipset "$MANUAL_IPSET_NAME"
                echo -e " total IPs banned${NC} in set ${YLW}${BG}${MANUAL_IPSET_NAME}${NC}."
            fi
            next
            ;;
        2)  debug_log " $manual_choice. Unban / View"
            echo -e "${YLW}Select with [space] the IPs to unban, press ↵ to continue."
            echo
            select_ips=($(ipset list $MANUAL_IPSET_NAME | grep -E '^[0-9]+\.' | cut -f1))
            
            multiselect result select_ips false

            selected_ips=()
            idx=0
            for selected in "${select_ips[@]}"; do
                if [[ "${result[idx]}" == "true" ]]; then
                    selected_ips+=("$selected")
                fi
            ((idx++))
            done

            if [[ ${#selected_ips[@]} -eq 0 ]]; then
                echo -e "${RED}No IP entered.${NC}"
            else
                echo "Removing selected IPs from ipset..."
                remove_ips $MANUAL_IPSET_NAME "${selected_ips[@]}"
                echo -e "${CYN} IPs ${NC}removed${NC}."
                count_ipset "$MANUAL_IPSET_NAME"
                echo -e " total IPs banned${NC} in set ${BG}$MANUAL_IPSET_NAME${NC}."
            fi
            next
            ;;
        3)  debug_log " $manual_choice. Export to file"
            subtitle "export"
            ipset list "$MANUAL_IPSET_NAME" | grep -E '^[0-9]+\.' > "$SCRIPT_DIR/$MANUAL_IPSET_NAME.ipb"      #2do 
            echo -e "Saved to ${BG}${BLU}$SCRIPT_DIR/$MANUAL_IPSET_NAME.ipb${NC}"
            next
            ;;
    esac
    back
}

# (Menu 5) DOWNLOAD & BAN
function handle_download_and_ban() {
    debug_log "* DOWNLOAD & BAN!"
    header
    echo -ne "${VLT}"
    subtitle "DOWNLOAD,${CYN} AGGREGATE ${BLU}& BAN!"
    if [[ $IPSET == "false" ]]; then
        echo -e "${RED}No option available."
    else
        echo -e "${YLW}Proceed?"
        select_opt "No" "Yes"
        select_yesno=$?
        echo -ne "${NC}"
        case $select_yesno in
            0)  echo "Nothing to do."
                ;;
            1)  subtitle "1. ${VLT} Download"
                download_blacklist
                subtitle "2. ${CYN} Aggregate"
                tempcli=$CLI
                CLI="true"
                compressor
                CLI=$tempcli
                subtitle "3. ${BLU} Ban!"
                INFOS="false"
                ban_core $OPTIMIZED_FILE
                ;;
        esac
       
    fi
    next
    back
}

# (Menu 6) manage firewall and ipsets  #2do this section needs a refactoring
function handle_firewalls() {
    debug_log "6. Firewall & Sets"
    header
    echo -ne "${ORG}"
    subtitle "Firewall & ipsets"
    echo -ne "Firewall ${ORG}${BG}${FIREWALL}${NC} "
    if $FIREWALLD || $PERSISTENT; then
        echo -e "in use with ${S16}permanent rules${NC}"
    fi
 
    


    echo
    echo -e "\t1. View current ${ORG}rules${NC}"
    echo -e "\t2. Re-/Create ${ORG}VIPB-rules${NC}"
    echo -e "\t3. Change firewall \t\t ${RED}!${NC}${DM}>>${NC}"
    if [[ $IPSET == "true" ]]; then
        echo -e "\t4. View/Clear ${BLU}all ipsets${NC}\t ${DM}>>${NC}"
        echo -e "\t5. Re-/Create ${VLT}VIPB-ipsets${NC}\t ${DM}>>${NC}"
        echo -e "\t6. Destroy ${VLT}VIPB-ipsets${NC} and ${ORG}rules ${RED}!${NC}${DM}>>${NC}"
    fi
    echo
    echo -e "\t${DM}0. <<${NC}" 
    echo -e "\e[0m"
    echo
    echo -e "${YLW}All ready. What do you want to do?" 
    echo
    while true; do
        read -p "_ " ipsets_choice
        echo -e "${NC}"
        case $ipsets_choice in
            1)  debug_log " $ipsets_choice. View current rules"
                echo -ne "${ORG}"
                subtitle "$FIREWALL rules"
                if [[ "$FIREWALL" == "iptables" ]]; then
                    iptables -L INPUT -n --line-numbers | awk 'NR>2 {print $1, $2, $3, $7, $8, $9, $10, $11, $12}' | column -t
                    iptables -L INPUT -n --line-numbers | grep -q "match-set vipb-" && echo -e "${GRN}VIPB ipsets found in iptables rules.${NC}" || echo -e "${RED}No VIPB ipsets found in iptables rules.${NC}"
                elif [[ "$FIREWALL" == "firewalld" ]]; then
                    firewall-cmd --list-all --zone=drop
                    firewall-cmd --list-all --zone=drop | grep -q "vipb-" && echo -e "${GRN}VIPB rules found in firewalld.${NC}" || echo -e "${RED}No VIPB rules found in firewalld.${NC}"
                elif [[ "$FIREWALL" == "ufw" ]]; then
                    ufw status verbose
                    if ufw status | grep -q "vipb-"; then
                        echo -e "${GRN}VIPB rules found in UFW.${NC}"
                    else
                        echo -e "${RED}No VIPB rules found in UFW.${NC}"
                    fi
                fi
                next
                ;;
            2)  debug_log " $ipsets_choice. Re-/Create rules"
                subtitle "Re-/Create rules"

                echo -e "This process won't remove any bans. ${YLW}Proceed?"
                select_opt "No" "Yes"
                select_yesno=$?
                echo -ne "${NC}"
                case $select_yesno in
                    0)  echo "Nothing to do."
                        ;;
                    1)  echo -e "${VLT}☷ ipset '${IPSET_NAME}'${NC}"
                            echo -ne "  Removing rule... ${NC}"
                            if remove_firewall_rules "$IPSET_NAME" ; then
                                echo -e "${GRN}OK${NC}"
                            else
                                echo -e "${RED}Failed${NC}"
                            fi

                            echo -ne "  Adding new rule... ${NC}"
                            if add_firewall_rules "$IPSET_NAME" ; then
                                echo -e "${GRN}OK${NC}"
                            else
                                echo -e "${RED}Failed${NC}"
                            fi
                        echo

                        echo -e "${YLW}☷ ipset '${MANUAL_IPSET_NAME}'${NC}"
                            echo -ne "  Removing rule... ${NC}"
                            if remove_firewall_rules "$MANUAL_IPSET_NAME"; then
                                echo -e "${GRN}OK${NC}"
                            else
                                echo -e "${RED}Failed${NC}"
                            fi

                            echo -ne "  Adding new rule... ${NC}"
                            if add_firewall_rules "$MANUAL_IPSET_NAME" ; then
                                echo -e "${GRN}OK${NC}"
                            else
                                echo -e "${RED}Failed${NC}"
                            fi
                        echo

                        if [[ "$FIREWALL" == "firewalld" ]]; then
                            echo -ne "Reloading ${ORG}$FIREWALL${NC}... "
                            firewall-cmd --reload
                        fi
                        ;;
                esac                
                next
                ;;
            3)  debug_log " $ipsets_choice. Change firewall"
                subtitle "${ORG}Change firewall"
                echo -e "${ORG}Change firewall at your risk.${NC}"
                echo -e "This section is in still in development and not optimized for cross-use between firewalls yet."
                echo -e "Misuse could bring to orphaned rules or ipsets in your system."
                fw_options=()

                if [ "$IPTABLES" == "true" ]; then
                    fw_options+=("iptables ${BG}${S16}[default]${NC}")
                fi
                if [ "$FIREWALLD" == "true" ]; then 
                    fw_options+=("FirewallD")
                fi
                if [ "$DEBUG" == "true" ]; then
                    fw_options+=("ufw ${BG}[not supported]${NC}") #2do
                fi
                
                select_opt "${NC}${DM}<< Back${NC}" "${fw_options[@]}"
                fw_options=$?
                case $fw_options in
                    0)  debug_log " $fw_options. < Back to Menu"
                        handle_firewalls
                        ;;
                    1)  debug_log " $fw_options. iptables"
                        FIREWALL="iptables"
                        ;;
                    2)  debug_log " $fw_options. FirewallD"
                        FIREWALL="firewalld"
                        ;;
                    3)  debug_log " $fw_options. ufw"
                        FIREWALL="ufw"
                        ;;
                esac
                # Update vipb-core.sh with the new fw 
                sed -i "0,/^FIREWALL='.*'/s//FIREWALL='$FIREWALL'/" "$SCRIPT_DIR/vipb-core.sh"
                log "Firewall changed to $FIREWALL"
                echo -e "Firewall changed to ${ORG}$FIREWALL${NC}"
                next
                ;;
            4)  debug_log " $ipsets_choice. View/Clear ipsets" #2do
                subtitle "${BLU}View/Clear ipsets"
 
                if [[ "$FIREWALL" == "firewalld" ]]; then
                    select_ipsets=($(firewall-cmd --permanent --get-ipsets))
                elif [[ "$IPSET" == "true" ]]; then
                    select_ipsets=($(ipset list -n))
                fi

                if [[ ${#select_ipsets[@]} -eq 0 ]]; then
                    echo -e "${RED}No ipsets found.${NC} Create them with option 5."
                else
                    echo -e  "${YLW} Select with [space] the ipsets to clear, press ↵ to continue.${NC}"
                    echo

                    ipsets_selector "${select_ipsets[@]}"
                    
                    if [[ ${#selected_ipsets[@]} -eq 0 ]]; then
                        echo -e "${YLW}No ipsets selected.${NC}"
                    else
                        for ipset_name in "${selected_ipsets[@]}"; do
                            if [[ "$ipset_name" != vipb-* ]]; then
                                echo -e "${RED}Skipping ipset ${BLU}$ipset_name${NC} as it is not a VIPB ipset (read-only).${NC}"
                            else
                                echo -ne "Clearing ipset ${BLU}$ipset_name${NC}... "
                                if [[ "$FIREWALL" == "firewalld" ]]; then
                                    echo "2do"
                                    firewall-cmd --permanent --delete-ipset="$ipset_name"
                                    setup_ipset "$ipset_name"
                                    #reload_firewall
                                elif [[ "$FIREWALL" == "iptables" ]]; then
                                    ipset flush "$ipset_name"
                                fi
                                echo -e "${GRN}cleared${NC}"
                            fi
                        done
                    fi
                fi
                
                next
                ;;
            5)  debug_log " $ipsets_choice. Re-Create VIPB-ipsets"
                subtitle "${VLT}Re-Create VIPB-ipsets"
                echo -e "${YLW}Select with [space] the VIPB-ipsets to (re)create${NC}, press ↵ to continue."
                echo -e "This will NOT remove related firewall rules! ${DM}(use option 6 instead)${NC}"
                echo

                select_ipsets=("$IPSET_NAME" "$MANUAL_IPSET_NAME")
                ipsets_selector "${select_ipsets[@]}"

                if [[ ${#selected_ipsets[@]} -eq 0 ]]; then
                    echo -e "${RED}No ipsets selected.${NC}"
                else
                    echo -e "Are you sure?"
                    select_opt "No" "Yes"
                    select_yesno=$?
                    case $select_yesno in
                        0)  echo "Nothing to do."
                            ;;
                        1)  for ipset_name in "${selected_ipsets[@]}"; do  
                                echo -e "${VLT}☷ Re/creating ipset '$ipset_name'...${NC}"
                                remove_ipset "$ipset_name"
                                setup_ipset "$ipset_name"
                            done
                            echo
                            echo -e "${VLT}All ipsets resetted.${NC}"
                            ;;
                    esac
                fi
                next
                ;;
            6)  debug_log " $ipsets_choice. Destroy VIPB-ipsets and rules"
                subtitle "${VLT}Destroy VIPB-ipsets ${ORG}and rules"
                echo -e "${YLW}Select with [space] the ipsets to ${ORG}destroy${NC}, press ↵ to continue."
                echo -e "This action will also try to remove related ${ORG}$FIREWALL${NC} rules! ${DM}${BG}use option 5 instead${NC}"
                echo

                select_ipsets=("$IPSET_NAME" "$MANUAL_IPSET_NAME")
                ipsets_selector "${select_ipsets[@]}"

                if [[ ${#selected_ipsets[@]} -eq 0 ]]; then
                    echo -e "${RED}No ipsets selected.${NC}"
                else
                    echo -e "${YLW}Are you sure?"
                    select_opt "No" "Yes"
                    select_yesno=$?
                    case $select_yesno in
                        0)  echo "Nothing to do."
                            ;;
                        1)  
                            for ipset_name in "${selected_ipsets[@]}"; do  
                                echo -e "${ORG}▤ Deleting '$ipset_name' rules...${NC}"
                                remove_firewall_rules "$ipset_name"
                            done
                            echo

                            for ipset_name in "${selected_ipsets[@]}"; do  
                                echo -e "${VLT}☷ Deleting '$ipset_name' ipset...${NC}"
                                remove_ipset "$ipset_name"
                                if [[ "$FIREWALL" == "firewalld" ]]; then
                                    destroy_ipset "$ipset_name" 
                                fi
                            done
                            echo
                            echo -e "${VLT}Done.${NC} Be careful now."
                            ;;
                    esac
                fi
                next
                ;;
            0)  debug_log " $ipsets_choice. << Back to Menu"
                back
                ;;
        esac
        handle_firewalls
    done
    
}

# (Menu 7) cron job daily autoban
function handle_cron_jobs() {
    debug_log "7. Daily Cron Job"
    header
    echo -ne "${SLM}"
    subtitle "Daily Cron Job"        
    
    if [ "$CRON" == "false" ]; then
        echo -e "${RED}Error: Cannot read crontab${NC}"
    else
        if [[ "$DAILYCRON" == "true" ]]; then
            echo -e "${SLM}↺${NC}  VIPB autoban job ${GRN}found${NC}" #2do add time details
        else
            echo -e "${SLM}↺${NC}  VIPB autoban job ${RED}not found${NC}"
        fi
        
        existing_cronjobs=$(crontab -l 2>/dev/null | grep -E "vipb")
        if [ -n "$existing_cronjobs" ]; then
            echo -e "${S16}$existing_cronjobs${NC}"
        else
            echo -e "${ORG} No active VIPB-Cron Jobs found.${NC}"
        fi
        
        echo
    fi
    
    echo
    cron_options=("${VLT}Change IPsum ▼ download list level [ $BLACKLIST_LV ] ${NC}")
    if [[ $CRON == "true" ]]; then
        if [[ "$DAILYCRON" == "true" ]]; then
            cron_options+=("Remove ↺ VIPB autoban job")
        else
            cron_options+=("Add ↺ VIPB autoban job")
        fi
    fi
    select_opt "${NC}${DM}<< Back${NC}" "${cron_options[@]}"
    cron_select=$?
    case $cron_select in
        0)  back
            ;;
        1)  subtitle "set fire level"
            # "Change default IPsum list level"
            select_opt "${NC}${DM}<< Back${NC}" "" "${RED}  2  caution! big list${NC}" "${YLW}  3  ${NC}" "${GRN}  4  ${NC}" "${S16}  5  ${NC}" "${YLW}  6  ${NC}" "${ORG}  7  ${NC}"  "${ORG}  8  ${NC}"
            select_lv=$?
            case $select_lv in
                [0-1])  back
                    ;;
                [2-8]) 
                    set_blacklist_level $select_lv #2do ?
                    next
                    ;;
            esac
            next
            ;;
        2)  if [[ "$DAILYCRON" == "true" ]]; then
                DAILYCRON=false
                crontab -l | grep -v "vipb.sh" | crontab -
                echo -e "VIPB daily ban job ${ORG}removed.${NC}"
            else
                subtitle "add daily ban job"
                (crontab -l 2>/dev/null; echo "10 4 * * * $SCRIPT_DIR/vipb.sh") | crontab -
                echo -e "Cron Job ${GRN}added for daily VIPB autoban on blacklist. ${NC} @ 4.10 AM server time"
                DAILYCRON=true
            fi
            next           
            ;;
    esac
    back
}

# (Menu 8) Geo IP lookup 
function handle_geo_ip_info() {
    debug_log "8. GeoIP lookup"
    header
    echo -e "${S24}"
    subtitle "GeoIP lookup"
    echo -e 

    ask_IPS

    echo
    if [[ ${#IPS[@]} -eq 0 ]]; then
        echo -e "${ORG}No IP entered.${NC}"
    else
        geo_ip 
    fi
    next
    back
}

# (Menu 9) Logs and info 
function handle_logs_info() {
    debug_log "9. Logs & infos"
    header
    echo -ne "${ORG}"
    subtitle "Logs & infos"
    
    log_selector(){
        
        loglen=20
        more_loglen=$(($loglen * 100))

        echo -e "${ORG}■■■ LOG & DATA VIEWER ■■■${NC}"
        echo
        echo "View system logs and extract IPs."

        function log2IPs() {
            # New! Extract IPs from the last tail of log
            local log_file="$1"
            local grep="$2"
            #lg "*" "log2IPs $*"
            local extracted_ips=()
            if [[ -f "$log_file" ]]; then 
                extracted_ips=($(tail -n $more_loglen "$log_file" | grep "$grep" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort -u))
                
                if [[ ${#extracted_ips[@]} -eq 0 ]]; then
                    echo -e "${SLM}No IPs found in log $log_file matching: ${BG}$grep.${NC}"
                else
                    echo -e "${SLM}Extracted IPs (last $more_loglen loglines):${NC}"
                    for ip in "${extracted_ips[@]}"; do
                        echo "$ip"
                    done
                    echo
                    echo -e "${YLW}Should we ban them promptly?"
                    select_opt "No" "Yes"
                    select_yesno=$?
                    echo -ne "${NC}"
                    case $select_yesno in
                        0)  echo "Nothing to do."
                            ;;
                        1)  echo "Sure!"
                            INFOS="true"
                            add_ips "$MANUAL_IPSET_NAME" "${extracted_ips[@]}"
                            ;;
                    esac                
                fi
            else
                echo -e "${RED}Fail2Ban log file not found at ${BG}$log_file.${NC}"
            fi
        }
        
        log_options=("${VLT}VIPB${NC}" "${VLT}VIPB${NC} ${ORG}variables" "${VLT}VIPB log${NC} ${YLW}*reset" "${CYN}auth.log${NC}" "${S16}syslog${NC}" "${S16}journalctl${NC}" )
        if [[ $FAIL2BAN == "true" ]]; then
            log_options+=("${ORG}Fail2Ban${NC}" "${ORG}Fail2Ban ${YLW}[WARNING]s${NC}")
        fi
        
        select_opt "${NC}${DM}<< Back${NC}" "${log_options[@]}"
        select_log=$?
        case $select_log in
            0)  back
                ;;
            1)  header
                echo
                echo -e "${VLT}▗ $SCRIPT_DIR/vipb-log.log${NC}"
                tail -n $loglen $SCRIPT_DIR/vipb-log.log
                ;;
            2)  header
                echo
                echo -e "${VLT}▗ VIPB variables"    #2do
                vars=(
                    "              VER:$VER"
                    "              CLI:$CLI"
                    "            DEBUG:$DEBUG"
                    "${BLU}       SCRIPT_DIR:$SCRIPT_DIR"
                    "         LOG_FILE:$LOG_FILE"
                    "${CYN}       IPSET_NAME:$IPSET_NAME"
                    "MANUAL_IPSET_NAME:$MANUAL_IPSET_NAME"
                    "${SLM}             CRON:$CRON"
                    "        DAILYCRON:$DAILYCRON"
                    "           CRONDL:$CRONDL"
                    "${ORG}         FIREWALL:$FIREWALL"
                    "         IPTABLES:$IPTABLES"
                    "            IPSET:$IPSET"
                    "        FIREWALLD:$FIREWALLD"
                    "              UFW:$UFW"
                    "       PERSISTENT:$PERSISTENT"
                )
                for var in "${vars[@]}"; do
                    key="${var%%:*}"
                    value="${var#*:}"
                    echo -e "${key}: ${BG}${value}${NC}"
                done
                ;;
            3)  header
                echo
                echo -e "${VLT}▗ VIPB${NC} (last $loglen lines)"
                tail -n $loglen $SCRIPT_DIR/vipb-log.log
                echo
                > "$SCRIPT_DIR/vipb-log.log"
                echo -e "VIPB-log ${YLW}cleared${NC}"
                ;;
            4)  header
                echo
                echo -e "${CYN}▗ /var/log/auth.log${NC}"
                tail -n $loglen /var/log/auth.log
                echo
                log2IPs "/var/log/auth.log" 'Connection closed'
                ;;
            5)  header
                echo
                echo -e "${S16}▗ /var/log/syslog${NC}"
                tail -n $loglen /var/log/syslog
                ;;
            6)  header
                echo
                echo -e "${S16}▗ ${BG}journalctl -n $loglen${NC}"
                journalctl -n "$loglen"
                ;;
            7)  header
                echo
                echo -e "${SLM}▗ /var/log/fail2ban.log${NC}"
                tail -n $loglen /var/log/fail2ban.log
                ;;
            8)  header
                echo
                echo -e "${SLM}▗ Fail2Ban [WARNING]s${NC}"
                tail -n $loglen /var/log/fail2ban.log | grep "WARNING"
                echo
                log2IPs "/var/log/fail2ban.log" "WARNING"
                next
                ;;
            
        esac
        echo
        log_selector
    }
    log_selector
    echo -e "\e[0m"
    next
    back
}

### Main UI

# Header Row
function services_row() {  
    echo -ne "${DM}"
    center "-----------------------------------------------------------------"
    rowtext="${NC}"
    #iptables
    if [ "$FIREWALL" == "iptables" ]; then
        rowtext+="${GRN}[ ${NC}"
        else
        rowtext+="${DM}"
    fi 

        if [ "$IPTABLES" == "true" ]; then
            rowtext+="${GRN}"
        else
            rowtext+="${DM}"
        fi
        rowtext+="iptables"

        if [ "$PERSISTENT" == "true" ]; then
            rowtext+="-persistent" # we have to check the save function
        fi

    #ipset        
        if [ "$IPSET" == "true" ]; then
            rowtext+="${GRN} +"
        else
            rowtext+="${DM}"
        fi
        rowtext+=" ipset${NC}"

    if [ "$FIREWALL" == "iptables" ]; then
        rowtext+="${GRN} ]${NC}"
    fi 
    
    #ufw
    if [ "$FIREWALL" == "ufw" ]; then
        rowtext+="${GRN} [ ${NC}"
        else
        rowtext+="${DM} "
    fi 

        if [ "$UFW" == "true" ]; then
            rowtext+="${GRN}"
        else
            rowtext+="${GRY}"
        fi 
        rowtext+="ufw${NC}"

    if [ "$FIREWALL" == "ufw" ]; then
        rowtext+="${GRN} ]${NC}"
    fi

    #firewalld
    if [ "$FIREWALL" == "firewalld" ]; then
        rowtext+="${GRN} [ "
    else
        rowtext+="${DM} "
    fi 
        if [ "$FIREWALLD" == "true" ]; then 
            rowtext+="${GRN}"
        else
            rowtext+="${DM}"
        fi
        rowtext+="firewalld${NC}"

    if [ "$FIREWALL" == "firewalld" ]; then
        rowtext+="${GRN} ]${NC}"
    fi

    rowtext+=" ${DM}•${NC} "
    
    #fail2ban
    if [ "$FAIL2BAN" == "true" ]; then
        rowtext+="${GRN}"
    else
        rowtext+="${NC}${DM}"
    fi
    rowtext+="${BG}fail2ban ${NC}"
    
    rowtext+="${DM}•${NC} "

    #cron
    if [ "$CRON" == "true" ]; then
        rowtext+="${GRN}"
    else
        rowtext+="${DM}"
    fi
    rowtext+="${BG}cron ${NC}"

    if [ "$CRON" == "true" ]; then
        if crontab -l | grep -q "vipb\.sh"; then
            rowtext+="${GRN}↺ "
            DAILYCRON=true
        else
            rowtext+="${RED}✗ "
            DAILYCRON=false
        fi
        rowtext+="$BLACKLIST_LV"
    fi
    rowtext+="${NC}"

    center "${rowtext}"

}

# Nice main header :)
function header () {
    if [ "$DEBUG" == "true" ]; then
        echo
        echo -e "▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤ ${YLW}DEBUG MODE ON${NC} ▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤"
        echo
    else
       clear
    fi
    if [ "$IPSET" == "true" ] || [ "$FIREWALLD" == "true" ]; then
        ipset_bans=$(count_ipset "$IPSET_NAME")
        manual_ipset_bans=$(count_ipset "$MANUAL_IPSET_NAME")
    fi
    if [[ "$FIREWALL" == "iptables" ]]; then
        iptables -L INPUT -n --line-numbers | grep -q "match-set vipb-" && FW_RULES="true" || FW_RULES="false"
    elif [[ "$FIREWALL" == "firewalld" ]]; then
        firewall-cmd --list-all --zone=drop | grep -q "vipb-" && FW_RULES="true" || FW_RULES="false"
    elif [[ "$FIREWALL" == "ufw" ]]; then
        ufw status | grep -q "vipb-" && FW_RULES="true" || FW_RULES="false"
    fi
    echo -ne "${NC}${RED}${DM}"
    echo -e "▁ ▂ ▃ ▅ ▆ ▇ ▉ ▇ ▆ ▅ ▃ ▂ ${NC}${VLT}${BD}Versatile IPs Blacklister${NC} ${DM}${VER}${RED} ▁ ▂ ▃ ▅ ▆ ▇ ▉ ▇ ▆ ▅ ▃ ▂${NC}"
    echo -e "\t                                   ${DM}    •                  ${NC}"     
    echo -e "\t  ██╗   ██╗██╗██████╗ ██████╗      ${DM}   ┏┓┏┳┓┏┓┏┓┏┓┓┏┏┓┏┏┓┏┓${NC}"
    echo -e "\t  ██║   ██║██║██╔══██╗██╔══██╗     ${DM}by ┛┗┛┗┗┗┛┛┗┗┫┗┻┗┻┛┗┻┛ ${NC}"
    echo -e "\t  ██║   ██║██║██████╔╝██████╔╝     ${DM}             ┗         ${NC}"
    echo -ne "\t  ╚██╗ ██╔╝██║██╔═══╝ ██╔══██╗    "
    if [ "$IPSET" == "true" ] || [ "$FIREWALLD" == "true" ]; then
        echo -ne "✦ ${VLT}VIPB bans: ${BD}$ipset_bans ${NC}"
    fi
    echo
    echo -ne "\t   ╚████╔╝ ██║██║     ██████╔╝    "
    if [ "$IPSET" == "true" ] || [ "$FIREWALLD" == "true" ]; then
        echo -ne "✦ ${YLW}USER bans: ${BD}$manual_ipset_bans${NC}"
    fi
    echo
    echo -ne "\t    ╚═══╝  ╚═╝╚═╝     ╚═════╝     "
    echo -ne "✦ ${ORG}$FIREWALL: "
    if [ "$FW_RULES" == "true" ] ; then
        echo -ne "${GRN}✓${NC}"
    else
        echo -ne "${RED}✗${NC}"
    fi
    echo
}

# Main menu
function menu_main() {
    services_row

    echo -e "${NC}"
    echo -e "\t${DM}✦ BLACKLISTS & BAN${NC}"
    echo -e "\t1${VLT}. Download${NC} ${BG}IPsum${NC} blacklist"
    echo -e "\t2${CYN}.${NC} ${CYN}Aggregate${NC} IPs into subnets"
    echo -e "\t3${BLU}. Ban ${NC}from Blacklists${NC}"
    echo -e "\t4${YLW}. Manual ban ${NC}IPs"
    echo
    echo -e "\t${VLT}5. Download > ${CYN}Aggregate > ${BLU}Ban!${NC}"
    echo -e "\n\t${DM}✦ TOOLS${NC}"
    if [[ $IPSET == "false" ]]; then
        echo -ne "${DM}"
    fi
    echo -e "\t6. Manage ${ORG}firewall${NC} & ${ORG}ipsets${NC}"
    if [[ $CRON == "false" ]]; then
        echo -ne "${DM}"
    fi
    echo -e "\t7${SLM}.${NC} Daily ${SLM}Cron${NC} Jobs"
    echo -e "\t8${S24}. Geo IP${NC} lookup"
    echo -e "\t9${ORG}. Logs ${NC}& Vars"
    echo
    echo -e "\t${DM}0. Exit${NC}"
    echo
    echo -e "${YLW}${BG}${DM}You can directly enter an IP to ban.${NC}"
    while true; do
        local choice
        echo -ne "${YLW}"
        read -p "[#|IP]: " choice
        echo -ne "${NC}"
        case $choice in
            1) handle_ipsum_download ;;
            2) handle_aggregator ;;
            3) handle_blacklist_ban ;;
            4) handle_manual_ban ;;
            5) handle_download_and_ban; break ;;
            6) handle_firewalls ;;
            7) handle_cron_jobs ;;
            8) handle_geo_ip_info ;;
            9) handle_logs_info ;;
            0) debug_log "0. Exit"; vquit; break ;;
            *) if validate_ip "$choice"; then
                    echo -e "${YLW}Manual Ban IP: $choice${NC}"
                    geo_ip "$choice"
                    INFOS="true"    
                    ban_ip "$MANUAL_IPSET_NAME" "$choice"
                    next
                else
                    echo -e "${YLW}Invalid option. ${BG}[0-9 or CIDR address]${NC}"
                fi
            ;;
        esac
    done
}

# Menu selector functions (at the end 'cause so exotic that messes up formatting)

function ipsets_selector () { 
    #local select_ipsets=("$@":-"$IPSET_NAME" "$MANUAL_IPSET_NAME")
    #local test_select_ipsets=${@:-$IPSET_NAME $MANUAL_IPSET_NAME}
    #local ipset=${1:-"$IPSET_NAME"}
    #standard_ipsets=("$IPSET_NAME" "$MANUAL_IPSET_NAME")
    local select_ipsets=("$@")

    ipset_counts=()
    ipset_display=()

    for ipset in "${select_ipsets[@]}"; do
        count=$(count_ipset "$ipset")
        ipset_counts+=("$count")
        ipset_display+=("$ipset  \t[ $count ]")
    done

    multiselect result ipset_display false

    selected_ipsets=()
    selected_counts=()
    idx=0
    for selected in "${select_ipsets[@]}"; do
        if [[ "${result[idx]}" == "true" ]]; then
            selected_ipsets+=("$selected")
            selected_counts+=("${ipset_counts[idx]}")
        fi
        ((idx++))
    done
    #echo "${selected_ipsets[@]}"
}

function multiselect() {

    local return_value=$1
    local -n options=$2
    local -n defaults=$3

    # source https://unix.stackexchange.com/a/673436
    if tput colors | grep -q '256' && ! [ "$DEBUG" == "true" ]; then
        
        #my_options=(   "Option 1"  "Option 2"  "Option 3" )
        #preselection=( "true"      "true"      "false"    )
        #multiselect result my_options preselection (or false if no preselection)
        #i=0
        #for option in "${my_options[@]}"; do
        #    echo -e "$option\t=> ${result[i]}"
        #    ((i++))
        #done
        
        ESC=$( printf "\033")
        cursor_blink_on()   { printf "$ESC[?25h"; }
        cursor_blink_off()  { printf "$ESC[?25l"; }
        cursor_to()         { printf "$ESC[$1;${2:-1}H"; }
        print_inactive()    { printf "$2   $1 "; }
        print_active()      { printf "$2  $ESC[7m $1 $ESC[27m"; }
        get_cursor_row()    { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }

        local selected=()
        for ((i=0; i<${#options[@]}; i++)); do
            if [[ ${defaults[i]} = "true" ]]; then
                selected+=("true")
            else
                selected+=("false")
            fi
            printf "\n"
        done
        # determine current screen position for overwriting the options
        local lastrow=`get_cursor_row`
        local startrow=$(($lastrow - ${#options[@]}))

        # ensure cursor and input echoing back on upon a ctrl+c during read -s
        trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
        cursor_blink_off

        key_input() {
            local key
            IFS= read -rsn1 key 2>/dev/null >&2
            if [[ $key = ""      ]]; then echo enter; fi;
            if [[ $key = $'\x20' ]]; then echo space; fi;
            if [[ $key = "k" ]]; then echo up; fi;
            if [[ $key = "j" ]]; then echo down; fi;
            if [[ $key = $'\x1b' ]]; then
                read -rsn2 key
                if [[ $key = [A || $key = k ]]; then echo up;    fi;
                if [[ $key = [B || $key = j ]]; then echo down;  fi;
            fi 
        }

        toggle_option() {
            local option=$1
            if [[ ${selected[option]} == true ]]; then
                selected[option]=false
            else
                selected[option]=true
            fi
        }

        print_options() {
            # print options by overwriting the last lines
            local idx=0
            for option in "${options[@]}"; do
                local prefix="[ ]"
                if [[ ${selected[idx]} == true ]]; then
                prefix="[\e[38;5;46m✔\e[0m]"
                fi

                cursor_to $(($startrow + $idx))
                if [ $idx -eq $1 ]; then
                    print_active "$option" "$prefix"
                else
                    print_inactive "$option" "$prefix"
                fi
                ((idx++))
            done
        }

        local active=0
        while true; do
            print_options $active

            # user key control
            case `key_input` in
                space)  toggle_option $active;;
                enter)  print_options -1; break;;
                up)     ((active--));
                        if [ $active -lt 0 ]; then active=$((${#options[@]} - 1)); fi;;
                down)   ((active++));
                        if [ $active -ge ${#options[@]} ]; then active=0; fi;;
            esac
        done

        # cursor position back to normal
        cursor_to $lastrow
        printf "\n"
        cursor_blink_on

        eval $return_value='("${selected[@]}")'

    else
        local selected=()
        for ((i=0; i<${#options[@]}; i++)); do
            if [[ ${defaults[i]} = "true" ]]; then
                selected+=("true")
            else
                selected+=("false")
            fi
        done

        echo -e "${DM}(Multiselect not available in low color mode. Fallback to single # selection.)${NC}"
        i=0
        m=1
        for option in "${options[@]}"; do
            echo -ne "\t $m. $option"
            echo -e "${NC}"
            ((i++))
            ((m++))
        done

        local multichoice=0
        debug_log "multichoice ${multichoice} multichoice ${multichoice}"
        
        while true; do
            echo -e "${YLW}"
            read -p "[1-${#options[@]}]: " multichoice
            case $multichoice in
                [0])  break;;
                [1-${#options[@]}])  
                    ((multichoice--))
                    selected[$multichoice]="true"; break;;
                *)  echo; echo -ne "${YLW}Invalid option. ${BG}[0 to exit]${NC}" ;;
            esac
        done
        echo -ne "${NC}"
        #echo -e "multichoice ${multichoice} multichoice ${multichoice}"
       

        eval $return_value='("${selected[@]}")'
    fi
}

function select_option() {
     # source github https://unix.stackexchange.com/questions/146570/arrow-key-enter-menu
        #   Arguments   : list of options, maximum of 256
        #   Return value: selected index (0 for opt1, 1 for opt2 ...)

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "   $1 "; }
    print_selected()   { printf "  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    key_input()        { read -s -n3 key 2>/dev/null >&2
                         if [[ $key = $ESC[A ]]; then echo up;    fi
                         if [[ $key = $ESC[B ]]; then echo down;  fi
                         if [[ $key = ""     ]]; then echo enter; fi; }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt; do printf "\n"; done

    # determine current screen position for overwriting the options
    local lastrow=`get_cursor_row`
    local startrow=$(($lastrow - $#))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local selected=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for opt; do
            cursor_to $(($startrow + $idx))
            if [ $idx -eq $selected ]; then
                print_selected "$opt"
            else
                print_option "$opt"
            fi
            ((idx++))
        done

        # user key control
        case `key_input` in
            enter) break;;
            up)    ((selected--));
                   if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
            down)  ((selected++));
                   if [ $selected -ge $# ]; then selected=0; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $selected
}

debug_log "vipb-ui.sh $( echo -e "${GRN}OK${NC}")"