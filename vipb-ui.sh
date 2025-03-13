#!/bin/bash

# VIPB User Interface

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
    BG='\033[3m' # italic ? 
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
        #for i in {0..255} ; do
        #     printf "\x1b[48;5;%sm%3d\e[0m " "$i" "$i"
        #done
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
        SLM='\033[38:5:210m'    # lightcoral
        RED='\033[38;5;196m'    # red
        GRY='\033[38;5;15m'     # white
        #   activate advanced menu
        #   USAGE:
        #   menu_options=()
        #   menu_options+=("${GRN}Lookup IP${NC}")
        #   select_opt "${NC}${DM}<< Back${NC}" "${menu_options[@]}"
        #   menu_choice=$?
        #   case $menu_choice in
        #   ...
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
        GRY='\033[97m' # white
        #use simple menu 
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

#  UI-CORE functions

function back {
    header
    menu_main
}

function next() {
    echo -e "${NC}"
    echo -ne "${YLW}${DM}[enter] to continue"
    read -p "_ " p
    echo -e "${NC}"

    back
}

function vquit {
    echo -e "${VLT}"
    subtitle "ViPB end."
    log "▩▩▩▩ VIPB $VER END. ▩▩▩▩"
    exit 0
}

function center() {
    text="$1"
    #width=${2:-$(tput cols)}
    width=${2:-80}
    textlen=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g' | wc -m)
    padding=$(( (width - textlen) / 2 ))
    printf "%*s%b%*s\n" $padding '' "$text" $padding ''
}

# UI-OPT functions

function subtitle {
    if command -v figlet >/dev/null 2>&1 && [ "$DEBUG" == "false" ] && [ -f "$SCRIPT_DIR/tmplrREMOVE.flf" ]; then
        figlet -f "$SCRIPT_DIR/tmplr.flf" "$@"
    else
        echo
        echo -e "\033[47;7;1m -=≡≡ $@ ≡≡=- \033[0m"
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

# Handlers UI - Main Menu functions

# IPsum blacklist download (Menu 1) download_blacklist
function handle_ipsum_download() {
    debug_log "1. Download IPsum Blacklist" 
    echo -ne "${VLT}"
    subtitle "Download IPsum Blacklist"
    echo -e "${BG}IPsum${NC} is a feed based on 30+ publicly available lists of suspicious and/or malicious IP addresses."
    echo -e "The provided list is made of IP addresses matched with a number of (black)lists occurrences. "
    echo -e "more infos at ${BG}https://github.com/stamparm/ipsum${NC}"
    echo
    echo -ne "≡ ${VLT}IPsum Blacklist "
    check_blacklist_file $BLACKLIST_FILE infos
    echo
    echo
    echo -e "Select ${BG}IPsum${NC} blacklist level, where level # => IPs appears on at least # blacklists"
    echo -e "${BD}${YLW}[2] more strict (caution big list!) <--> [8] less strict ${NC}"
    echo -e "${DM}[suggested 3-4, exit with 0]${NC}"
    echo -e "${YLW}"
	echo -ne "[LV 2-8${DM}|0${NC}${YLW}]: "
	read -p "" select_lv
	echo -e "${NC}"
    case $select_lv in
        0)  back ;;
        [2-8]) 
            download_blacklist $select_lv
            next
            ;;
    esac
}

# blacklist compression (Menu 2) aggregator
function handle_aggregator() {
    debug_log "2. VIPB-aggregator"
    echo -ne "${CYN}"
    subtitle "VIPB-aggregator"
    compressor
    next
}

