#!/bin/bash

# VIPB User Interface

# Check if the script is running from CLI
if [ "$CLI" == "true" ]; then
    log "*** VIPB ${VER} *** CLI interface not supported."
    if [ "$DEBUG" == "true" ]; then
        echo ">> but we are developers..."
    else
        exit 1
    fi
else
    log "*** VIPB ${VER} *** Hello Human! loading UI interface..."
    echo -ne "*** VIPB ${VER} *** Hello Human! loading UI interface"
    
    #here add a check if it is a 256 colors terminal, otherwise set to 8 colors
    
    # Check if terminal supports 256 colors
    if tput colors | grep -q '256' && ! [ "$DEBUG" == "true" ]; then
        # UI then define COLORS!
        SLM='\033[38:5:209m' # SALMON
        VLT='\033[38;5;183m'
        BLU='\033[38;5;12m'
        CYN='\033[38;5;50m'
        S24='\033[38;5;195m' # AZURE
        S16='\033[38;5;194m' # LIGHTGREEN
        GRN='\033[38;5;192m'
        YLW='\033[38;5;11m'
        ORG='\033[38;5;215m'
        RED='\033[31m'
        GRY='\033[38;5;7m' # GREY
    else
        # Fallback to 8 colors
        # deactivate multimenu
        S24='\033[34m' # BLUE
        BLU='\033[34m'
        CYN='\033[36m' # CYAN
        S16='\033[32m' # GREEN
        GRN='\033[32m'
        YLW='\033[33m' # YELLOW
        ORG='\033[33m'
        SLM='\033[35m' # MAGENTA
        VLT='\033[35m'
        RED='\033[31m' # RED
        GRY='\033[37m' # WHITE???
    fi
    NC='\033[0m' # No Color (reset)
    BD='\033[1m' # bold
    DM='\033[2m' # dim color #2do check if/when used
    BG='\033[3m' # italic / BG white #2do check if/when used
    
    # 2do: remove across the script
    BL='\033[5m' # blink
    BR='\033[25m' # reset blink
    TB='\033[33m' # text blink????? see YLW & ORG

    NB='\033[49m' # No BG #2do check if/when used

    echo -e " and... ${RED}c${VLT}o${ORG}l${YLW}o${S16}r${CYN}s${BLU}!${NC}"
fi

#  UI-CORE functions

function back {
    header
    dashboard
    menu_main
}

function next() {
    echo -e "${NC}"
    echo -ne "${YLW}press enter"
    read -p "_ " p
    echo -e "${NC}"
    
    back
}

