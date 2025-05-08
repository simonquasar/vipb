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
    read -p "_ " choice
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

function subtitle() {
    if command -v figlet >/dev/null 2>&1 && [ "$DEBUG" == "false" ] && [ -f "$SCRIPT_DIR/tmplrREMOVE.flf" ]; then
        figlet -f "$SCRIPT_DIR/tmplr.flf" "$@"
    else
        echo
        center "\033[47;7;1m -=≡≡ $* ≡≡=- \033[0m"
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
    subtitle "Blacklists ban"
	
    ipb_files=()
    while IFS= read -r -d '' file; do
        if [[ -f "$file" && ! "$file" =~ vipb-s && ! "$file" =~ vipb-o && ! "$file" =~ vipb-b ]]  || [[ "$file" =~ DUPLICATE ]] ; then
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
        echo -e "${RED}ipset not found. Limited options available.${NC}"
        echo
        echo -e "\t1. View ${BLU}${BG}*.ipb${NC} lists\t${DM}>>${NC}"
        echo -e "\t2. ${ORG}Delete ${BLU}blacklists${NC} files \t${DM}>>${NC}"
        echo
        echo -e "\t${DM}0. <<" 
        echo -e "\e[0m"
        echo
        while true; do
            echo -ne "${YLW}"
            read -p "_ " blacklist_choice
            echo -e "${NC}"
            case $blacklist_choice in
                1)  debug_log " $blacklist_choice. READ IPB FILE"
                    subtitle "${BLU}Read *.ipb list"
                    echo
                    echo -e "${YLW}Select with [space] the lists to view into, press ↵ to continue."
                    echo
                    
                    multiselect result ipb_files false

                    idx=0
                    selected_ipbf=()
                    for selected in "${ipb_files[@]}"; do
                        if [[ "${result[idx]}" == "true" ]]; then
                            selected_ipbf+=("$selected")
                        fi
                        ((idx++))
                    done

                    debug_log "selected_ipbf: ${selected_ipbf[*]}"
                    if [[ ${#selected_ipbf[@]} -eq 0 ]]; then
                        echo -e "${RED}No files selected.${NC}"
                    else
                        ips=()
                        for ipb_file in "${selected_ipbf[@]}"; do
                            echo -e "Reading file ${BLU}$ipb_file${NC} ... "
                            while IFS= read -r ip; do
                                if validate_ip "$ip"; then
                                    ips+=("$ip")
                                fi
                            done < "$ipb_file"

                            echo -e "${BLU}${BG}$ipb_file${NC} parsed."
                            echo
                        done
                        echo -e "0 to exit."
                        echo
                        number_menu "${NC}${DM}« Back${NC}\t" 
                    fi
                    next
                    handle_blacklist_ban
                    ;;
                2)  debug_log " $blacklist_choice. DELETE blacklist files"
                    subtitle "Clear blacklist files"
                    echo -e "${YLW}Select with [space] the blacklists to clear.${NC}"
                    echo "Press ↵ to continue."
                    echo

                    select_lists=("IPsum Blacklist" "Optimized Blacklist" "/24 subnets" "/16 subnets" )
                    for ipb_file in "${ipb_files[@]}"; do
                        select_lists+=("$ipb_file")
                    done
                    multiselect result select_lists false

                    selected_lists=()
                    idx=0
                    for selected in "${select_lists[@]}"; do
                        if [[ "${result[idx]}" == "true" ]]; then
                            selected_lists+=("$selected")
                            case $idx in
                                0)  true > "$BLACKLIST_FILE"
                                    echo -n "$BLACKLIST_FILE"
                                    ;;
                                1)  true > "$OPTIMIZED_FILE"
                                    echo -n "$OPTIMIZED_FILE"
                                    ;;
                                2)  true > "$SUBNETS24_FILE"
                                    echo -n "$SUBNETS24_FILE"
                                    ;;
                                3)  true > "$SUBNETS16_FILE"
                                    echo -n "$SUBNETS16_FILE"
                                    ;;
                                *)  rm -f "$selected"
                                    echo -n "$selected"
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
    else
        INFOS="false"
        echo -e "${YLW}All ready. What do you want to do?${NC}" 
        echo
        echo -e "\t${BD}${CYN}1. Ban aggregated list ✓${NC}  \t${CYN}$(wc -l < "$OPTIMIZED_FILE") sources${NC}"
        echo -e "\t${VLT}2. Ban source ${BG}IPsum${NC}${VLT} list${NC} \t${VLT}$(wc -l < "$BLACKLIST_FILE") IPs${NC}"
        echo -e "\t3. Only ${S24}/24 subnets${NC} #.#.#.${BD}0${NC} \t${S24}$(wc -l < "$SUBNETS24_FILE") networks${NC}"
        echo -e "\t4. Only ${S16}/16 subnets${NC} #.#.${BD}0.0${NC} \t${S16}$(wc -l < "$SUBNETS16_FILE") networks${NC}"
        echo -e "\t5. Ban ${BLU}from ${BG}*.ipb${NC} files \t${DM}>>${NC}"
        echo -e "\t6. View ${BLU}${BG}*.ipb${NC} list & ban \t${DM}>>${NC}"
        echo -e "\t7. ${ORG}Delete ${BLU}blacklists${NC} files \t${DM}>>${NC}"
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
                    check_vipb_ipsets
                    next
                    handle_blacklist_ban
                    ;;
                2)  debug_log " $blacklist_choice. BLACKLIST_FILE"
                    subtitle "${VLT}Ban original blacklist" 
                    ban_core "$BLACKLIST_FILE"
                    check_vipb_ipsets
                    next
                    handle_blacklist_ban
                    ;;    
                3)  debug_log " $blacklist_choice. SUBNETS24_FILE"
                    subtitle "${S24}Ban /24 subnets (#.#.#.0)"
                    ban_core "$SUBNETS24_FILE"
                    check_vipb_ipsets
                    next
                    handle_blacklist_ban
                    ;;
                4)  debug_log " $blacklist_choice. SUBNETS16_FILE"
                    subtitle "${S16}Ban /16 subnets (#.#.0.0)"
                    INFOS="true"
                    ban_core "$SUBNETS16_FILE"
                    check_vipb_ipsets
                    next
                    handle_blacklist_ban
                    ;;
                5)  debug_log " $blacklist_choice. BAN IPB_FILE"
                    subtitle "${BLU}Import *.ipb list"                
                    echo
                    echo -e "${YLW}Select with [space] the lists to import and ban into ${BG}$MANUAL_IPSET_NAME${NC}, press ↵ to continue."
                    echo
                    multiselect result ipb_files false
                    idx=0
                    selected_ipbf=()
                    for selected in "${ipb_files[@]}"; do
                        if [[ "${result[idx]}" == "true" ]]; then
                            selected_ipbf+=("$selected")
                        fi
                        ((idx++))
                    done
                    debug_log "selected_ipbf: ${selected_ipbf[*]}"
                    if [[ ${#selected_ipbf[@]} -eq 0 ]]; then
                        echo -e "${RED}No files selected.${NC}"
                    else
                        echo -e "The selected files will be loaded into ${YLW}${BG}$MANUAL_IPSET_NAME${NC}."
                        echo
                        for ipb_file in "${selected_ipbf[@]}"; do
                            INFOS="true"
                            ban_core "$ipb_file" "$MANUAL_IPSET_NAME"
                            #echo -e "${BLU}${BG}$ipb_file${NC} parsed."
                            echo
                        done
                        check_vipb_ipsets
                        echo -e "${GRN}All files parsed."
                    fi
                    next
                    handle_blacklist_ban
                    ;;
                6)  debug_log " $blacklist_choice. READ IPB FILE  & BAN "
                    subtitle "${BLU}Read *.ipb list"
                    echo
                    echo -e "${YLW}Select with [space] the lists to view into, press ↵ to continue."
                    echo
                    
                    multiselect result ipb_files false

                    idx=0
                    selected_ipbf=()
                    for selected in "${ipb_files[@]}"; do
                        if [[ "${result[idx]}" == "true" ]]; then
                            selected_ipbf+=("$selected")
                        fi
                        ((idx++))
                    done

                    debug_log "selected_ipbf: ${selected_ipbf[*]}"
                    if [[ ${#selected_ipbf[@]} -eq 0 ]]; then
                        echo -e "${RED}No files selected.${NC}"
                    else
                        ips=()
                        for ipb_file in "${selected_ipbf[@]}"; do
                            echo -e "Reading file ${BLU}$ipb_file${NC} ... "
                            while IFS= read -r ip; do
                                if validate_ip "$ip"; then
                                    ips+=("$ip")
                                fi
                            done < "$ipb_file"

                            echo -e "${BLU}${BG}$ipb_file${NC} parsed."
                            echo
                        done
                        echo -e "${YLW}Select the number of an IP to ban in ${BG}$MANUAL_IPSET_NAME${NC}, 0 to exit."
                        echo

                        number_menu "${NC}${DM}« Back${NC}\t" "${ips[@]}"
                        selected="$?"
                        selected_ips=()
                        if [ "$selected" != "0" ]; then
                            selected="$((selected - 1))"
                            selected_ips=("${ips[$selected]}")
                            log "selected_ips: ${selected_ips[*]}"
                        fi

                        if [[ ${#selected_ips[@]} -eq 0 ]] || [[ ${#selected_ips[0]} == "0" ]] ; then
                            echo "Nothing to do."
                        else
                            echo "Adding selected IPs..."
                            INFOS="true"
                            add_ips "$MANUAL_IPSET_NAME" "${selected_ips[@]}"
                            check_vipb_ipsets
                            echo -e "$USER_BANS IPs banned${NC} in ${BG}$MANUAL_IPSET_NAME${NC}."
                        fi
                    fi
                    next
                    handle_blacklist_ban
                    ;;
                7)  debug_log " $blacklist_choice. DELETE blacklist files"
                    subtitle "Clear blacklist files"
                    echo -e "${YLW}Select with [space] the blacklists to clear.${NC}"
                    echo "Press ↵ to continue."
                    echo

                    select_lists=("IPsum Blacklist" "Optimized Blacklist" "/24 subnets" "/16 subnets" )
                    for ipb_file in "${ipb_files[@]}"; do
                        select_lists+=("$ipb_file")
                    done
                    multiselect result select_lists false

                    selected_lists=()
                    idx=0
                    for selected in "${select_lists[@]}"; do
                        if [[ "${result[idx]}" == "true" ]]; then
                            selected_lists+=("$selected")
                            case $idx in
                                0)  true > "$BLACKLIST_FILE"
                                    echo -n "$BLACKLIST_FILE"
                                    ;;
                                1)  true > "$OPTIMIZED_FILE"
                                    echo -n "$OPTIMIZED_FILE"
                                    ;;
                                2)  true > "$SUBNETS24_FILE"
                                    echo -n "$SUBNETS24_FILE"
                                    ;;
                                3)  true > "$SUBNETS16_FILE"
                                    echo -n "$SUBNETS16_FILE"
                                    ;;
                                *)  rm -f "$selected"
                                    echo -n "$selected"
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
    handle_blacklist_ban
}

# (Menu 4) manual banning 
function handle_manual_ban() {
    debug_log "5. Manual ban IPs"
    USER_STATUS=$(check_ipset "$MANUAL_IPSET_NAME" &>/dev/null)
    USER_BANS=$(count_ipset "$MANUAL_IPSET_NAME")   
    header
    echo -ne "${YLW}"
    subtitle "Manual ban IPs"
    
    echo -e "User bans are stored in ipset ${YLW}${BG}$MANUAL_IPSET_NAME${NC}. Max 254 sources allowed."
    echo -e "${DM}You can use the ${YLW}ban${NC}${DM} command to add IPs to the manual ipset via CLI.${NC}"
    echo
    if [[ $IPSET == "false" ]]; then
        echo -e "${RED}ipset not found. No option available."
        next
    else
        echo -e "${YLW}Banned IPs:${NC}"
        if [[ "$FIREWALL" == "firewalld" ]]; then 
            mapfile -t user_ips < <(firewall-cmd ${PERMANENT:+$PERMANENT} --ipset="$MANUAL_IPSET_NAME" --get-entries)
        elif [[ "$FIREWALL" == "iptables" ]]; then
            mapfile -t user_ips < <(ipset list "$MANUAL_IPSET_NAME" | grep -E '^[0-9]+\.')
        fi

        if [[ ${#user_ips[@]} -gt 10 ]]; then
            mapfile -t last_banned_ips < <(printf '%s\n' "${user_ips[@]}" | tail -n 10)
            remaining=$((${#user_ips[@]} - 10))
            last_banned_ips+=("${DM}+$remaining...")
            echo -e "${last_banned_ips[@]}" | tr ' ' '\n'
            #echo -e "Total IPs: ${#user_ips[@]}"
        elif [[ ${#user_ips[@]} -gt 0 ]]; then
            printf '%s\n' "${user_ips[@]}"
        else
            echo -e "${BG}No manually banned IPs found.${NC}"
        fi

        manual_options=()
        manual_options+=("${YLW}Ban IPs${NC}")

        if [[ "$IPSET" == "true" ]]; then
            manual_options+=("${ORG}View all / Unban IPs${NC}" "Export to file ${BLU}${BG}$MANUAL_IPSET_NAME.ipb${NC}")
        fi
        echo -e "${YLW}"
        select_opt "${NC}${DM}« Back${NC}" "${manual_options[@]}"
        manual_choice=$?
        case $manual_choice in
            0)  debug_log " $manual_choice. < Back to Menu"
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
                    echo -e "------------"
                    echo -e "${GRN}✓ $ADDED_IPS IPs added ${NC}($ALREADYBAN_IPS already banned)"
                    check_ipset "$MANUAL_IPSET_NAME" &>/dev/null && USER_BANS=$(count_ipset "$MANUAL_IPSET_NAME");
                    echo -e "${YLW}≡ $USER_BANS total IPs banned${NC} in set ${YLW}${BG}${MANUAL_IPSET_NAME}${NC}."
                fi
                next
                handle_manual_ban
                ;;
            2)  debug_log " $manual_choice. Unban / View"
                select_ips=()
                if [[ "$FIREWALL" == "firewalld" ]]; then
                    select_ips=($(firewall-cmd --ipset="$MANUAL_IPSET_NAME" --get-entries))
                elif [[ "$IPSET" == "true" ]]; then
                    select_ips=($(ipset list $MANUAL_IPSET_NAME | grep -E '^[0-9]+\.' | cut -f1))
                fi
                selected_ips=()

                if [[ ${#select_ips[@]} -gt 25 ]]; then
                    #   Use simple numbered menu 
                    echo -e "${YLW}Select the IP to unban, 0 to go back."
                    echo
                    number_menu "${NC}${DM}« Back${NC}\t" "${select_ips[@]}"
                    selected="$?"
                    if [ "$selected" != "0" ]; then
                        selected="$((selected - 1))"
                        selected_ips=("${select_ips[$selected]}")
                    fi
                else
                    echo -e "${YLW}Select with [space] the IPs to unban, press ↵ to continue."
                    echo
                    
                    multiselect result select_ips false

                    idx=0
                    for selected in "${select_ips[@]}"; do
                        if [[ "${result[idx]}" == "true" ]]; then
                            selected_ips+=("$selected")
                        fi
                    ((idx++))
                    done
                fi

                debug_log "selected_ips: ${selected_ips[*]}"

                if [[ ${#selected_ips[@]} -eq 0 ]] || [[ ${#selected_ips[0]} == "0" ]] ; then
                    echo -e "${RED}No IP entered.${NC}"
                else
                    echo "Removing selected IPs from ipset..."
                    remove_ips $MANUAL_IPSET_NAME "${selected_ips[@]}"
                    echo -e "${YLW} IPs ${NC}removed${YLW}"
                    count_ipset "$MANUAL_IPSET_NAME"
                    check_ipset "$MANUAL_IPSET_NAME" &>/dev/null && USER_BANS=$(count_ipset "$MANUAL_IPSET_NAME");
                    echo -e " IPs banned${NC} in ${BG}$MANUAL_IPSET_NAME${NC}."
                fi
                next
                handle_manual_ban
                ;;
            3)  debug_log " $manual_choice. Export to file"
                subtitle "export"
                if [[ "$FIREWALL" == "firewalld" ]]; then
                    firewall-cmd --ipset="$MANUAL_IPSET_NAME" --get-entries  > "$SCRIPT_DIR/$MANUAL_IPSET_NAME-$(date +%Y%m%d_%H%M%S).ipb"
                elif [[ "$IPSET" == "true" ]]; then
                    ipset list "$MANUAL_IPSET_NAME" | grep -E '^[0-9]+\.' > "$SCRIPT_DIR/$MANUAL_IPSET_NAME-$(date +%Y%m%d_%H%M%S).ipb"
                fi
                echo -e "Saved to ${BG}${BLU}$SCRIPT_DIR/$MANUAL_IPSET_NAME-$(date +%Y%m%d_%H%M%S).ipb${NC}"
                next
                handle_manual_ban
                ;;
        esac
        back
    fi
    back

}

# (Menu 5) DOWNLOAD, COMPRESS & BAN
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
                check_vipb_ipsets
                ;;
        esac
       
    fi
    next
    back
}

# (Menu 6) Check/Repair
function handle_check_repair() {
    debug_log "6. Check & Repair"
    header
    echo -ne "${SLM}"
    subtitle "+ Check & Repair +"
    check_and_repair && vipb_repair
    next
    back
}

# (Menu 7) manage ipsets  
function handle_ipsets() {
    debug_log "7. ipsets"
    header
    echo -ne "${BLU}"
    subtitle "ipsets"
    echo
    if [[ $IPSET == "false" ]]; then
        echo -e "${RED}ipset not found. No option available."
        next
    else
        if [[ "$FIREWALL" == "firewalld" ]]; then
            select_ipsets=($((sudo firewall-cmd --permanent --get-ipsets; firewall-cmd --get-ipsets | tr ' ' '\n') | sort -u))
            select_ipsets=($(printf "%s\n" "${select_ipsets[@]}" | awk '!seen[$0]++'))
            #select_ipsets=($(sudo firewall-cmd ${PERMANENT:+$PERMANENT} --get-ipsets)
        elif [[ "$IPSET" == "true" ]]; then
            select_ipsets=($(ipset list -n))
        fi
        echo
        echo -e "\t1. Manage ${BLU}ipsets${NC}"
        echo -e "\t2. ${S16}Create ${VLT}VIPB-ipsets${NC}\t${DM}>>${NC}"
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
                1)  debug_log " $ipsets_choice. Manage ipsets"
                    subtitle "${BLU}Manage ipsets"
                    if [[ ${#select_ipsets[@]} -eq 0 ]]; then
                        echo -e "${RED}No ipsets found.${NC} Create them with option 2."
                    else
                        #echo -e  "${YLW} Select with the ipset to view into, press ↵ to continue.${NC}"
                        echo
                        ipsets_options=()
                        for ipset in "${select_ipsets[@]}"; do
                            if [[ "$ipset" != vipb-* ]]; then
                                ipsets_options+=("${BLU}$ipset ${NC}")
                            else
                                ipsets_options+=("${VLT}$ipset ${NC}")
                            fi
                        done
                        select_opt "${NC}${DM}« Back${NC}" "${ipsets_options[@]}"
                        ipsets_select=$?

                        case $ipsets_select in
                            0)  debug_log " $ipsets_select. < Back"
                                handle_ipsets
                                ;;
                            *)  debug_log " $ipsets_select. ipset"
                                idx=$((ipsets_select - 1))
                                current_ipset="${select_ipsets[$idx]}"
                                options=("${BD}Details ${NC}")
                                if [[ "$current_ipset" == vipb-* ]]; then
                                    options+=("${YLW}Clear ${NC}" "${RED}${DM}Destroy ${NC}")
                                fi
                                echo
                                select_opt "${NC}${DM}« Back${NC}" "${options[@]}"
                                ipset_opt=$?
                                case $ipset_opt in
                                    0)  debug_log " $ipset_opt. < Back"
                                        handle_ipsets
                                        ;;
                                    1)  debug_log " $ipset_opt. Details"
                                        subtitle "$current_ipset"
                                        check_ipset "$current_ipset"
                                        check_status="$?"
                                        echo
                                        count=$(count_ipset "$current_ipset")
                                        echo -e "${VLT}$count entries${NC} in set"
                                        case $check_status in
                                            0 | 2 | 3 | 4 | 5)    desc=$(ipset list "$current_ipset" | grep "Name:" | awk '{print $2}')
                                                            type=$(ipset list "$current_ipset" | grep "Type:" | awk '{print $2}')
                                                            maxelem=$(ipset list "$current_ipset" | grep -o "maxelem [0-9]*" | awk '{print $2}')
                                                            echo -e "description: ${BD}$desc${NC}"
                                                            echo "ipset type: $type"
                                                            echo "maxelements: $maxelem";;
                                        esac
                                        ;;
                                    2)  debug_log " $ipset_opt. Clear"
                                        subtitle "${VLT}Clear $current_ipset"
                                        if [[ "$current_ipset" != vipb-* ]]; then
                                            echo -e "${RED}Skipping ipset ${BLU}$current_ipset${NC} as it is not a VIPB ipset (read-only).${NC}"
                                        else
                                            echo -e "${YLW}Are you sure?"
                                            select_opt "No" "Yes"
                                            select_yesno=$?
                                            case $select_yesno in
                                                0)  echo "Nothing to do."
                                                    ;;
                                                1)  echo -e "${VLT}☷ Clearing '$current_ipset' ipset...${NC} "
                                                    clear_ipset "$current_ipset"
                                                    check_vipb_ipsets
                                                    echo
                                                    VIPB_BANS=$(count_ipset "$VIPB_IPSET_NAME")
                                                    USER_BANS=$(count_ipset "$MANUAL_IPSET_NAME")
                                                    echo -e "${VLT}Done.${NC}"
                                                    ;;
                                            esac
                                        fi
                                        ;;
                                    3)  debug_log " $ipset_opt. Destroy"
                                        echo -ne "${RED}"
                                        subtitle "X destroy $current_ipset X"
                                        if [[ "$current_ipset" != vipb-* ]]; then
                                            echo -e "${RED}Skipping ipset ${BLU}$current_ipset${NC} as it is not a VIPB ipset (read-only).${NC}"
                                        else
                                            echo -e "This action will ${ORG}*also* remove related $FIREWALL${NC} rules!${NC}"
                                            echo -e "${YLW}Are you sure?"
                                            select_opt "No" "Yes"
                                            select_yesno=$?
                                            case $select_yesno in
                                                0)  echo "Nothing to do."
                                                        ;;
                                                1)  
                                                    echo -ne "${ORG}▤ Removing related '$FIREWALL' rules...${NC} "
                                                    if remove_firewall_rules "$current_ipset" &>/dev/null; then
                                                        echo -e "${GRN}OK${NC}"
                                                    else
                                                        echo -e "${RED}error${NC}"
                                                    fi
                                                    echo
                                                    echo -e "${VLT}☷ Clearing ipset '$current_ipset'...${NC} "
                                                    clear_ipset "$current_ipset"
                                                    echo
                                                    echo -e "${BLU}☷ Destroying '$current_ipset' ipset...${NC} "
                                                    destroy_ipset "$current_ipset"
                                                    echo
                                                    check_firewall_rules
                                                    check_vipb_ipsets
                                                    echo -e "${VLT}Done.${NC}"
                                                    ;;
                                                esac
                                        fi
                                        ;;
                                esac
                                next
                                ;;
                        esac
                    fi
                    ;;
                2)  debug_log " $ipsets_choice. Re-Create VIPB-ipsets"
                    subtitle "${VLT}Create VIPB-ipsets"
                    echo -e "This will NOT remove related firewall rules!${NC}"
                    echo
                    select_ipsets=("$VIPB_IPSET_NAME" "$MANUAL_IPSET_NAME")
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
                                    echo -e "Setting up new ipset... "
                                    if setup_ipset "$ipset_name"; then
                                        echo -e "${GRN}OK${NC}"
                                    fi
                                done
                                echo
                                check_vipb_ipsets
                                echo -e "${VLT}Done.${NC}"
                                ;;
                        esac
                    fi
                    next
                    ;;
                0)  debug_log " $ipsets_choice. << Back to Menu"
                    back
                    ;;
            esac
            handle_ipsets
        done
    fi
    back
}

# (Menu 8) manage firewalls  
function handle_firewalls() {
    debug_log "8. Firewall"
    header
    echo -ne "${ORG}"
    subtitle "Firewall"
    echo -ne "Firewall ${ORG}${BG}${FIREWALL}${NC} in use "
    $PERSISTENT && echo -ne "with ${S16}permanent rules${NC}";
    echo
    echo
    echo -e "\t1. View ${ORG}all rules${NC}"
    echo -e "\t2. ${S16}Create ${ORG}VIPB-rules${NC}\t ${DM}>>${NC}"
    echo -e "\t3. Remove ${ORG}all VIPB-rules${NC} ${DM}>>${NC}"
    echo -ne "\t4. "
    if [[ "$FIREWALL" == "iptables" ]]; then
        echo -e "Save rules"
    elif [[ "$FIREWALL" == "firewalld" ]]; then
        if [[ "$PERMANENT" == "--permanent" ]]; then
            echo -e "${BLU}Apply changes${NC} (reload)"
        else
            echo -e "Save as ${BLU}--permanent${NC}"
        fi
    fi
    echo -e "\t5. Change firewall \t ${RED}!${NC}${DM}>>${NC}"
    if [[ "$FIREWALL" == "firewalld" ]]; then
        echo -e "\n\t${DM}✦ $FIREWALL${NC}"
        echo -ne "\t6. Switch to "
        if [[ "$PERMANENT" == "--permanent" ]]; then
           echo -e "${S24}runtime${NC} edit"
        else
           echo -e "${BLU}--permanent${NC} edit"
        fi
    fi
    echo
    echo -e "\t${DM}0. <<${NC}" 
    echo -e "\e[0m"
    echo
    echo -e "${YLW}All ready. What do you want to do?" 
    echo
    while true; do
        read -p "_ " fw_choice
        echo -e "${NC}"
        case $fw_choice in
            1)  debug_log " $fw_choice. View all rules"
                header
                echo -ne "${SLM}"
                subtitle "$FIREWALL rules" 
                if get_fw_rules; then 
                    for i in "${!FW_RULES_LIST[@]}"; do
                        echo "${FW_RULES_LIST[$i]}"
                    done
                    echo
                    check_vipb_rules
                else
                    echo -e "${RED}No rules found.${NC} System unprotected."
                fi
                echo
                rules_options=()
                for idx in "${FOUND_VIPB_RULES[@]}"; do
                    rule_num=$((idx + 1))
                    rules_options+=("${SLM}#$rule_num ${NC}")
                done
                select_opt "${NC}${DM}« Back${NC}" "${rules_options[@]}"
                rules_select=$?
                case $rules_select in
                    0)  debug_log " $rules_select. < Back"
                        handle_firewalls
                        ;;
                    *)  debug_log " $rules_select. rule"
                        rules_select=$((rules_select - 1))
                        selected_rule_number="${FOUND_VIPB_RULES[$rules_select]}"
                        selected_rule_number=$((selected_rule_number + 1))
                        echo -e "${SLM}${selected_rule_number}${NC}"
                        #selected_rule_txt=$(get_fw_ruleNUM $selected_rule_number)
                        #echo "${selected_rule_txt}"
                        
                        select_opt "${NC}${DM}« Back${NC}" "Remove"
                        rule_opt=$?
                        case $rule_opt in
                            0)  debug_log " $rule_opt. < Back"
                                handle_firewalls
                                ;;
                            1)  debug_log " $rule_opt. Remove"
                                if remove_firewall_rule $selected_rule_number; then
                                    echo "Rule #$selected_rule_number removed."
                                else
                                    echo -e "${RED}Failed to remove rule #$selected_rule_number${NC}"
                                fi
                                ;;
                            2)  debug_log " $rule_opt. Move to top"
                                echo "fw_rule_move_to_top $selected_rule_number"
                                ;;
                            
                        esac
                        ;;
                esac
                next
                handle_firewalls
                ;;
            2)  debug_log " $fw_choice. Create VIPB-rules"
                subtitle "Re-/Create VIPB rules"

                select_ipsets=("$VIPB_IPSET_NAME" "$MANUAL_IPSET_NAME")
                ipsets_selector "${select_ipsets[@]}"

                if [[ ${#selected_ipsets[@]} -eq 0 ]]; then
                    echo -e "${RED}No ipsets selected.${NC}"
                else
                    echo -e "This process won't remove any bans. \n${YLW}Proceed?"
                    select_opt "No" "Yes"
                    select_yesno=$?
                    case $select_yesno in
                        0)  echo "Nothing to do."
                            ;;
                        1)  for ipset_name in "${selected_ipsets[@]}"; do  
                                echo -e "${ORG}☷ ipset '${ipset_name}' ⇄ ${BG}$FIREWALL ${NC}"
                                echo -e "Checking firewall rules..."
                                if [[ $(check_firewall_rules "$ipset_name") == 0 ]] || [[ $(check_firewall_rules "$ipset_name") == 3 ]] || [[ $(check_firewall_rules "$ipset_name") == 4 ]]; then
                                    echo -e "Rules found."
                                    if remove_firewall_rules "$ipset_name" ; then
                                        echo -e "${GRN}Done${NC}"
                                    else
                                        echo -e "${RED}Failed${NC}" "$?"
                                    fi  
                                else
                                    echo "No rule found."
                                fi
                                if add_firewall_rules "$ipset_name" ; then
                                    echo -e "${GRN}OK${NC}"
                                else
                                    echo -e "${RED}failed${NC}" "$?"
                                fi
                            done
                            check_firewall_rules
                            ;;
                    esac
                fi
                next
                ;;
            3)  debug_log " $fw_choice. Remove VIPB-rules"
                subtitle "Remove VIPB-rules"

                select_ipsets=("$VIPB_IPSET_NAME" "$MANUAL_IPSET_NAME")
                ipsets_selector "${select_ipsets[@]}"

                if [[ ${#selected_ipsets[@]} -eq 0 ]]; then
                    echo -e "${RED}No ipsets selected.${NC}"
                else
                    echo -e "${YLW}This process will remove all bans. Proceed?"
                    select_opt "No" "Yes"
                    select_yesno=$?
                    case $select_yesno in
                        0)  echo "Nothing to do."
                            ;;
                        1)  for ipset_name in "${selected_ipsets[@]}"; do  
                                echo -e "${VLT}☷ ipset '${ipset_name}' ⇄ ${BG}$FIREWALL ${NC}"
                                if remove_firewall_rules "$ipset_name" ; then
                                    echo -e "${VLT}Done.${NC}"
                                else
                                    echo -e "${RED}Failed${NC}" "$?"
                                fi
                            done
                            check_firewall_rules
                            ;;
                    esac
                fi
                next
                ;;
            4)  debug_log " $fw_choice. Save rules"
                if [[ "$FIREWALL" == "iptables" ]]; then
                    save_iptables_rules
                elif [[ "$FIREWALL" == "firewalld" ]]; then
                    if [[ "$PERMANENT" == "--permanent" ]]; then
                        reload_firewall
                    else
                        firewall-cmd --runtime-to-permanent
                    fi
                    echo -ne "Edit mode changed to " 
                    [[ "$PERMANENT" == "--permanent" ]] && echo -e "${BLU}--permanent${NC}" || echo -e "${S24}--runtime${NC}" ;
                fi
                next
                ;;
            
            5)  debug_log " $fw_choice. Change firewall"
                subtitle "${ORG}Change firewall"
                echo -e "${ORG}Change firewall at your risk.${NC}"
                echo -e "This section is in still in development and not optimized for cross-use between firewalls yet."
                echo -e "Misuse could bring to orphaned rules or ipsets in your system."
                echo

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
                
                select_opt "${NC}${DM}« Back${NC}" "${fw_options[@]}"
                fw_options=$?
                case $fw_options in
                    0)  debug_log " $fw_options. < Back to Menu"
                        handle_firewalls
                        ;;
                    1)  debug_log " $fw_options. iptables"
                        FIREWALL="iptables"
                        PERMANENT=''
                        ;;
                    2)  debug_log " $fw_options. FirewallD"
                        FIREWALL="firewalld"
                        PERMANENT=''
                        ;;
                    3)  debug_log " $fw_options. ufw"
                        FIREWALL="ufw"
                        PERMANENT=''
                        ;;
                esac
                # Update vipb-core.sh with the new fw 
                sed -i "0,/^FIREWALL='.*'/s//FIREWALL='$FIREWALL'/" "$SCRIPT_DIR/vipb-core.sh"
                echo -e "Firewall changed to ${ORG}$FIREWALL${NC}"
                log "Firewall changed to: $FIREWALL"
                METAERRORS=0
                echo -n "Checking firewall rules... "
                check_firewall_rules
                echo "OK"
                check_vipb_ipsets
                next
                ;;
            6)  debug_log " $fw_choice. Switch Edit Mode"
                if [[ "$FIREWALL" == "firewalld" ]]; then        
                    if [[ "$PERMANENT" == "--permanent" ]]; then
                        #needs reload to be saved
                        PERMANENT=""
                    else
                        PERMANENT="--permanent" ;
                    fi
                    echo -ne "Edit mode changed to " 
                    [[ "$PERMANENT" == "--permanent" ]] && echo -e "${BLU}--permanent${NC}" || echo -e "${S24}--runtime${NC}" ;
                fi
                next
                ;;
            7)  debug_log " $fw_choice. Reload firewall" #DELETEME
                subtitle "Reload"

                echo -e "We'll reload the firewall. ${YLW}Proceed?"
                select_opt "No" "Yes"
                select_yesno=$?
                case $select_yesno in
                    0)  echo "Nothing to do." ;;
                    1)  reload_firewall ;;
                esac
                next
                ;;
            0)  debug_log " $fw_choice. << Back to Menu"
                back
                ;;
        esac
        handle_firewalls
    done
}