# blacklist files (Menu 3)
function handle_blacklist_files() {
    debug_log "3. Blacklists Files"
    echo -ne "${BLU}"
    subtitle "Blacklists"
    echo -ne "${VLT} IPsum list  "
    check_blacklist_file "$BLACKLIST_FILE" infos
    echo
    echo -ne "${CYN} Optimized   "
    check_blacklist_file "$OPTIMIZED_FILE" infos
    if [ -f "$BLACKLIST_FILE" ]; then
        cmodified=$(stat -c "%y" "$BLACKLIST_FILE" | cut -d. -f1) 
        if [[ "$cmodified" > "$MODIFIED" ]]; then
            echo -ne " ${ORG}older!${NC}"
        fi 
    fi

    #2do add handling of custom .ipb files (see menu 3)
    echo
    echo -ne "${S24} Subnets /24 "
    check_blacklist_file $SUBNETS24_FILE infos    
    echo
    echo -ne "${S16} Subnets /16 "
    check_blacklist_file $SUBNETS16_FILE infos
    echo
	echo
	blacklist_options=()
    blacklist_options+=("${BLU}View / Clear blacklist files${NC}")
    select_opt "${NC}${DM}<< Back${NC}" "${blacklist_options[@]}"
    select_blackl=$?
    case $select_blackl in
        0)  debug_log " $select_blackl. < Back to Menu"
            back
            ;;
        1)  debug_log " $select_blackl. View / Clear blacklist files"
            echo "Select with [space] the Blacklists to clear, then press [enter] to continue."
            echo

            select_lists=("${BG}IPsum${NC} Blacklist (Single IPs)" "Optimized Blacklist (IPs & Subnets)" "/24 subnets (#.#.#.255)" "/16 subnets (#.#.255.255)" )

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
            ;;
    esac
    next
}

# blacklist banning (Menu 4) ban_core 
function handle_blacklist_ban() {
    debug_log "4. Ban"
    echo -ne "${VLT}"
    subtitle "Ban"
    if [[ $IPSET == "false" ]]; then
        echo -e "${RED}ipset not found. No option available."
    else
        check_ipset $IPSET_NAME
        check_ipset $MANUAL_IPSET_NAME
        INFOS="false"
        echo
        echo -e "All ready. What do you want to do?" 
        echo
        echo -e "\t1. Ban ${VLT}original blacklist${NC} (${VLT}$(wc -l < "$BLACKLIST_FILE") IPs${NC})"
        echo -e "\t2. Ban ${CYN}all optimized${NC} (${CYN}$(wc -l < "$OPTIMIZED_FILE") sources${NC})"
        echo -e "\t3. Ban ${S24}/24 subnets${NC} (#.#.#.\e[37m0${NC}) (${S24}$(wc -l < "$SUBNETS24_FILE") networks${NC})"
        echo -e "\t4. Ban ${S16}/16 subnets${NC} (#.#.\e[37m0.0${NC}) (${S16}$(wc -l < "$SUBNETS16_FILE") networks${NC})${ORG}!${NC}"
        echo -e "\t5. Ban ${BLU}from ${BG}*.ipb${NC} files${NC}"
        echo
        echo -e "\t${DM}0. <<" 
        echo -e "\e[0m"
        echo
        while true; do
            read -p "_ " blacklist_choice
            echo -e "${NC}"
            case $blacklist_choice in
                1)  debug_log " $blacklist_choice. BLACKLIST_FILE"
                    echo -e "${VLT}Ban original blacklist${NC}" 
                    ban_core "$BLACKLIST_FILE"
                    next
                    break
                    ;;    
                2)  debug_log " $blacklist_choice. OPTIMIZED_FILE"
                    echo -e "${CYN}Ban all optimized${NC}"
                    ban_core "$OPTIMIZED_FILE"
                    next
                    break
                    ;;
                3)  debug_log " $blacklist_choice. SUBNETS24_FILE"
                    echo -e "${S24}Ban /24 subnets${NC} (#.#.#.\e[37m0${NC})"
                    ban_core "$SUBNETS24_FILE"
                    next
                    break
                    ;;
                4)  debug_log " $blacklist_choice. SUBNETS16_FILE"
                    echo -e "${S16}Ban /16 subnets${NC} (#.#.\e[37m0.0${NC})"
                    INFOS="true"
                    ban_core "$SUBNETS16_FILE"
                    next
                    break
                    ;;
                5)  debug_log " $blacklist_choice. IPB_FILE"
                    echo -e "${VLT}Import *.ipb list"
                    echo
                    echo -e "Looking for ${BG}.ipb${NC} files in ${BG}$SCRIPT_DIR${NC} ..."
                    ipb_files=()
                    selected_ipbf=()
                    # Cerca file *.ipb nella directory dello script
                    while IFS= read -r -d '' file; do
                        ipb_files+=("$file")
                    done < <(find "$SCRIPT_DIR" -maxdepth 1 -name '*.ipb' -print0)

                    echo -e "Select with [space] the lists to import and ban into ${YLW}$IPSET_NAME${NC}, then press [enter] to continue."
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
                    ;;
                0)  debug_log " $blacklist_choice. << Back to Menu"
                    back
                    ;;
            esac
        done
    fi
    next
}