function vquit {
    echo -e "${NC}"
    title "ViPB end."
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

#  UI-OPT functions

function title {
    if command -v figlet >/dev/null 2>&1 && [ "$DEBUG" == "false" ]; then
        figlet -cf "$SCRIPT_DIR/tmplr.flf" "$@"
        echo -e "\t\t\t\t${VLT}≡▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔≡${NC}"
    else
        echo
        center "▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤ ${BD}$@${NC} ▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤"
    fi
    echo
}

function subtitle {
    if command -v figlet >/dev/null 2>&1 && [ "$DEBUG" == "false" ]; then
        figlet -f "$SCRIPT_DIR/tmplr.flf" "$@"
    else
        echo
        echo "-=≡≡ $@ "
    fi
    echo
}

function get_figlet() { #2do combine the font in the ui file
    figlet -f "$SCRIPT_DIR/pagga.flf" "$1"
}

function big() {
    local n1=$1
    local n2=$2
    local spacing=${3:-8}
    if command -v figlet >/dev/null 2>&1; then

        mapfile -t lines1 < <(get_figlet "$n1")
        mapfile -t lines2 < <(get_figlet "$n2")
        
        local max_lines=$(( ${#lines1[@]} > ${#lines2[@]} ? ${#lines1[@]} : ${#lines2[@]} ))
        
        for (( i=0; i<max_lines; i++ )); do
            local line1="${lines1[$i]:-}"
            local line2="${lines2[$i]:-}"
            
            printf "%s%*s%s\n" "                    ${line1%"${line1##*[![:space:]]}"}" "$spacing" "" "$line2"
        done
    else
         center "◢  $1  ✦  $2  ◣" 80
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
    log "* Download IPsum Blacklist" 
    header
    echo -ne "${S16}"
    title "download list"
    echo -e "${VLT}Current Blacklist: "
    check_blacklist_file $BLACKLIST_FILE infos
    echo -e "\n"
    echo -e "${GRY}${BG}IPsum${NC}${GRY} is a feed based on 30+ publicly available lists of suspicious and/or malicious IP addresses. The provided list is made of IP addresses matched with a number of (black)lists occurrences. "
    echo -e "${S16}for more infos see IPsum's URL ${BG}https://github.com/stamparm/ipsum/${NC}"
    echo
    echo -e "${YLW}Select ${BG}IPsum${NC} ${YLW}Blacklist level, where ${BD}level # => IPs appears on at least # blacklists:${NC} ${BG}${ORG}2 more strict (caution big list!) <--> less strict 8${NC}"
    echo -e "${YLW}"
	read -p "[LV 2-8|0]: " select_lv
	echo -e "${NC}"
    case $select_lv in
        0)  back ;;
        [2-8]) 
            download_blacklist $select_lv
            next
            ;;
    esac
}

# blacklist compression (Menu 2) aggregator & files
function handle_blacklist_files() {
    debug_log "* Blacklists Files & aggregator"
    header
    echo -ne "${CYN}"
    title "aggregator"
    echo
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
	echo
    echo -e "1. ${CYN}Start IPsum to Subnets Aggregation${NC}" 
    echo -e "2. ${ORG}Delete current blacklists files"
    echo -e "${YLW}"
    read -p "[1-2|0]: " select_blackl
	echo -e "${NC}"
    #select_blackl=$(select_opt "${NC}${DM}<< Back${NC}" "${CYN}Start IPsum to Subnets Aggregation${NC}" "Delete current blacklists files")
    loglen=25
    case $select_blackl in
        0)  debug_log "** $select_blackl. < Back to Menu"
            back
            ;;
        1)  debug_log "** $select_blackl. Aggregate Blacklist into Subnets"
            header
            title "compressor"
            compressor
            next
            ;;
        2)  debug_log "** $select_blackl. View / Clear blacklist files"
            subtitle "delete lists" 
            echo "Select with [space] the Blacklists to clear, then press [enter] to continue."
            echo

            select_lists=("IPsum Blacklist (Single IPs)" "Optimized Blacklist (IPs & Subnets)" "/24 subnets (#.#.#.255)" "/16 subnets (#.#.255.255)" )

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

# blacklist banning (Menu 3) ban_core & ipsets 
function handle_blacklist_ban() {
    debug_log "* Blacklists Ban (ipsets)"
    header
    title "lists ban"
    echo
    if [[ $IPSET == "false" ]]; then
        echo -e "${RED}ipset not found. No option available."
    else
        check_ipset $IPSET_NAME
        check_ipset $MANUAL_IPSET_NAME
        INFOS="false"
        echo
        echo -e "All ready. What do you want to do?" 
        echo
        echo -e "1. Ban ${VLT}original blacklist${NC} (${VLT}$(wc -l < "$BLACKLIST_FILE") IPs${NC})"
        echo -e "2. Ban ${CYN}all optimized${NC} (${CYN}$(wc -l < "$OPTIMIZED_FILE") sources${NC})"
        echo -e "3. Ban ${S24}/24 subnets${NC} (#.#.#.\e[37m0${NC}) (${S24}$(wc -l < "$SUBNETS24_FILE") networks${NC})"
        echo -e "4. Ban ${S16}/16 subnets${NC} (#.#.\e[37m0.0${NC}) (${S16}$(wc -l < "$SUBNETS16_FILE") networks${NC})${ORG}!${NC}"
        echo -e "5. Ban ${BLU}from ${BG}*.ipb${NC} files${NC}"
        echo -e "6. View/Clear active ipsets"
        echo -e "7. Re-create VIPB-sets ${ORG}!${NC}"
        echo -e "8. Destroy sets ${ORG}!${NC}"
        echo
        echo "0. <<" 
        echo -e "\e[0m"
        echo
        while true; do
            read -p "_ " ipsets_choice
            echo -e "${NC}"
            case $ipsets_choice in
                1)  debug_log "** $ipsets_choice. BLACKLIST_FILE"
                    echo -e "${VLT}Ban original blacklist${NC}" 
                    ban_core "$BLACKLIST_FILE"
                    next
                    break
                    ;;    
                2)  debug_log "** $ipsets_choice. OPTIMIZED_FILE"
                    echo -e "${CYN}Ban all optimized${NC}"
                    ban_core "$OPTIMIZED_FILE"
                    next
                    break
                    ;;
                3)  debug_log "** $ipsets_choice. SUBNETS24_FILE"
                    echo -e "${S24}Ban /24 subnets${NC} (#.#.#.\e[37m0${NC})"
                    ban_core "$SUBNETS24_FILE"
                    next
                    break
                    ;;
                4)  debug_log "** $ipsets_choice. SUBNETS16_FILE"
                    echo -e "${S16}Ban /16 subnets${NC} (#.#.\e[37m0.0${NC})"
                    INFOS="true"
                    ban_core "$SUBNETS16_FILE"
                    next
                    break
                    ;;
                5)  debug_log "** $ipsets_choice. IPB_FILE"
                    echo -e "${VLT}Import *.ipb list"
                    echo
                    echo -e "Looking for ${BG}.ipb${NC} files in ${BG}$SCRIPT_DIR${NC} ..."
                    ipb_files=()
                    selected_ipbf=()
                    # Cerca file *.ipb nella directory dello script
                    while IFS= read -r -d '' file; do
                        ipb_files+=("$file")
                    done < <(find "$SCRIPT_DIR" -maxdepth 1 -name '*.ipb' -print0)

                    echo "Select with [space] the lists to import and ban, then press [enter] to continue."
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
                        echo -e "Loading selected files into ${VLT}$IPSET_NAME${NC} ..."
                    for ipb_file in "${selected_ipbf[@]}"; do
                            echo -e "Banning from list ${BLU}$ipb_file${NC}... "
                            INFOS="true"
                            ban_core "$ipb_file"
                            echo -e "${GRN}OK${NC}"
                        done
                    fi
                    next
                    break
                    ;;
                6)  debug_log "** $ipsets_choice. View/Clear" 
                    subtitle "clear ipsets" 
                    echo "Select with [space] the ipsets to clear, then press [enter] to continue."
                    echo

                    #select_ipsets=($(ipset list -n | grep vipb))
                    select_ipsets=($(ipset list -n))
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
                        echo -e "Clearing selected ipsets..."
                        for ipset_name in "${selected_ipsets[@]}"; do
                            echo -ne "Clearing ipset ${BLU}$ipset_name${NC}... "
                            ipset flush "$ipset_name"
                            echo -e "${GRN}cleared${NC}"
                        done
                    fi
                    
                    next
                    ;;
                7)  debug_log "** $ipsets_choice. Destroy"
                    subtitle "destroy ipsets" 
                    echo "Select with [space] the ipsets to destroy, then press [enter] to continue."
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
                        echo    "Are you sure?"
                        case `select_opt "No" "Yes"` in
                            0)  echo "Nothing to do."
                                ;;
                            1)  echo "Refreshing selected ipsets..."
                                for ipset_name in "${selected_ipsets[@]}"; do
                                    ipset flush $ipset_name
                                    ipset destroy $ipset_name #2do with checks
                                    setup_ipset $ipset_name
                                done
                                echo "Done."
                                ;;
                        esac
                    fi
                    next
                    ;;
                8)  debug_log "** $ipsets_choice. Destroy"
                    subtitle "destroy ipsets" 
                    echo "Select with [space] the ipsets to destroy, then press [enter] to continue."
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
                        echo -e "${YLW}This action will also remove related firewall rules!"
                        echo    "Are you sure?"
                        case `select_opt "No" "Yes"` in
                            0)  echo "Nothing to do."
                                ;;
                            1)  echo "Deleting selected ipsets..." #2do rewrite with new vars/handlers
                                for ipset_name in "${selected_ipsets[@]}"; do
                                    echo -ne " Deleting ipset ${BLU}$ipset_name${NC}... "
                                    ipset destroy "$ipset_name"
                                    echo -e " ipset ${ORG}deleted${NC}"
                                    
                                    echo " Deleting iptables rule.."
                                    iptables -D INPUT -m set --match-set "$ipset_name" src -j DROP
                                    echo -e " iptables rule ${ORG}deleted${NC}"

                                    echo " Deleting firewalld rules.."
                                    #firewall-cmd --permanent --zone=public --remove-source=ipset:"$ipset_name" 2do check fw rules in zones ????????
                                    firewall-cmd --permanent --delete-ipset="$IPSET_NAME"
                                    firewall-cmd --permanent --direct --remove-rule ipv4 filter INPUT 0 -m set --match-set "$IPSET_NAME" src -j DROP
                                    echo -e " firewalld remove rules commands ${ORG}parsed${NC}"
                                    echo "Firewall rules for ipset deleted."
                                done
                                reload_firewall #2do check 
                                echo "Done."
                                ;;
                        esac
                    fi
                    next
                    ;;
                0)  debug_log "** $ipsets_choice. < Back to Menu"
                    back
                    ;;
            esac
        done
    fi
    next
}