# (Menu 9) cron job daily autoban
function handle_cron_jobs() {
    debug_log "9. Daily Cron Job"
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
    select_opt "${NC}${DM}« Back${NC}" "${cron_options[@]}"
    cron_select=$?
    case $cron_select in
        0)  debug_log " $cron_select. < Back to Menu"
            back
            ;;
        1)  debug_log " $cron_select. download list level"
            subtitle "set fire level"
            # "Change default IPsum list level"
            select_opt "${NC}${DM}« Back${NC}" "" "${RED}  2  caution! big list${NC}" "${YLW}  3  ${NC}" "${GRN}  4  ${NC}" "${S16}  5  ${NC}" "${YLW}  6  ${NC}" "${ORG}  7  ${NC}"  "${ORG}  8  ${NC}"
            select_lv=$?
            case $select_lv in
                [0-1])  back
                    ;;
                [2-8]) 
                    set_blacklist_level $select_lv
                    ;;
            esac
            next
            handle_cron_jobs
            ;;
        2)  debug_log " $cron_select. VIPB autoban job"
            if [[ "$DAILYCRON" == "true" ]]; then
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
            handle_cron_jobs           
            ;;
    esac
    handle_cron_jobs
}

# (Menu 10) Geo IP lookup 
function handle_geo_ip_info() {
    debug_log "10. GeoIP lookup"
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

# (Menu 11) Logs and info 
function handle_logs_info() {
    debug_log "11. Logs & infos"
    header
    echo -ne "${ORG}"
    subtitle "Logs & infos"
    
    log_selector(){
        echo
        loglen=20
        more_loglen=$(($loglen * 100))

        echo -e "${ORG}■■■ LOG & DATA VIEWER ■■■${NC}"
        echo "View system logs and ★ extract IPs."
        echo        
        log_options=("${VLT}VIPB log" "VIPB log ${BG}*reset*" "VIPB variables ${NC}")
        log_options+=("${S16}syslog ${NC}" "${S16}journalctl ${NC}" "${ORG}★ auth.log" "★ ${BG}custom log ${NC}")
        if [[ $FAIL2BAN == "true" ]]; then
            log_options+=("${ORG}★ Fail2Ban" "★ Fail2Ban [WARNING]s ${NC}")
        fi
        
        select_opt "${NC}${DM}« Back${NC}" "${log_options[@]}"
        log_select=$?
        case $log_select in
            0)  debug_log " $log_select. < Back to Menu"
                back
                ;;
            1)  debug_log " $log_select. VIPB log"
                header
                echo
                echo -e "${VLT}▗ $SCRIPT_DIR/vipb-log.log${NC}"
                tail -n $loglen $SCRIPT_DIR/vipb-log.log
                ;;
            2)  debug_log " $log_select. reset VIPB log"
                header
                echo
                echo -e "${VLT}▗ VIPB${NC} (last $loglen lines)"
                tail -n $loglen $SCRIPT_DIR/vipb-log.log
                echo
                > "$SCRIPT_DIR/vipb-log.log"
                echo -e "VIPB-log ${YLW}cleared${NC}"
                ;;
            3)  debug_log " $log_select. VIPB variables"
                header
                echo
                echo -e "${VLT}▗ VIPB variables"    #2do
                vars=(
                    "              VER:$VER"
                    "              CLI:$CLI"
                    "            DEBUG:$DEBUG"
                    "${BLU}       SCRIPT_DIR:$SCRIPT_DIR"
                    "         LOG_FILE:$LOG_FILE"
                    "${CYN}  VIPB_IPSET_NAME:$VIPB_IPSET_NAME [$VIPB_STATUS]"
                    "MANUAL_IPSET_NAME:$MANUAL_IPSET_NAME [$USER_STATUS]"
                    "${ORG}         FIREWALL:$FIREWALL"
                    "            IPSET:$IPSET"
                    "         IPTABLES:$IPTABLES"
                    "        FIREWALLD:$FIREWALLD"
                    "              UFW:$UFW"
                    "       PERSISTENT:$PERSISTENT"
                    "        PERMANENT:$PERMANENT"
                    "${SLM}             CRON:$CRON"
                    "        DAILYCRON:$DAILYCRON"
                    "     BLACKLIST_LV:$BLACKLIST_LV"
                )
                for var in "${vars[@]}"; do
                    key="${var%%:*}"
                    value="${var#*:}"
                    echo -e "${key}: ${BG}${value}${NC}"
                done
                ;;
            4)  debug_log " $log_select. syslog"
                header
                echo
                echo -e "${S16}▗ /var/log/syslog${NC}"
                tail -n $loglen /var/log/syslog
                ;;
            5)  debug_log " $log_select. journalctl"
                header
                echo
                echo -e "${S16}▗ ${BG}journalctl -n $loglen${NC}"
                journalctl -n "$loglen"
                ;;
            6)  debug_log " $log_select. auth.log"
                header
                echo
                echo -e "${CYN}▗ /var/log/auth.log${NC}"
                tail -n $loglen /var/log/auth.log
                echo
                log2ips "/var/log/auth.log" 'Connection closed'
                ;;
            7)  debug_log " $log_select. custom log"
                header
                echo
                echo -e "${CYN}▗ CUSTOM LOG${NC}"
                echo -ne "${YLW}"
                read -p "[Log File]: " log_file
                echo -ne "${NC}"
                echo -ne "${YLW}"
                read -p "[Pattern]: " grep_pattern
                echo -ne "${NC}"
                echo -e "trying ${BG}$log_file${NC} with '$grep_pattern'..."
                echo -ne "  ${DM}"
                grep -m 1 "$grep_pattern" $log_file
                echo -e "${NC}"
                log2ips "$log_file" "$grep_pattern"
                ;;
            8)  debug_log " $log_select. Fail2Ban"
                header
                echo
                echo -e "${SLM}▗ /var/log/fail2ban.log${NC}"
                tail -n $loglen /var/log/fail2ban.log
                echo
                log2ips "/var/log/fail2ban.log" "NOTICE"
                ;;
            9)  debug_log " $log_select. Fail2Ban [WARNING]s"
                header
                echo
                echo -e "${SLM}▗ Fail2Ban [WARNING]s${NC}"
                tail -n $loglen /var/log/fail2ban.log | grep "WARNING"
                echo
                log2ips "/var/log/fail2ban.log" "WARNING"
                next
                ;;
            
        esac
        log_selector
    }
    log_selector
    echo -e "\e[0m"
    next
    handle_logs_info
}