# manual banning (Menu 5)
function handle_manual_ban() {
    debug_log "5. Manual ban IPs"
    echo -ne "${YLW}"
    subtitle "Manual ban IPs"
    #echo -e "${YLW}Last 10 banned IPs:${NC}"
    #ipset list $MANUAL_IPSET_NAME | grep -E '^[0-9]+\.' | tail -n 10
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
        2)  debug_log " $manual_choice. View / Unban"
            echo "Select with [space] the IPs to unban, then press [enter] to continue."
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
            #2DO CHECK FUNCTION
            ipset save "$MANUAL_IPSET_NAME" > "$SCRIPT_DIR/$MANUAL_IPSET_NAME.ipb" THIS COMMAND SAVES ThE SEt!
            #iptables-save > "$SCRIPT_DIR/vipb-export.ipb" check persistent
            echo -e "Saved to ${BG}${BLU}$SCRIPT_DIR/$MANUAL_IPSET_NAME.ipb${NC}"
            next
            ;;
    esac
}

# manage banned sets (Menu 6)  
function handle_firewalls() {
    debug_log "6. Firewall & Sets"
    echo -ne "${ORG}"
    subtitle "Firewall & Sets"
    echo -ne "Firewall ${ORG}${BG}${FIREWALL}${NC} "
    if $FIREWALLD || $PERSISTENT; then
        echo -e "in use with ${S16}permanent rules${NC}"
    fi
    if [[ $IPSET == "true" ]]; then
        INFOS="true"
        check_ipset $IPSET_NAME
        check_ipset $MANUAL_IPSET_NAME
    else
        echo -e "${RED}ipset not found."
    fi
    echo
    echo -e "All ready. What do you want to do?" 
    echo
    echo -e "\t1. View current ${ORG}${BG}$FIREWALL${NC} rules"
    echo -e "\t2. Refresh ${ORG}${BG}$FIREWALL${NC} rules${NC}"
    echo -e "\t3. Change firewall ${ORG}!${NC}"
    if [[ $IPSET == "true" ]]; then
        echo -e "\t4. View/Clear active ipsets"
        echo -e "\t5. Re-/Create ${VLT}VIPB-ipsets${NC}"
        echo -e "\t6. Destroy ${VLT}VIPB-ipsets${NC} and ${ORG}rules !${NC}"
    fi
    echo
    echo -e "\t${DM}0. <<${NC}" 
    echo -e "\e[0m"
    echo
    while true; do
        read -p "_ " ipsets_choice
        echo -e "${NC}"
        case $ipsets_choice in
            1)  debug_log " $ipsets_choice. View current rules"
                subtitle "$FIREWALL rules"
                if [[ "$FIREWALL" == "iptables" ]]; then
                    iptables -L -v -n | head -n 20
                elif [[ "$FIREWALL" == "firewalld" ]]; then
                    firewall-cmd --list-all
                elif [[ "$FIREWALL" == "ufw" ]]; then
                    ufw status verbose
                fi
                next
                ;;
            2)  debug_log " $ipsets_choice. Refresh rules"
                subtitle "refresh rules"
                if [[ "$FIREWALL" == "iptables" ]]; then
                    
                    echo -e "ipset $IPSET_NAME"
                    if iptables -C INPUT -m set --match-set "$IPSET_NAME" src -j DROP 2>/dev/null; then
                        iptables -D INPUT -m set --match-set "$IPSET_NAME" src -j DROP
                    fi
                    iptables -I INPUT -m set --match-set "$IPSET_NAME" src -j DROP
                    echo -e "Done."
                    
                    echo -e "ipset $MANUAL_IPSET_NAME"
                    if iptables -C INPUT -m set --match-set "$MANUAL_IPSET_NAME" src -j DROP 2>/dev/null; then
                        iptables -D INPUT -m set --match-set "$MANUAL_IPSET_NAME" src -j DROP
                    fi
                    iptables -I INPUT -m set --match-set "$MANUAL_IPSET_NAME" src -j DROP
                    echo -e "Done."
                    
                elif [[ "$FIREWALL" == "firewalld" ]]; then
                    echo -e "${VLT}Deleting old rules..."
                    iptables -D INPUT -m set --match-set "$IPSET_NAME" src -j DROP 2>/dev/null
                    if [[ "$FIREWALLD" = "true" ]]; then
                        firewall-cmd --permanent --delete-ipset="$IPSET_NAME"
                        firewall-cmd --permanent --direct --remove-rule ipv4 filter INPUT 0 -m set --match-set "$IPSET_NAME" src -j DROP
                    fi
                    echo -e "${VLT}Restoring to $FIREWALL..."
                    if [[ "$FIREWALLD" = "true" ]]; then
                        firewall-cmd --permanent --new-ipset="$IPSET_NAME" --type=hash:net
                        firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -m set --match-set "$IPSET_NAME" src -j DROP
                    else
                        iptables -I INPUT -m set --match-set "$IPSET_NAME" src -j DROP
                    fi
                    echo -e "${SLM}Refreshing default manual user rules ${BG}($MANUAL_IPSET_NAME)${NC}"
                    echo -e "${SLM}Deleting old VIPB rules..."
                        iptables -D INPUT -m set --match-set "$MANUAL_IPSET_NAME" src -j DROP 2>/dev/null
                        firewall-cmd --permanent --delete-ipset="$MANUAL_IPSET_NAME"
                        firewall-cmd --permanent --direct --remove-rule ipv4 filter INPUT 0 -m set --match-set "$MANUAL_IPSET_NAME" src -j DROP
                    echo -e "${SLM}Restoring to $FIREWALL..."
                    if [[ "$FIREWALLD" = "true" ]]; then
                        firewall-cmd --permanent --new-ipset="$MANUAL_IPSET_NAME" --type=hash:net
                        firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -m set --match-set "$MANUAL_IPSET_NAME" src -j DROP
                    else
                        iptables -I INPUT -m set --match-set "$MANUAL_IPSET_NAME" src -j DROP
                    fi
                    echo -e "${GRN}$FIREWALL refreshed.${NC}"
                    echo

                    reload_firewall

                    echo
                    echo "Firewall rules refreshed."
                elif [[ "$FIREWALL" == "ufw" ]]; then
                    echo "2do"
                fi
                back
                ;;
            3)  debug_log " $ipsets_choice. Change firewall"
                echo
                fw_options=()

                if [ "$IPTABLES" == "true" ]; then
                    fw_options+=("iptables (default)")
                fi
                if [ "$FIREWALLD" == "true" ]; then 
                    fw_options+=("FirewallD")
                fi
                if [ "$UFW" == "true" ]; then
                    fw_options+=("ufw") #not supported yet
                fi
                
                select_opt "${NC}${DM}<< Back${NC}" "${fw_options[@]}"
                fw_options=$?
                case $fw_options in
                    0)  debug_log " $fw_options. < Back to Menu"
                        back
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
                echo -e "Firewall changed to ${ORG}$FIREWALL${NC}."
                next
                ;;
            4)  debug_log " $ipsets_choice. View/Clear" 
                echo "Select with [space] the ipsets to clear, then press [enter] to continue."
                echo

                select_ipsets=($(ipset list -n))
                ipset_counts=()
                ipset_display=()

                for ipset in "${select_ipsets[@]}"; do
                    count=$(ipset save $ipset | grep -c "add $ipset")
                    ipset_counts+=("$count")
                    ipset_display+=("$ipset \t\t($count)")
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

                if [[ ${#selected_ipsets[@]} -eq 0 ]]; then
                    echo -e "${RED}No ipsets selected.${NC}"
                else
                    echo -e "Clearing selected ipsets..."
                    for ipset_name in "${selected_ipsets[@]}"; do
                        echo -ne "Clearing ipset ${BLU}$ipset_name${NC}... "
                        ipset flush "$ipset_name"
                        echo -e "${GRN}cleared${NC}"
                    done
                fi
                
                next
                ;;
            5)  debug_log " $ipsets_choice. Re-Create VIPB-ipsets"
                echo "Select with [space] the VIPB-ipsets to recreate, then press [enter] to continue."
                echo -e "This will NOT remove related firewall rules! ${DM}(use option 6 instead)${NC}"
                echo

                select_ipsets=("$IPSET_NAME" "$MANUAL_IPSET_NAME")
                ipset_counts=()
                ipset_display=()

                for ipset in "${select_ipsets[@]}"; do
                    count=$(ipset save $ipset | grep -c "add $ipset")
                    ipset_counts+=("$count")
                    ipset_display+=("$ipset     ($count)")
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

                if [[ ${#selected_ipsets[@]} -eq 0 ]]; then
                    echo -e "${RED}No ipsets selected.${NC}"
                else
                    echo -e "Are you sure?"
                    select_opt "No" "Yes"
                    select_yesno=$?
                    case $select_yesno in
                        0)  echo "Nothing to do."
                            ;;
                        1)  echo "Refreshing selected ipsets..."
                            for ipset_name in "${selected_ipsets[@]}"; do
                                ipset flush $ipset_name
                                ipset destroy $ipset_name #2do check if works properly
                                setup_ipset $ipset_name
                            done
                            echo "Done."
                            ;;
                    esac
                fi
                next
                ;;
            6)  debug_log " $ipsets_choice. Destroy VIPB-ipsets and rules"
                echo -e "Select with [space] the ipsets to ${ORG}destroy${NC}, then press [enter] to continue."
                echo -e "This action will also try to remove related ${ORG}$FIREWALL${NC} rules! ${DM}${BG}use option 5 instead${NC}"
                echo

                select_ipsets=($(ipset list -n | grep vipb))
                ipset_counts=()
                ipset_display=()

                for ipset in "${select_ipsets[@]}"; do
                    count=$(ipset save $ipset | grep -c "add $ipset")
                    ipset_counts+=("$count")
                    ipset_display+=("$ipset     ($count)")
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

                if [[ ${#selected_ipsets[@]} -eq 0 ]]; then
                    echo -e "${RED}No ipsets selected.${NC}"
                else
                    echo    "Are you sure?"
                    select_opt "No" "Yes"
                    select_yesno=$?
                    case $select_yesno in
                        0)  echo "Nothing to do."
                            ;;
                        1)  echo "Deleting selected ipsets..."
                            for selected_ipset in "${selected_ipsets[@]}"; do
                                echo -ne " Deleting ipset ${BLU}$selected_ipset${NC}... "
                                ipset destroy "$ipset_name"
                                echo -e " ipset ${ORG}deleted${NC}"
                                
                                echo " Deleting iptables rule.."
                                iptables -D INPUT -m set --match-set "$selected_ipset" src -j DROP
                                echo -e " iptables rule ${ORG}deleted${NC}"

                                echo " Deleting firewalld rules.."
                                if [[ "$FIREWALL" == "iptables" ]]; then
                                    iptables -D INPUT -m set --match-set "$selected_ipset" src -j DROP
                                elif [[ "$FIREWALL" == "ufw" ]]; then
                                   echo "2do"
                                    #ufw delete deny from any to any 2do
                                elif [[ "$FIREWALL" == "firewalld" ]]; then
                                    firewall-cmd --permanent --delete-ipset="$selected_ipset"
                                    firewall-cmd --permanent --direct --remove-rule ipv4 filter INPUT 0 -m set --match-set "$selected_ipset" src -j DROP
                                    #firewall-cmd --permanent --zone=public --remove-source=ipset:"$ipset_name" 2do check fw rules in zones ????????
                                fi
                                echo -e " $FIREWALL remove rules commands ${ORG}parsed${NC}"
                                echo "${ORG}$FIREWALL${NC} rules for ${BG}$selected_ipset${NC} deleted."
                            done
                            reload_firewall 
                            echo "Done."
                            ;;
                    esac
                fi
                next
                ;;
            0)  debug_log " $ipsets_choice. << Back to Menu"
                back
                ;;
        esac
    done
    next
}

# cron jobs (Menu 7)
function handle_cron_jobs() {
    debug_log "7. Daily Cron Jobs"
    echo -ne "${SLM}"
    subtitle "Daily Cron Jobs"        
    
    if [ "$CRON" == "false" ]; then
        echo -e "${RED}Error: Cannot read crontab${NC}"
    else
        if [[ "$DAILYCRON" == "true" ]]; then
            echo -e "↺  VIPB autoban job ${GRN}found${NC}" #2do add time details
        else
            echo -e "↺  VIPB autoban job ${RED}not found${NC}"
        fi

        if [ "$CRONDL" == "true" ]; then
            blacklist_lvs=()
            echo -ne "${NC}▼ VIPB download job${GRN}"
            for blacklist_lv_check in {2..8}; do
                blacklist_url_check="$BASECRJ${blacklist_lv_check}.txt"
                if crontab -l | grep -q "$blacklist_url_check"; then
                    echo -ne " lv. $blacklist_lv_check${RED}"
                fi
            done
            echo
        else
            echo -e "${NC}▼ VIPB download job ${RED}not found${NC}"
        fi
    
        #echo -ne "${NC}≡  IPsum list       "
        #check_blacklist_file "$BLACKLIST_FILE" "infos"
        echo

        existing_cronjobs=$(crontab -l 2>/dev/null | grep -E "vipb")
        if [ -n "$existing_cronjobs" ]; then
            echo -e "${SLM}VIPB-Cron Jobs${NC}"
            echo -e "${S16}$existing_cronjobs${NC}"
        else
            echo -e "${ORG} No active VIPB-Cron Jobs found.${NC}"
        fi
        
        echo
    fi
    
    echo
    cron_options=("${VLT}Change IPsum ▼ download list level [ $BLACKLIST_LV ] ${NC}")
    if [[ $CRON == "true" ]]; then
        if [[ "$CRONDL" == "true" ]]; then
            cron_options+=("Remove ▼ VIPB download job")
        else
            cron_options+=("Add ▼ VIPB download job")
        fi
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
        2)  if [[ "$CRONDL" == "true" ]]; then
            # echo "Add/Remove VIPB daily download cron job"
                for blacklist_lv_check in {2..8}; do
                    blacklist_url_check="$BASECRJ${blacklist_lv_check}.txt"
                    if crontab -l | grep -q "$blacklist_url_check"; then
                        crontab -l | grep -v "$blacklist_url_check" | crontab -
                        echo -ne "Cron Job ${ORG}▼ lv $blacklist_lv_check removed"
                        CRONDL=false
                    fi
                done
            else
                echo "Adding new Download Cron Job ${GRN}▼ lv $BLACKLIST_LV ${NC}"
                cronurl="https://raw.githubusercontent.com/stamparm/ipsum/master/levels/${BLACKLIST_LV}.txt"
                (crontab -l 2>/dev/null; echo "0 4 * * * curl -o $BLACKLIST_FILE $cronurl") | crontab -
                echo -e "Cron Job ${GRN}added${NC} for daily ${BG}IPsum${NC} blacklist download.  @ 4.00 AM server time"
                CRONDL=true
            fi
            next
            ;;
        3)  if [[ "$DAILYCRON" == "true" ]]; then
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
}