# manual banning (Menu 4)
function handle_manual_ban() {
    debug_log "* Manual/User Ban"
    header
    title "manual ban"
    echo

    echo -e "${VLT}Last banned IPs:${NC}"
    ipset list $MANUAL_IPSET_NAME | grep -E '^[0-9]+\.' | tail -n 10
    echo

    manual_options=()
    if [[ "$FIREWALL" == "iptables" ]] || [[ "$FIREWALL" == "firewalld" ]]; then
        #manual_options+=("${YLW}Ban single IPs${NC}")
        echo -e "1. ${YLW}Ban IPs${NC}"
    fi
    if [[ "$IPSET" == "true" ]]; then
        #manual_options+=("View / Unban user Blacklist" "Export to file ($MANUAL_IPSET_NAME.ipb)")
        echo -e "2. ${ORG}View / Unban List${NC}"
        echo -e "3. ${BLU}Export to file ${BG}$MANUAL_IPSET_NAME.ipb${NC}"
    fi
    #manual_choice=$(select_opt "${NC}${DM}<< Back${NC}" "${manual_options[@]}")
    echo -e "${NC}${DM}0. << Back${NC}"
    echo -e "${YLW}"
    read -p "_ " manual_choice
    echo -e "${NC}"
    case $manual_choice in
        0)  debug_log "** $manual_choice. < Back to Menu"
            back
            ;;
        1)  debug_log "** $manual_choice. Manual Ban"
            subtitle "ban ips"   
            ask_IPS
            echo
            if [[ ${#IPS[@]} -eq 0 ]]; then
                echo -e "${ORG}No IP entered.${NC}"
            else
                if [[ "$IPSET" == "true" ]]; then
                    setup_ipset "$MANUAL_IPSET_NAME"
                fi
                echo "$IPSET"
                echo
                INFOS="true"
                add_ips "$MANUAL_IPSET_NAME" "${IPS[@]}"
                echo -e "${GRN}$ADDED_IPS IPs added ${NC}($ALREADYBAN_IPS already banned)."
                count_ipset "$MANUAL_IPSET_NAME"
                echo -e " total IPs banned in set ${BG}${MANUAL_IPSET_NAME}${NC}."
                echo
                if [[ $ADDED_IPS -gt 0 ]]; then
                    echo -e "${YLW}Do you want to reload the firewall rules?${NC}"
                    case `select_opt "No" "Yes"` in
                        0)  echo "Nothing to do."
                            ;;
                        1)  echo "Reloading firewall rules..."
                            reload_firewall
                            ;;
                    esac
                fi
            fi
            next
            ;;
        2)  debug_log "** $manual_choice. View / Unban"
            subtitle "view/unban"
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
        3)  debug_log "** $manual_choice. Export to file"
            subtitle "Export"
            ipset save "$MANUAL_IPSET_NAME" > "$SCRIPT_DIR/$MANUAL_IPSET_NAME.ipb"
            #iptables-save > "$SCRIPT_DIR/vipb-export.ipb" check persistent
            echo "Saved to ${BG}$SCRIPT_DIR/$MANUAL_IPSET_NAME.ipb${NC}"
            ;;
    esac
}