### Main UI

# Header Row
function services_row() {  
    rowtext="${NC}"
    
    #ipset        
    if [ "$IPSET" == "true" ]; then
        rowtext+="${VLT}✓"
    else
        rowtext+="${RED}✗"
    fi
    rowtext+=" ipset${NC} "
    
    #iptables
    if [ "$FIREWALL" == "iptables" ]; then
        rowtext+="${GRN}[${NC}"
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
    if [ "$FIREWALL" == "iptables" ]; then
        rowtext+="${GRN}]${NC}"
    fi 

    #firewalld
    if [ "$FIREWALL" == "firewalld" ]; then
        rowtext+="${NC}${GRN} ["
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
        rowtext+="${GRN}]${NC}"
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
            rowtext+="${DM}"
        fi 
        rowtext+="ufw${NC}"
    if [ "$FIREWALL" == "ufw" ]; then
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
        if crontab -l | grep -q "vipb\.sh"; then
            rowtext+="${GRN}↺${NC} "
            DAILYCRON=true
        else
            rowtext+="${RED}✗${NC} "
            DAILYCRON=false
        fi
        rowtext+="${GRN}"        
    else
        rowtext+="${DM}"
    fi
    rowtext+="${BG}cron${NC} "
    rowtext+="${VLT}L▼ $BLACKLIST_LV${NC}"

    rowtext+="${NC}"

    center "${rowtext}"

}