# Geo IP lookup (Menu 8)
function handle_geo_ip_info() {
    debug_log "8. GeoIP lookup"
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
}

# logs and info (Menu 9)
function handle_logs_info() {
    debug_log "9. Logs & infos"
    header
    echo -ne "${ORG}"
    subtitle "Logs & infos"
    echo
    echo -e "${VLT}VIPB variables"    
    echo -e "${VLT}VER: ${NC}$VER, ${VLT}CLI: ${NC}$CLI, ${VLT}DEBUG: ${NC}$DEBUG"
    echo -e "${CYN}IPSET_NAME: ${NC}$IPSET_NAME, ${VLT}MANUAL_IPSET_NAME: ${NC}$MANUAL_IPSET_NAME, ${VLT}SCRIPT_DIR: ${NC}$SCRIPT_DIR"
    echo -e "${SLM}CRON: ${NC}$CRON, ${SLM}DAILYCRON: ${NC}$DAILYCRON, ${SLM}CRONDL: ${NC}$CRONDL, ${SLM}LOG_FILE: ${NC}$LOG_FILE"
    echo -e "${ORG}IPSET: ${NC}$IPSET, ${ORG}FIREWALL: ${NC}$FIREWALL, ${ORG}IPTABLES: ${NC}$IPTABLES, ${ORG}FIREWALLD: ${NC}$FIREWALLD, ${ORG}UFW: ${NC}$UFW, ${ORG}PERSISTENT: ${NC}$PERSISTENT"

    log_selector(){
        echo
        echo -e "${ORG}■■■ LOG VIEWER ■■■${NC}"
        echo "Select log:"
        
        log_options=("auth.log" "usermin" "webmin" "syslog" "journalctl" "VIPB" "Reset VIPB log")
        if [[ $FAIL2BAN == "true" ]]; then
            log_options+=("Fail2Ban" "Fail2Ban [WARNINGS]")
        fi
        
        select_opt "${NC}${DM}<< Back${NC}" "${log_options[@]}"
        select_log=$?
        loglen=20
        case $select_log in
            0)  back
                ;;
            1)  echo -e "${CYN}▗ auth.log${NC}"
                tail -n $loglen /var/log/auth.log | grep -v "occ background-job:worker"
                ;;
            2)  echo -e "${S24}▗ usermin${NC}"
                tail -n $loglen /var/usermin/miniserv.error
                ;;
            3)  echo -e "${BLU}▗ webmin${NC}"
                tail -n $loglen /var/webmin/miniserv.error
                ;;
            4)  echo -e "${S16}▗ syslog${NC}"
                tail -n $loglen /var/log/syslog
                ;;
            5)  echo -e "${S16}▗ ${BG}journalctl -n $loglen${NC}"
                journalctl -n "$loglen"
                ;;
            6)  echo -e "${VLT}▗ VIPB${NC}"
                tail -n $loglen $SCRIPT_DIR/vipb-log.log
                ;;
            7)  echo -e "${VLT}▗ VIPB${NC}"
                check_blacklist_file "$LOG_FILE" infos
                echo
                > "$SCRIPT_DIR/vipb-log.log"
                echo -e "VIPB-log ${ORG}cleared${NC}"
                ;;
            8)  echo -e "${SLM}▗ Fail2ban${NC}"
                tail -n $loglen /var/log/fail2ban.log
                ;;
            9)  echo -e "${SLM}▗ Fail2Ban [WARNING]${NC}"
                tail -n 1000 /var/log/fail2ban.log | grep "WARNING"
                ;;
        esac
        echo
        log_selector
    }
    log_selector
    echo -e "\e[0m"
    next
}