# cron jobs (Menu 5)
function handle_cron_jobs() {
    debug_log "* Cron Jobs"
    header
    title "daily jobs"        
    if ! crontab -l >/dev/null 2>&1; then
        echo -e "  ${RED}Error: Cannot read crontab${NC}"
    else
    
        if crontab -l | grep -q "vipb.sh"; then
            echo -e " ${GRN}${BL}◉${BR} VIPB daily job found${NC}"
        else
            echo -e "  ${RED}VIPB daily job not found${NC}"
        fi

        for blacklist_lv_check in {1..8}; do
            blacklist_url_check="$BASECRJ${blacklist_lv_check}.txt"
            if crontab -l | grep -q "$blacklist_url_check"; then
                echo -e " ${GRN}${BL}▼${BR} Daily IPsum download @ ${VLT}LV $blacklist_lv_check${NC}"
            fi
        done
    
    fi
    echo -ne "${VLT} IPsum list  "
    check_blacklist_file "$BLACKLIST_FILE"
    echo -e "\n"
    function check_cronjobs(){
        if ! command -v cron &> /dev/null && ! command -v crond &> /dev/null; then
            CRON=false
            echo -e "${ORG} cron/crond not found.${NC}"
        else
            existing_cronjobs=$(crontab -l 2>/dev/null | grep -E "vipb")
            if [ -n "$existing_cronjobs" ]; then
                echo -e "${GRN}${BG} VIPB-Cron Jobs${NC}${GRN}. ${NC}"
                echo -e "${S16}$existing_cronjobs${NC}"
            else
                echo -e "${ORG} No active VIPB-Cron Jobs found.${NC}"
            fi
        fi
    }
    check_cronjobs

    echo
    echo
    cron_options=("${VLT}Change IPsum list level [ $BLACKLIST_LV ] ${NC}")
    if [[ $CRON == "true" ]]; then
        cron_options+=("Add Daily Download Job" "Add VIPB Autoban Job" "Remove Cron Jobs")
    fi
    cron_select=$(select_opt "${NC}${DM}<< Back${NC}" "${cron_options[@]}")
    case $cron_select in
        0)  back
            ;;
        1)  subtitle "fire level"
            # "Change default IPsum list level"
            select_lv=$(($(select_opt "${NC}${DM}<< Back${NC}" "${RED}  2  caution! big list${NC}" "${YLW}  3  ${NC}" "${GRN}  4  ${NC}" "${S16}  5  ${NC}" "${YLW}  6  ${NC}" "${ORG}  7  ${NC}"  "${ORG}  8  ${NC}") + 1))
            case $select_lv in
                1)  back
                    ;;
                [2-8]) 
                    set_blacklist_level $select_lv #2do
                    next
                    ;;
            esac
            next
            ;;
        2)  # echo "Add new Download Cron Job ( lv. $BLACKLIST_LV )"
            subtitle "add daily dl"
            echo "Adding new Download Cron Job ( lv. $BLACKLIST_LV )"
            #select_crjlv=$(($(select_opt "${RED}\t2\t${NC}" "${ORG}\t3\t${NC}" "${GRN}\t4\t${NC}" "${S16}\t5\t${NC}" "${S16}\t6\t${NC}" "${YLW}\t7\t${NC}" "${NC}${DM}<< Back${NC}") + 2))
            #case $select_crjlv in
                #[2-7]) 
            cronurl="https://raw.githubusercontent.com/stamparm/ipsum/master/levels/${BLACKLIST_LV}.txt"
            (crontab -l 2>/dev/null; echo "0 4 * * * curl -o $BLACKLIST_FILE $cronurl") | crontab -
            echo -e "${GRN}Cron Job added for daily IP blacklist update. ${NC} @ 4.00 AM server time"
            next
            ;;
        3)  # echo "Add VIPB autoban cron job"
            subtitle "ViPB cronjob"
            (crontab -l 2>/dev/null; echo "10 4 * * * $SCRIPT_DIR/vipb.sh") | crontab -
            echo -e "${GRN}Cron Job added for daily VIPB autoban on blacklist. ${NC} @ 4.10 AM server time"
            next
            ;;
        4)  #  "Remove Cron Jobs"
            subtitle "remove cronjobs"

            mapfile -t existing_cronjobs < <(crontab -l 2>/dev/null | grep -E "vipb")
            multiselect result existing_cronjobs false

            selected_cronjobs=()
            idx=0
            for selected in "${existing_cronjobs[@]}"; do
                if [[ "${result[idx]}" == "true" ]]; then
                    selected_cronjobs+=("$selected")
                fi
                ((idx++))
            done

            if [[ ${#selected_cronjobs[@]} -eq 0 ]]; then
                echo -e "${RED}No Cron Job selected.${NC}"
            else
                for cronjob in "${selected_cronjobs[@]}"; do
                    echo -ne "Clearing Cron Job ${BLU}$cronjob${NC}... "
                    echo
                    echo "FUNCTION NOT WRITTEN :("
                    echo
                    echo -e "${GRN}cleared${NC}"
                done
            fi
            next
            ;;        
    esac
}

# firewall rules (Menu X) #maybe remove
function handle_firewall_rules() {
    debug_log "* Firewall Rules"
    header
    title "firewall"
    services_row
    echo
    echo -ne "${YLW}▗ Firewall \t"
    echo -ne "${S16}${FIREWALL}${GRN} in use"
    if $FIREWALLD; then
        echo -e " with permanent rules"
        echo
        echo -e "${ORG}▙ Rules:${NC}"  #2do check loop here
        check_firewall_rules(){
            firewall-cmd --list-all | grep -i vipb
            firewall-cmd --direct --get-all-rules | grep vipb
            #firewall-cmd --list-all --zone=all | grep -i vipb
        }
        check_firewall_rules
    fi
    echo
    echo
    fw_options=()
    if [[ "$FIREWALL" == "iptables" ]]; then
        fw_options+=("View iptables rules" "Refresh rules")
    fi
    fw_choice=$(select_opt "${NC}${DM}<< Back${NC}" "${fw_options[@]}")
    case $fw_choice in
        0)  back;;
        1)  subtitle "iptables rules"
            iptables -L -v -n | head -n 20
            next
            ;;
        2)  subtitle "refresh rules"
            echo -e "${VLT}Refreshing default blacklist rules ${BG}($IPSET_NAME)${NC}"
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
            next
            ;;
    esac
}