# Nice main header :)
function header() {
    if [ "$DEBUG" == "true" ]; then
        echo
        echo -e "▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤ ${YLW}DEBUG MODE ON${NC} ▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤"
        echo
    else
       clear
    fi
    
    echo -ne "${NC}${RED}${DM}"
    echo -e "▁ ▂ ▃ ▅ ▆ ▇ ▉ ▇ ▆ ▅ ▃ ▂ ${NC}${VLT}${BD}Versatile IPs Blacklister${NC} ${DM}${VER}${RED} ▁ ▂ ▃ ▅ ▆ ▇ ▉ ▇ ▆ ▅ ▃ ▂${NC}"
    echo -e "\t                                   ${DM}    •                  ${NC}"     
    echo -e "\t  ██╗   ██╗██╗██████╗ ██████╗      ${DM}   ┏┓┏┳┓┏┓┏┓┏┓┓┏┏┓┏┏┓┏┓${NC}"
    echo -e "\t  ██║   ██║██║██╔══██╗██╔══██╗     ${DM}by ┛┗┛┗┗┗┛┛┗┗┫┗┻┗┻┛┗┻┛ ${NC}"
    echo -e "\t  ██║   ██║██║██████╔╝██████╔╝     ${DM}             ┗         ${NC}"
    echo -ne "\t  ╚██╗ ██╔╝██║██╔═══╝ ██╔══██╗    "
    case $VIPB_STATUS in
        0 | 5) echo -ne "${GRN}";;      #OK
        1 | 6) echo -ne "${DM}${RED}";; #not found
        2) echo -ne "${RED}";;          #firewalld: no sets
        3) echo -ne "${S24}";;          #firewalld: ok runtime
        4) echo -ne "${BLU}";;          #firewalld: ok permanent
        7 | 8 | 9) echo -ne "${DM}${ORG}";;   #firewalld: orph
        *) log "$VIPB_STATUS";;
    esac
    echo -ne "✦ VIPB ${VLT}$VIPB_BANS ${NC}"   
    echo
    echo -ne "\t   ╚████╔╝ ██║██║     ██████╔╝    "
    case $USER_STATUS in
        0 | 5) echo -ne "${GRN}";;      #OK
        1 | 6) echo -ne "${DM}${RED}";; #not found
        2) echo -ne "${RED}";;          #firewalld: no sets
        3) echo -ne "${S24}";;          #firewalld: ok runtime
        4) echo -ne "${BLU}";;          #firewalld: ok permanent
        7 | 8 | 9) echo -ne "${DM}${ORG}";;   #firewalld: orph
        *) log "$USER_STATUS";;
    esac
    echo -ne "✦ USER ${YLW}$USER_BANS ${NC}"   
    echo
    echo -ne "\t    ╚═══╝  ╚═╝╚═╝     ╚═════╝     "
    [ "$FW_RULES" == "true" ] && echo -ne "${GRN}✦ " || echo -ne "${RED}✦ no ";
    echo -ne "rules${NC} in ${ORG}$FIREWALL${NC}"
    echo
    echo -ne "${DM}"
    if [ "$METAERRORS" -gt 0 ]; then
        center "${RED}------------------${NC}${RED}-- ${METAERROR:-"possible conflict detected"} --${DM}------------------${NC}"
    fi
    if [ "$FIREWALL" == "firewalld" ] && [ "$PERMANENT" == "--permanent" ]; then
        center "${BLU}----------------------${NC}${BLU}-- permanent editing --${DM}----------------------${NC}"
    elif [ "$FIREWALL" == "firewalld" ] ; then
        center "${S24}----------------------${NC}${S24}--- runtime editing ---${DM}----------------------${NC}"
    else
        center "--------------------------------------------------------------------"
    fi
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
    echo -e "\t6. ${SLM}Check ${NC}&${SLM} Repair${NC}"
    [[ $IPSET == "false" ]] && echo -ne "${DM}";
    echo -e "\t7. Manage ${BLU}ipsets${NC}"
    [[ $FIREWALL == "ERROR" ]] && echo -ne "${DM}";
    echo -e "\t8. Manage ${ORG}firewall${NC}"
    [[ $CRON == "false" ]] && echo -ne "${DM}";
    echo -ne "\t9. Daily ${SLM}Cron${NC}"
    [[ $CRON == "false" ]] && echo -ne "${DM}";
    echo -e " Job & ${VLT}L▼${NC}"
    echo -e "\t10${S24}. Geo IP${NC} lookup"
    echo -e "\t11${ORG}. Log Extractor ${NC}& Vars"
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
            5) handle_download_and_ban ;;
            6) handle_check_repair ;;
            7)  [[ $IPSET == "true" ]] && handle_ipsets || back ;;
            8)  [[ $FIREWALL == "ERROR" ]] && back || handle_firewalls ;;
            9)  [[ $CRON == "true" ]] && handle_cron_jobs || back ;;
            10) handle_geo_ip_info ;;
            11) handle_logs_info ;;
            0) debug_log "0. Exit"; vquit ;;
            *) if validate_ip "$choice"; then
                    echo -e "${YLW}Manual Ban IP: $choice${NC}"
                    geo_ip "$choice"
                    INFOS="true"    
                    ban_ip "$MANUAL_IPSET_NAME" "$choice"
                    USER_BANS=$(count_ipset "$MANUAL_IPSET_NAME")
                    next
                    back
                else
                    echo -e "${YLW}Invalid option. ${BG}[0-9 or CIDR address]${NC}"
                fi
            ;;
        esac
    done
}