# DOWNLOAD & BAN (Menu NONE!!) 2do?
function handle_download_and_ban() {
    debug_log "* DOWNLOAD & BAN!"
    subtitle "DOWNLOAD & BAN!"
    if [[ $IPSET == "false" ]]; then
        echo -e "${RED}No option available."
    else
        echo
        download_blacklist
        check_blacklist_file $BLACKLIST_FILE
        echo
        setup_ipset $IPSET_NAME
        INFOS="false"
        ban_core $BLACKLIST_FILE
        add_firewall_rules
        reload_firewall
    fi
    next
}

# Main UI

# Nice header :)
function header () {
    if [ "$DEBUG" == "true" ]; then
        echo
        echo -e "▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤ ${YLW}DEBUG MODE ON${NC} ▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤"
        echo
    else
       clear
    fi
    if [ "$IPSET" == "true" ]; then
        ipset_bans=$(count_ipset "$IPSET_NAME")
        manual_ipset_bans=$(count_ipset "$MANUAL_IPSET_NAME")
    fi
    echo -ne "${NC}${RED}${DM}"
    echo -e "▁ ▂ ▃ ▅ ▆ ▇ ▉ ▇ ▆ ▅ ▃ ▂ ${NC}${VLT}${BD}Versatile IPs Blacklister${NC} ${DM}${VER}${RED} ▁ ▂ ▃ ▅ ▆ ▇ ▉ ▇ ▆ ▅ ▃ ▂${NC}"
    echo -e "                                   ${DM}    •                  ${NC}"     
    echo -e "  ██╗   ██╗██╗██████╗ ██████╗      ${DM}   ┏┓┏┳┓┏┓┏┓┏┓┓┏┏┓┏┏┓┏┓${NC}"
    echo -e "  ██║   ██║██║██╔══██╗██╔══██╗     ${DM}by ┛┗┛┗┗┗┛┛┗┗┫┗┻┗┻┛┗┻┛ ${NC}"
    echo -e "  ██║   ██║██║██████╔╝██████╔╝     ${DM}             ┗         ${NC}"
    echo -ne "  ╚██╗ ██╔╝██║██╔═══╝ ██╔══██╗    "
    if [ "$IPSET" == "true" ]; then
        echo -ne "✦ ${VLT}VIPB bans:${BD} $ipset_bans ${NC}"
    fi
    echo
    echo -ne "   ╚████╔╝ ██║██║     ██████╔╝    "
    if [ "$IPSET" == "true" ]; then
        echo -ne "✦ ${YLW}USER bans: ${BD}$manual_ipset_bans${NC}"
    fi
    echo
    echo -e "    ╚═══╝  ╚═╝╚═╝     ╚═════╝      "
    
    function services_row() {  
        echo -ne " ${NC}"
        if [ "$FIREWALL" == "iptables" ]; then
            echo -ne "${GRN}[ ✓"
         else
            echo -ne "${DM}"
        fi 

            if [ "$IPTABLES" == "false" ]; then
                echo -ne " ${DM}"
            fi
            echo -ne " iptables"

            if [ "$PERSISTENT" == "true" ]; then
                echo -ne "-persistent"
            fi
            
            if [ "$IPSET" == "true" ]; then
                echo -ne " ✚"
            else
                echo -ne "${RED} ✗"
            fi
            echo -ne " ipset"

        if [ "$FIREWALL" == "iptables" ]; then
            echo -ne "${GRN} ]${NC}"
        fi 

        echo -ne " "
        
        if [ "$FIREWALL" == "ufw" ]; then
            echo -ne "${GRN}[ ✓ "
         else
            echo -ne "${DM}"
        fi 

            if [ "$UFW" == "false" ]; then
                echo -ne "${DM}"
            fi 
            echo -ne "ufw ${NC}"

        if [ "$FIREWALL" == "ufw" ]; then
            echo -ne "${GRN} ] ${NC}"
        fi

        if [ "$FIREWALL" == "firewalld" ]; then
            echo -ne "${GRN}[ ✓ "
        else
            echo -ne "${DM}"
        fi 
            if [ "$FIREWALLD" == "true" ]; then 
                echo -ne "${GRN}"
            else
                echo -ne "${DM}"
            fi
            echo -ne "firewalld ${NC}"
        if [ "$FIREWALL" == "firewalld" ]; then
            echo -ne "${GRN}] ${NC}"
        fi

        echo -ne "${DM}•${NC} "
        
        if [ "$FAIL2BAN" == "true" ]; then
            echo -ne "${GRN}"
        else
            echo -ne "${NC}${DM}"
        fi
        echo -ne "${BG}fail2ban ${NC}"
        
        echo -ne "${DM}•${NC} "

        if [ "$CRON" == "true" ]; then
            echo -ne "${GRN}"
        else
            echo -ne "${DM}"
        fi
        echo -ne "${BG}cron ${NC}"

        if [ "$CRON" == "true" ]; then
            if crontab -l | grep -q "vipb.sh"; then
                echo -ne "${GRN}↺ "
                DAILYCRON=true
            else
                echo -ne "${RED}✗ "
                DAILYCRON=false
            fi
            CRONDL=false
            blacklist_lvs=()
            echo -ne "${GRN}" # first job will be ok, more than 1 not
            for blacklist_lv_check in {2..8}; do
                blacklist_url_check="$BASECRJ${blacklist_lv_check}.txt"
                if crontab -l | grep -q "$blacklist_url_check"; then
                    echo -ne " ▼ $blacklist_lv_check${RED}"
                    blacklist_lvs+=("$blacklist_lv_check")
                    CRONDL=true
                fi
            done
            
            if [ "$CRONDL" == "false" ]; then
                echo -ne "${RED}✗"
            fi
        fi
        echo -e "${NC}"

    }
    services_row
}