# Geo IP lookup (Menu 6)
function handle_geoip_info() {
    debug_log "* GeoIP lookup"
    header
    title "geo ip lookup"
    echo -e 

    geo_options=()
    geo_options+=("${GRN}Lookup IP${NC}")
    geo_choice=$(select_opt "${NC}${DM}<< Back${NC}" "${geo_options[@]}")
    case $geo_choice in
        0)  debug_log "** $geo_choice. < Back to Menu"
            back
            ;;
        1)  debug_log "** $geo_choice. GeoLookup IP"
            subtitle "Geo ip"   
            ask_IPS
            echo
            if [[ ${#IPS[@]} -eq 0 ]]; then
                echo -e "${ORG}No IP entered.${NC}"
            else
                if command -v geoiplookup >/dev/null 2>&1; then
                    echo -e "${GRN}Using ${BG}geoiplookup${NC}${GRN} for IP geolocation${NC}"
                    for ip in "${IPS[@]}"; do
                        echo -e "${S16}Looking up IP: $ip${NC}"
                        geoiplookup "$ip"
                    done
                else
                    echo -ne "${YLW}geoiplookup not found,"
                    
                    if command -v geoiplookup >/dev/null 2>&1; then
                        echo -e "${GRN}using whois instead${NC}"
                        for ip in "${IPS[@]}"; do
                            echo -e "${S16}Looking up IP: $ip${NC}"
                            whois "$ip" | grep -E "Country|city|address|organization|OrgName|NetName" 2>/dev/null
                        done
                    else
                        echo -e "${ORG}whois not found.${NC}"
                        echo -e "${RED}Geo IP not available."
                    fi
                    
                fi
            fi
            next
            ;;
    esac
}

# logs and info (Menu 7)
function handle_logs_info() {
    debug_log "* Logs & infos"
    header
    title "Logs & infos"
    echo -ne "${VLT}▙ Blacklist URL "
    if [ ! "$BLACKLIST_LV" ]; then
        echo -e "▗ ${RED}core error: BLACKLIST_LV not set${NC}\t"
        else
        level_bar "$BLACKLIST_LV"
        echo -e "\t${GRN}lv. $BLACKLIST_LV"
    fi
    if [ ! "$BLACKLIST_URL" ]; then
        echo -e "▗\t${RED}core error: BLACKLIST_URL not set${NC}"
        else
        echo -e "▗ ${GRN}${BG}$BLACKLIST_URL${NC}"
    fi
    echo -e "${VLT}▗ ${BG}by IPsum \thttps://github.com/stamparm/ipsum/${NC}${VLT}"
    echo
    echo -e "${YLW}▙ Blacklist Files${NC}\e[33m"
    echo -ne "${YLW}▗ ${VLT}blacklist \t\t"
    check_blacklist_file "$BLACKLIST_FILE" infos
    echo
    echo -ne "${YLW}▗ ${BLU}optimized ${NC}\t\t"
    check_blacklist_file "$OPTIMIZED_FILE" infos
    echo
    echo -ne "${YLW}▗ ${S24}/24subs${NC} (#.#.#.\e[37m0${NC})\t"
    check_blacklist_file "$SUBNETS24_FILE" infos
    echo
    echo -ne "${YLW}▗ ${S16}/16subs${NC} (#.#.\e[37m0.0${NC})\t"
    check_blacklist_file "$SUBNETS16_FILE" infos
    echo
    echo
    echo -e "${SLM}▙ Cron Jobs"
    echo -e "${SLM}▗ User ${GRN}$(whoami)"
    echo -ne "${SLM}▗_ Daily Download ${NC}" # curl.*${BASECRJ}
    if [[ $CRON == "true" ]]; then
        crontab -l | grep -E "curl.*$BASECRJ|wget.*$BASECRJ|scp.*$BASECRJ|rsync.*$BASECRJ" | awk '{print "\t\033[38;5;192m\033[5m◉\033[0m " $0 }'
    else
        echo -e " ${RED}◉${NC} no daily download found${NC}"
    fi
    echo -ne "${SLM}▗_ Daily Autoban ${NC}" # vipb-core.sh
    if [[ $CRON == "true" ]]; then
        crontab -l | grep -E "vipb.sh" | awk '{print "\t\033[38;5;192m\033[5m◉\033[0m " $0 }'
    else
        echo -e " ${RED}◉${NC} no daily VIPB-autoban job found"
    fi
    echo
    echo -e "${YLW}▙ VIPB variables"
    echo -e "${YLW}▗ Core ${NC}"
    
    echo -e "${YLW}VER: ${NC}$VER, ${YLW}CLI: ${NC}$CLI, ${YLW}DEBUG: ${NC}$DEBUG"
    echo -e "${YLW}IPSET_NAME: ${NC}$IPSET_NAME, ${YLW}MANUAL_IPSET_NAME: ${NC}$MANUAL_IPSET_NAME, ${YLW}SCRIPT_DIR: ${NC}$SCRIPT_DIR"
    echo -e "${YLW}CRON: ${NC}$CRON, ${YLW}LOG_FILE: ${NC}$LOG_FILE"
    
    echo -e "${YLW}▗ Session ${NC}"

    echo -e "${YLW}IPSET: ${NC}$IPSET, ${YLW}FIREWALL: ${NC}$FIREWALL, ${YLW}FIREWALLD: ${NC}$FIREWALLD"
    echo -e "${YLW}ADDED_IPS: ${NC}$ADDED_IPS, ${YLW}ALREADYBAN_IPS: ${NC}$ALREADYBAN_IPS, ${YLW}INFOS: ${NC}$INFOS, ${YLW}MODIFIED: ${NC}$MODIFIED"
    echo -e "${YLW}IPS: ${NC}${IPS[@]:0:3}... (total: ${#IPS[@]})"

    log_selector(){
        echo
        echo -e "${ORG}▙ LOGS${NC}"
        echo -e "${ORG}select log:${NC}"
        
        
        log_options=("auth.log" "usermin" "webmin" "syslog" "journalctl" "VIPB" "Reset VIPB log")
        if check_service fail2ban; then
            log_options+=("Fail2Ban" "Fail2Ban [WARNINGS]")
        fi
        
        select_log=$(select_opt "${NC}${DM}<< Back${NC}" "${ORG}${log_options[@]}")
        
        loglen=25
        case $select_log in
            0)  back
                ;;
            1)  header
                title "auth.log"
                echo
                echo -e "${CYN}▗ auth.log${NC}"
                tail -n $loglen /var/log/auth.log | grep -v "occ background-job:worker"
                echo
                log_selector
                ;;
            2)  header #2do check if present
                title "usermin"
                echo -e "${GRN}▗ usermin${NC}"
                tail -n $loglen /var/usermin/miniserv.error
                echo
                log_selector
                ;;
            3)  header #2do check if present
                title "webmin"
                echo -e "${BLU}▗ webmin${NC}"
                tail -n $loglen /var/webmin/miniserv.error
                echo
                log_selector
                ;;
            4)  header
                title "syslog"
                echo -e "${S16}▗ syslog${NC}"
                tail -n $loglen /var/log/syslog
                echo
                log_selector
                ;;
            5)  header
                title "journalctl"
                echo -e "${S24}▗ ${BG}journalctl -n $loglen${NC}"
                journalctl -n "$loglen"
                echo
                log_selector
                ;;
            6)  header
                title "ViPB log"
                echo
                echo -e "${VLT}▗ VIPB${NC}"
                check_blacklist_file "$LOG_FILE" infos
                echo
                echo
                tail -n $loglen $SCRIPT_DIR/vipb-log.log
                echo
                log_selector
                ;;
            7)  header
                title "reset ViPB log"
                echo
                echo -e "${VLT}▗ VIPB${NC}"
                check_blacklist_file "$LOG_FILE" infos
                echo
                tail -n $SCRIPT_DIR/vipb-log.log
                echo
                > "$SCRIPT_DIR/vipb-log.log"
                echo -e ".. VIPB-log now ${ORG}*** zeroed ***${NC}"
                log_selector
                ;;
            8)  header
                title "Fail2Ban" 
                echo
                echo -e "${SLM}▗ Fail2ban${NC}"
                tail -n $loglen /var/log/fail2ban.log
                echo
                log_selector
                ;;
            9)  header
                title "Fail2Ban Warnings" 
                echo
                echo -e "${SLM}▗ Fail2Ban [WARNING]${NC}"
                tail -n 1000 /var/log/fail2ban.log | grep "WARNING"
                echo
                log_selector
                ;;
        esac
    }
    log_selector
    echo -e "\e[0m"
    next
}