# Menu and selector functions (at the end 'cause so exotic that messes up formatting)

function ipset_selector() { #SINGLE IPSET SELECTOR #2do not used yet
    
    local select_ipsets=("$@")

    ipset_counts=()
    ipset_display=()

    for ipset in "${select_ipsets[@]}"; do
        #ipset_display+=("$ipset")
        count=$(count_ipset "$ipset")
        ipset_counts+=("$count")
        ipset_options+=("$ipset  [ $count ]")
    done
    select_opt "${NC}${DM}« Back${NC}" "${ipset_options[@]}"
    echo "${selected_ipsets[@]}"
    
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
    echo "${selected_ipsets[@]}"
}

function ipsets_selector() { #MULTIPLE IPSETS SELECTOR
    #local select_ipsets=("$@":-"$IPSET_NAME" "$MANUAL_IPSET_NAME")
    #local test_select_ipsets=${@:-$IPSET_NAME $MANUAL_IPSET_NAME}
    #local ipset=${1:-"$IPSET_NAME"}
    #standard_ipsets=("$IPSET_NAME" "$MANUAL_IPSET_NAME")
    local select_ipsets=("$@")

    ipset_counts=()
    ipset_display=()

    for ipset in "${select_ipsets[@]}"; do
        #ipset_display+=("$ipset")
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

function number_menu (){
    local options=("$@")
    local selected=""
    local i=0
    echo -ne "${NC}"
    for option in "${options[@]}"; do
        echo -ne "${DM}$i.${NC} "
        echo -ne "$option "
        if ((${#options[@]} > 999)) && ((i % 4 == 0)); then
            echo -ne "${NC}\t"
        elif ((${#options[@]} > 120)) && ((i % 3 == 0)); then
            echo -ne "${NC}\t\t"
        elif ((${#options[@]} > 40)) && ((i % 2 == 0)); then
            echo -ne "${NC}\t\t"
        else
            echo -e "${NC}"
        fi
        ((i++))
    done
    
    while true; do
        echo -e "${YLW}"
        read -r -p "_ " selected
        echo -ne "${NC}"
        case $selected in
            0)  echo; return 0 ;;
            [1-9]|[1-9][0-9]|[1-9][0-9][0-9]|[1-9][0-9][0-9][0-9]|${#options[@]}) echo -e "${YLW}${options[$selected]}${NC}"; break;;
            *)  echo
                echo -e "${YLW}Invalid option: '$selected' ${NC}" #[${options[$selected]}]
                echo -e "${YLW}${BG}[0-${#options[@]}]${NC}" ;;
        esac
    done
    return $selected
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
        
        ESC="\033"
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

        #echo -e "${DM}(Multiselect not available in low color mode. Fallback to single # selection.)${NC}"
        i=0
        m=1
        for option in "${options[@]}"; do
            echo -e "${NC}\t ${DM}$m.${NC} $option"
            ((i++))
            ((m++))
        done

        local multichoice=0
        debug_log "multichoice ${multichoice} multichoice ${multichoice} opt # ${#options[@]}"
        
        while true; do
            echo -e "${YLW}"
            read -p "[1-${#options[@]}]: " multichoice
            case $multichoice in
                [0])  break;;
                [1-9]|[1-9][0-9]|[1-9][0-9][0-9]|${#options[@]})  
                    if ((multichoice >= 1 && multichoice <= ${#options[@]})); then
                        ((multichoice--))
                        selected[$multichoice]="true"; break
                    else
                        echo -e "${YLW}Invalid option. ${BG}[1-${#options[@]} or 0 to exit]${NC}"
                    fi
                    ;;
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