# Main menu
function menu_main() {
    echo -e "${NC}"
    echo -e "\t${DM}✦ FILES BLACKLISTS${NC}"
    echo -e "\t1${VLT}. Download${NC} ${BG}IPsum${NC} blacklist"
    echo -e "\t2${CYN}.${NC} ${CYN}Aggregate${NC} IPs into subnets"
    echo -e "\t3${BLU}.${NC} View/Clear ${BLU}Blacklists${NC}"
    echo -e "\n\t${DM}✦ BAN IPS${NC}"
    echo -e "\t4${VLT}. Ban ${NC}from Blacklists"
    echo -e "\t5${YLW}. Manual ban ${NC}IPs"
    if [[ $IPSET == "false" ]]; then
        echo -ne "${DM}"
    fi
    echo -e "\t6. Manage ${ORG}firewall${NC} & sets ${RED}(2do!)${NC}"
    echo -e "\n\t${DM}✦ TOOLS${NC}"
    if [[ $CRON == "false" ]]; then
        echo -ne "${DM}"
    fi
    echo -e "\t7${SLM}.${NC} Daily ${SLM}Cron${NC} Jobs"
    echo -e "\t8${S24}. Geo IP${NC} lookup"
    echo -e "\t9${ORG}. Logs ${NC}& Vars"
    echo
    echo -e "\t0. Exit"
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
            3) handle_blacklist_files ;;
            4) handle_blacklist_ban ;;
            5) handle_manual_ban ;;
            6) handle_firewalls ;;
            7) handle_cron_jobs ;;
            8) handle_geo_ip_info ;;
            9) handle_logs_info ;;
            Y) handle_download_and_ban; break ;;
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

# Menu selector functions
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