# DOWNLOAD & BAN (Menu 9)
function handle_download_and_ban() {
    debug_log "* DOWNLOAD & BAN!"
    header
    title "DOWNLOAD & BAN!"
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
        echo "▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤ DEBUG MODE ON ▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤"
        echo
    else
       clear
    fi
    echo -e "${NC}${RED}${DM}"
    echo -e "    ▁ ▂ ▃ ▅ ▆ ▇ ▉ ▇ ▆ ▅ ▃ ▂ ${NC}${VLT}${BD}Versatile IPs Blacklister${NC}${RED}${DM} ▁ ▂ ▃ ▅ ▆ ▇ ▉ ▇ ▆ ▅ ▃ ▂${NC}"
    echo
    echo -e "  ██╗   ██╗██╗██████╗ ██████╗ "
    echo -e "  ██║   ██║██║██╔══██╗██╔══██╗"
    echo -e "  ██║   ██║██║██████╔╝██████╔╝     ${DM}    •${NC}"
    echo -e "  ╚██╗ ██╔╝██║██╔═══╝ ██╔══██╗     ${DM}   ┏┓┏┳┓┏┓┏┓┏┓┓┏┏┓┏┏┓┏┓${NC}"
    echo -e "   ╚████╔╝ ██║██║     ██████╔╝     ${DM}by ┛┗┛┗┗┗┛┛┗┗┫┗┻┗┻┛┗┻┛ ${NC}"
    echo -e "    ╚═══╝  ╚═╝╚═╝     ╚═════╝                   ${DM}┗                      ${NC}${VER}"
    #echo -e "${RED}${DM}▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤▤${NC}"
}

# Dashboard w/ check (2do minimize..)
function dashboard() {
    
    echo -e "╒═══════════════════════════════════════════════════════════════════════════════╕${NC}"
   
    function services_row() {
        echo -ne "${NC}  [ "

        if [ "$IPTABLES" == "true" ]; then
            echo -ne "${GRN}"
        else
            echo -ne "${RED}"
        fi
        echo -ne " ▦${NC} iptables"

        if [ "$PERSISTENT" == "true" ]; then
            echo -ne "${GRN}-persistent"
        else
            echo -ne "${RED}"
        fi
        echo -ne "${NC} "
        
        if [ "$IPSET" == "true" ]; then
            echo -ne "${GRN}"
        else
            echo -ne "${RED}"
        fi
        echo -ne " ▤${NC} ipset ] \t"

        if [ "$UFW" == "true" ]; then
            echo -ne "${YLW}"
        else
            echo -ne "${RED}"
        fi 
        echo -ne " ▥${NC}${BG} ufw ${NC}  "
        
        if [ "$FIREWALLD" == "true" ]; then 
            echo -ne "${GRN}"
        else
            echo -ne "${RED}"
        fi
        echo -ne " ▧${NC} ${BG}firewalld${NC}  "

        if [ "$FAIL2BAN" == "true" ]; then
            echo -ne "${GRN}"
        else
            echo -ne "${RED}"
        fi
        echo -ne " ▩${NC} ${BG}fail2ban${NC}  "
        echo
    }
    services_row
    echo -ne "\t${VLT}░ ${BG}IPsum list${NC} "
    check_blacklist_file "$BLACKLIST_FILE"
    echo -ne "  ${CYN}▒ VIPB list${NC} "
    check_blacklist_file "$OPTIMIZED_FILE"
    if [ -f "$BLACKLIST_FILE" ] && [ -f "$OPTIMIZED_FILE" ] && [ -f "$MODIFIED" ]; then
        cmodified=$(stat -c "%y" "$BLACKLIST_FILE" | cut -d. -f1) 
        if [[ "$cmodified" > "$MODIFIED" ]]; then
            echo -ne " ${ORG}older! rebuild with 2${NC}"
        fi 
    fi     
    echo

    echo -ne "\t${SLM}⊙ Cron Jobs ${NC}"
    if [ "$CRON" == "false" ]; then
        echo -e "${RED}error: Cannot read crontab${NC}"
    else
    
        if crontab -l | grep -q "vipb.sh"; then
            echo -ne "\t${GRN}${BL}◉${BR} VIPB daily job found${NC}"
        else
            echo -ne "\t${RED}VIPB daily job not found${NC}"
        fi

        echo -ne " ${SLM}${BL} ▼${BR} Cron Download "

        for blacklist_lv_check in {1..8}; do
            blacklist_url_check="$BASECRJ${blacklist_lv_check}.txt"
            if crontab -l | grep -q "$blacklist_url_check"; then
                echo -ne " ${GRN}Level $blacklist_lv_check${NC}"
            fi
        done
    
    fi
    echo -e "${NC}"

    echo -e "╘═══════════════════════════════════════════════════════════════════════════════╛"   
    if [ "$IPSET" == "true" ]; then
        ipset_bans=$(count_ipset "$IPSET_NAME")
        manual_ipset_bans=$(count_ipset "$MANUAL_IPSET_NAME")
        #center "${VLT}${BD}$IPSET_NAME ${NC}▤▤ ${SLM}$MANUAL_IPSET_NAME${NC}" 90 
        title "VIPB bans: $ipset_bans . USER bans: $manual_ipset_bans" 
    fi
}

# Main menu
function menu_main() {
    echo -ne "${VLT}"
    #echo -e "┏┳┓┏┓┏┓┏ "
    #echo -e "┛┗┗┗ ┛┗┻ ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰"
    center "▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰"
    echo -e "\t${BG}${DIM}(You can directly enter an IP to ban.)${NC}"
    echo -e "${NC}"
    echo -e "\t1${VLT}. Download${NC} IPsum Blacklist"
    echo -e "\t2${CYN}.${NC} Lists Files ⋯ ${CYN}Aggregator${NC}"
    if [[ $IPSET == "false" ]]; then
        echo -ne "${DM}"
    fi
    echo -e "\t3. Ban Blacklists ${GRN}✦ ${FIREWALL}${NC}"
    echo -e "\t4${YLW}. User${NC} IPs banlist"
    if [[ $CRON == "false" ]]; then
        echo -ne "${DM}"
    fi
    echo -e "\t5${S24}.${NC} Daily ${SLM}Cron ${NC}Ban Job"
    echo -e "\t6${GRN}. Geo${NC} IP lookup"
    #echo -e "\tX${SLM}.${NC} Firewall & Services"
    echo -e "\t7${ORG}. Logs ${NC}& Vars"
    if [[ $IPSET == "true" ]]; then
        echo
        echo -e "\t${VLT}9. >> DOWNLOAD & BAN! <<${NC}"
    fi
    echo
    echo -e "\t0. Exit"
    while true; do
        echo -e "${YLW}"
        read -p "[#|IP]: " choice
        echo -e "${NC}"
        case $choice in
            1) handle_ipsum_download ;;
            2) handle_blacklist_files ;;
            3) handle_blacklist_ban ;;
            4) handle_manual_ban ;;
            5) handle_cron_jobs ;;
            6) handle_geoip_info ;;
            7) handle_logs_info ;;
            9) handle_download_and_ban; break ;;
            0) debug_log "* Exit"; vquit; break ;;
            X) handle_firewall_rules #will be deactivated?
                ;;
            *) if validate_ip "$choice"; then
                    echo -e "${YLW}Manual Ban IP: $choice${NC}"
                    INFOS="true"    
                    ban_ip "$MANUAL_IPSET_NAME" "$choice"
                    if [[ $FIREWALLD == "true" ]]; then
                        reload_firewall
                    fi
                else
                    echo -e "${YLW}Invalid option. ${BG}[0-9 or CIDR address]${NC}"
                fi
            ;;
        esac
    done
}

#2do figlet > movable to ui?
if ! command -v figlet >/dev/null 2>&1; then
    debug_log "info: figlet not installed"
fi    

# 2do remove this multiselect stuff back to basic number input for better compatibility
function multiselect() {

    # source github https://unix.stackexchange.com/questions/146570/arrow-key-enter-menu
    #   Arguments   : list of options, maximum of 256
    #   Return value: selected index (0 for opt1, 1 for opt2 ...)

    ESC=$( printf "\033")
    cursor_blink_on()   { printf "$ESC[?25h"; }
    cursor_blink_off()  { printf "$ESC[?25l"; }
    cursor_to()         { printf "$ESC[$1;${2:-1}H"; }
    # little helpers for terminal print control and key input
    print_inactive()    { printf "$2   $1 "; }
    print_active()      { printf "$2  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()    { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }

    local return_value=$1
    local -n options=$2
    local -n defaults=$3

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
}

function select_option() {

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

function select_opt() {
    select_option "$@" 1>&2
    local result=$?
    echo $result
    return $result
} 

log "vipb-ui.sh loaded [DEBUG $DEBUG / ARGS: $*]"