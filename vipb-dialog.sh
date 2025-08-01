#!/bin/bash

# VIPB dialog interface
# A simple, versatile and efficient IP ban script for Linux servers

# https://www.geeksforgeeks.org/creating-dialog-boxes-with-the-dialog-tool-in-linux/
# dialog --common-options --boxType "Text" Height Width --box-specific-option
DIALOGRC="$SCRIPT_DIR/dialog.vipb"
export DIALOGRC
DIALOGOPTS="--backtitle 'VIPB - Versatile IP Blacklister'"
echo "Loading VIPB-gui (dialog) interface..."
sleep 1
CLI="dialog"

# Colors
colors() {
    NC='\Zn'    # reset
    BG='\Z7'    # white on black
    RED='\Z1'   # red
    GRN='\Z2'   # green
    VLT='\Z5'   # magenta
    BLU='\Z4'   # blue
    CYN='\Z6'   # cyan
    S24='\Z6'   # cyan
    S16='\Z6'   # cyan
    YLW='\Z3'   # orange
    ORG='\Z3'   # orange
    SLM='\Z3'   # orange
    GRY='\Z0'   # black default
    BD='\Zb'
    UL='\Zu'
    RV='\Zr'
}
nocolors() {
    NC=
    BG=
    RED=
    GRN=
    VLT=
    BLU=
    CYN=
    S24=
    S16=
    YLW=
    ORG=
    SLM=
    GRY=
    BD=
    UL=
    RV=
}

if ! command -v dialog &> /dev/null; then
    echo "dialog is not installed. Please install it first."
    exit 1
fi

if [[ "$(basename "$0")" != "vipb.sh" ]] && [[ "$(basename "$0")" != "vipb" ]]; then
    dialog --title "Error" --msgbox "This VIPB GUI must be launched via\n ./vipb.sh gui"
    exit 1
fi

function check_dialog() {
        (   echo -n "Checking Firewall rules... "
            check_firewall_rules
            echo "$FW_RULES" > "$SCRIPT_DIR/FW_RULES.tmp"
            echo "OK"
            echo -n "Checking VIPB ipsets"
            check_vipb_ipsets
            echo "$VIPB_STATUS" > "$SCRIPT_DIR/VIPB_STATUS.tmp"
            echo "$VIPB_BANS" > "$SCRIPT_DIR/VIPB_BANS.tmp"
            echo "$USER_STATUS" > "$SCRIPT_DIR/USER_STATUS.tmp"
            echo "$USER_BANS" > "$SCRIPT_DIR/USER_BANS.tmp"
            sleep 0.5
        ) | dialog --title "Please wait..." --backtitle "$backtitle" --colors --progressbox 4 38
            FW_RULES=$(cat "$SCRIPT_DIR/FW_RULES.tmp")
            VIPB_STATUS=$(cat "$SCRIPT_DIR/VIPB_STATUS.tmp")
            VIPB_BANS=$(cat "$SCRIPT_DIR/VIPB_BANS.tmp")
            USER_STATUS=$(cat "$SCRIPT_DIR/USER_STATUS.tmp")
            USER_BANS=$(cat "$SCRIPT_DIR/USER_BANS.tmp")
            rm -f "$SCRIPT_DIR/FW_RULES.tmp" "$SCRIPT_DIR/VIPB_STATUS.tmp" "$SCRIPT_DIR/VIPB_BANS.tmp" "$SCRIPT_DIR/USER_STATUS.tmp" "$SCRIPT_DIR/USER_BANS.tmp"
    }

backtitle="VIPB - Versatile IP Blacklister - $VER $CLI";
dialog --title "WELCOME to VIPB" --backtitle "$backtitle" --infobox "       $VER" 3 24
sleep 0.5

# 1. Download IPsum list
function download_dialog() { #[lv] argument
    select_lv=${1:-$BLACKLIST_LV}
    (
        echo "10"
        echo "XXX"
        echo "Downloading..."
        echo "XXX"
        download_blacklist $select_lv >/dev/null 2>&1
        PID=$!
        while kill -0 $PID 2>/dev/null; do
            echo "XXX"
            echo "Downloading... Please wait"
            echo "XXX"
            echo "50"
            sleep 1
        done
        echo "75"
        wait $PID
        echo "XXX"
        echo "Download complete!"
        echo "XXX"
        echo "100"
    ) | dialog --title "Downloading LV $select_lv" --backtitle "$backtitle" --gauge "Starting download..." 10 60 0

    local downloaded_count=$(wc -l < "$BLACKLIST_FILE")
    dialog --title "Download Complete"  --backtitle "$backtitle" --colors \
        --msgbox "\nDownloaded ${VLT}$downloaded_count IP addresses${NC} @ IPsum level $select_lv" 8 60
}

function download_ipsum_dialog {
    backtitle="VIPB - Download IPsum"
    dialog --title "Download IPsum list" --backtitle "$backtitle" --colors \
        --msgbox "${BLU}IPsum${NC} is a feed based on 30+ publicly available lists of suspicious and/or malicious IP addresses.\nThe provided list is made of IP addresses matched with a number of (black)lists occurrences. \n\nmore infos at ${BLU}${UL}https://github.com/stamparm/ipsum${NC}" 12 60

    local select_lv
    select_lv=$(dialog --title "Download IPsum list" --backtitle "$backtitle" --colors \
        --default-item 4 \
        --menu "Select IPsum list level:" 15 50 7 \
        2 "${RED}Less strict (larger list)${NC}" \
        3 "" \
        4 "${BG}default${NC}" \
        5 "" \
        6 "" \
        7 "" \
        8 "${RED}Very strict (smaller list)${NC}" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ] || [ -z "$select_lv" ]; then
        return 1
    fi
    download_dialog $select_lv
}

# 2. Aggregate IPs into subnets
function aggregator_dialog() {
    backtitle="VIPB - Aggregator"

    # Step 1: Select blacklist file
    blacklist_files=("$SCRIPT_DIR"/*.ipb)
    if [[ ! -f "$BLACKLIST_FILE" && ${#blacklist_files[@]} -gt 0 ]]; then
        default_blacklist="${blacklist_files[0]}"
    else
        default_blacklist="$BLACKLIST_FILE"
    fi

    selected_blacklist=$(dialog --title "Select Blacklist File" --backtitle "$backtitle" \
        --extra-button --extra-label "Info" \
        --fselect "$default_blacklist" 15 70 2>&1 >/dev/tty)

    d_exit=$?
    if [[ $d_exit -eq 3 ]]; then
        dialog --title "Aggregator Help" --backtitle "$backtitle Help" --colors --msgbox "\nSelect a .ipb blacklist file to aggregate. Use arrow keys to navigate, Enter to select, or Esc to cancel.\n\
        \nThis will aggregate the selected blacklist into subnets.\n\n${UL}The tolerance level is used to determine how strict the aggregation should be.${NC}\
        \n\nCIDR /24 (#.#.#.0) are often assigned for small networks, like a single office or department (256 addresses are then be banned) while CIDR /16 (#.#.0.0) cover larger networks, such as a whole organizations (65.536 addresses).\n\nA lower tolerance level will result in a larger list of subnets, while a higher tolerance level will result in a smaller list of subnets." 22 75
        aggregator_dialog
        return 1
    fi

    if [ $d_exit -ne 0 ] || [ -z "$selected_blacklist" ]; then
        return 1
    fi

    # Step 2: Enter CIDR tolerances
    cidr24_tol=$(dialog --title "CIDR /24 subnet tolerance" --backtitle "$backtitle - $selected_blacklist" \
        --rangebox "Set CIDR /24 tolerance (2-9):" 7 40 2 9 3 2>&1 >/dev/tty)
    d_exit=$?
    if [ $d_exit -ne 0 ]; then
        return 1
    fi

    cidr16_tol=$(dialog --title "CIDR /16 subnet tolerance" --backtitle "$backtitle - $selected_blacklist " \
        --rangebox "Set CIDR /16 tolerance (2-9):" 7 40 2 9 4 2>&1 >/dev/tty)
    d_exit=$?
    if [ $d_exit -ne 0 ]; then
        return 1
    fi

    response="$cidr24_tol $cidr16_tol"

    if [ $d_exit -eq 1 ] || [ $d_exit -eq 252 ]; then
        return 1
    else
        response=$(echo "$response" | tr '\n' ' ')
        read -r cidr24_tol cidr16_tol <<< "$response"
        if [[ -z "$selected_blacklist" || ! -f "$selected_blacklist" || "${selected_blacklist##*.}" != "ipb" ]]; then
            dialog --title "Error" --backtitle "$backtitle" --msgbox "No valid blacklist file selected. Please select a file with .ipb extension." 10 50
            aggregator_dialog
            return 1
        fi
        nocolors
        compressor "$selected_blacklist" "$cidr24_tol" "$cidr16_tol" | \
            dialog --title "Compressing Blacklist" --backtitle "VIPB - Download IPsum" --cr-wrap \
            --programbox "$selected_blacklist" 26 70
        d_exit=$?
        colors

        if [ $d_exit -ne 0 ] && [ $d_exit -ne 252 ]; then
            dialog --title "Error" --backtitle "$backtitle" --msgbox "Compression cancelled."
            return 1
        fi

        local uncompressed_count=$(wc -l < "$selected_blacklist")
        local subnet24_count=$(wc -l < "$SUBNETS24_FILE")
        local subnet16_count=$(wc -l < "$SUBNETS16_FILE")
        local compressed_count=$(wc -l < "$OPTIMIZED_FILE")

        dialog --title "Aggregator Info" --backtitle "$backtitle" --colors --ok-label "Back to Menu" \
            --msgbox "\nThe aggregation is complete!\n\nThe original list contained ${BLU}$uncompressed_count IP addresses${NC}.\nThe optimized list contains ${VLT}$compressed_count sources${NC}.\n(Including ${VLT}$subnet24_count${BLU}@$cidr24_tol${NC} /24 subnets & ${VLT}$subnet16_count${BLU}@$cidr16_tol${NC} /16 subnets)\n\n    ${BD}Compressed: $(awk "BEGIN {if ($uncompressed_count > 0) printf \"%.2f\", 100 - ($compressed_count / $uncompressed_count * 100); else print \"0.00\"}")%${NC}\n\nThe optimized list is saved as\n${VLT}$OPTIMIZED_FILE${NC}" 16 75

        next
    fi
}

# 3. Ban from Blacklists
function blacklists_ban_dialog () {
    backtitle="VIPB - Ban from Blacklists"
    blacklist_files=$(ls "$SCRIPT_DIR"/*.ipb 2>/dev/null)
    if [ -z "$blacklist_files" ]; then
        dialog --title "Error" --backtitle "$backtitle" --msgbox "No blacklist files found in $BLACKLIST_DIR." 10 50
        return 1
    fi
    ERRORS=0
    ALREADYBAN_IPS=0
    ADDED_IPS=0
    list_options=()

    for file in $blacklist_files; do
        rel_file="$(basename "$file")"
        count=$(wc -l < "$file")
        list_options+=("$rel_file" "$count entries")
    done

    selected_blacklist=$(dialog --title "Select Blacklist file" --backtitle "$backtitle" --colors \
        --default-item 2 \
        --menu "Select a blacklist file to ban IPs from:" 15 50 8 \
        "${list_options[@]}" \
        3>&1 1>&2 2>&3)
    d_exit=$?

    if [[ $d_exit -eq 0 && -n "$selected_blacklist" ]]; then
        selected_blacklist="$SCRIPT_DIR/${selected_blacklist#./}"

        total_lines=$(wc -l < "$selected_blacklist")

        #nocolors
        #ban_core_start "$selected_blacklist" | \
        #    dialog --title "Validating $selected_blacklist" --backtitle "$backtitle" \
        #    --progressbox 14 70
        #colors
        #sleep 5

        #mapfile -t BAN_IPS < "$SCRIPT_DIR/ban_core_ips.tmp"
        #total_ips=${#BAN_IPS[@]}
        #echo "0" > "$SCRIPT_DIR/added_ips.tmp"
        #echo "0" > "$SCRIPT_DIR/alreadyban_ips.tmp"
        #echo "0" > "$SCRIPT_DIR/errors.tmp"

        nocolors
        ban_core "$selected_blacklist" | \
            dialog --title "Banning $total_lines IPs" --backtitle "$backtitle" --cr-wrap \
            --programbox 20 70

        d_exit=$?
        ban_exit=${PIPESTATUS[0]}  # exit code di ban_core
        colors

        #nocolors
        #(
        #    ADDED_IPS=0
        #    ALREADYBAN_IPS=0
        #    ERRORS=0
        #    start_time=$(date +%s)
        #    for i in "${!BAN_IPS[@]}"; do
        #        ip="${BAN_IPS[$i]}"
        #        ban_ip "$VIPB_IPSET_NAME" "$ip"
        #        err=$?
        #        if [[ "$err" == "1" ]]; then
        #            ((ERRORS++))
        #        fi
        #        percent=$(( (i + 1) * 100 / total_ips ))
        #        estime=$(eta $start_time $i $total_ips)
        #        echo "$percent"
        #        echo "XXX"
        #        echo "Banning IP $((i + 1)) of $total_ips: $ip"
        #        echo "ETA: $estime "
        #        echo "XXX"
        #    done
        #    echo "$ADDED_IPS" > "$SCRIPT_DIR/added_ips.tmp"
        #    echo "$ALREADYBAN_IPS" > "$SCRIPT_DIR/alreadyban_ips.tmp"
        #    echo "$ERRORS" > "$SCRIPT_DIR/errors.tmp"
        #) | dialog --title "Banning $total_ips IPs" --backtitle "$backtitle" --gauge "Adding ${GRN}$total_ips IPs${NC} to '${BG}$VIPB_IPSET_NAME${NC}'..." 7 50 0
        #sleep 1.5
        #colors

        #ADDED_IPS=$(cat "$SCRIPT_DIR/added_ips.tmp")
        #ALREADYBAN_IPS=$(cat "$SCRIPT_DIR/alreadyban_ips.tmp")
        #ERRORS=$(cat "$SCRIPT_DIR/errors.tmp")
        #rm -f "$SCRIPT_DIR/added_ips.tmp" "$SCRIPT_DIR/alreadyban_ips.tmp" "$SCRIPT_DIR/errors.tmp"

        #nocolors
        #ban_core_end "$selected_blacklist" | \
        #    dialog --title "Ban Report" --backtitle "$backtitle" --ok-label "Back"\
        #    --programbox 16 28
        #
        #colors
    fi
    check_dialog
}

# 4. Manual banning
function manual_ban_dialog() {
    backtitle="VIPB - Manual Ban"
    USER_STATUS=$(check_ipset "$MANUAL_IPSET_NAME" &>/dev/null)
    USER_BANS=$(count_ipset "$MANUAL_IPSET_NAME")

    MANUAL_CHOICE=$(dialog --title "Manual Ban" --clear --colors --backtitle "$backtitle" --menu "User bans are stored in ipset ${BLU}$MANUAL_IPSET_NAME${NC} (max 254 sources allowed)" 11 45 10 \
        1 "Ban IP" \
        2 "View Banned IPs" \
        3 "(2do) Export to file"\
        2>&1 >/dev/tty)

    case $MANUAL_CHOICE in
        1)  ip_input=$(dialog --title "Manual Ban IP" --backtitle "$backtitle" --inputbox "Enter IP address or CIDR to ban:" 8 50 2>&1 >/dev/tty)
            d_exit=$?
            if [[ $d_exit -ne 0 || -z "$ip_input" ]]; then
                manual_ban_dialog
            fi
            # Validate IP/CIDR (basic check)
            if ! [[ "$ip_input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
                dialog --title "Error" --msgbox "Invalid IP or CIDR format." 8 40
                break
            else

                # Check if ipset exists, if not create it
                check_ipset "$MANUAL_IPSET_NAME"
                check_status="$?"
                count=$(count_ipset "$MANUAL_IPSET_NAME")
                case $check_status in
                    1 | 2 | 6 | 7 | 8 | 9 )
                        # not found / orphaned
                        if ! setup_ipset "$MANUAL_IPSET_NAME"; then
                            outcome="$?"
                            if [[ "$outcome" -ne 0 ]]; then
                                dialog --title "Manual Ban" --backtitle "$backtitle" --msgbox "${RED}ipset error.${NC}\n$outcome" 8 40
                                log "@$LINENO: Error: Failed to set up ipset. $outcome"
                                ((ERRORS++))
                                err=1
                            else
                                dialog --title "Manual Ban" --backtitle "$backtitle" --msgbox "${GRN}ipset created.${NC}\n$outcome" 8 40
                            fi
                        fi
                        ;;
                    0 | 3 | 4 | 5 )  #found
                        ;;
                esac

                # Ban ip in manual ipset

                ban_ip "$MANUAL_IPSET_NAME" "$ip_input"
                err=$?

                dialog --title "Manual Ban ($err)" --backtitle "$backtitle" --msgbox "IP/CIDR '$ip_input' has been banned." 8 40
            fi
            manual_ban_dialog
            ;;
        2)  if [[ "$FIREWALL" == "firewalld" ]]; then
                mapfile -t user_ips < <(firewall-cmd ${PERMANENT:+$PERMANENT} --ipset="$MANUAL_IPSET_NAME" --get-entries)
            elif [[ "$FIREWALL" == "iptables" ]]; then
                mapfile -t user_ips < <(ipset list "$MANUAL_IPSET_NAME" | grep -E '^[0-9]+\.')
            fi

            if [[ ${#user_ips[@]} -gt 0 ]]; then
                dialog --title "Manually Banned IPs" --backtitle "$backtitle" --msgbox "$(printf '%s\n' "${user_ips[@]}")" 15 60
            else
                dialog --title "Manually Banned IPs" --backtitle "$backtitle" --msgbox "No manually banned IPs found." 8 40
            fi
            manual_ban_dialog ;;
        3) manual_ban_dialog ;;
        *) break ;;
    esac
    check_dialog
}

# >>. DOWNLOAD, COMPRESS & BAN
function dab() {
    backtitle="VIPB - DOWNLOAD, COMPRESS & BAN"
    download_dialog
    nocolors
    compressor | \
        dialog --title "Compressing Blacklist" --backtitle "$backtitle" --cr-wrap \
        --programbox 22 70
    colors
    nocolors
    ban_core "$OPTIMIZED_FILE" | \
        dialog --title "Banning IPs" --backtitle "$backtitle" --cr-wrap \
        --programbox 20 70

    d_exit=$?
    ban_exit=${PIPESTATUS[0]}  # exit code di ban_core
    colors
    check_dialog
}

# 5. Check & Repair
function check_repair_dialog() {
    backtitle="VIPB - Check & Repair"
    nocolors
    check_and_repair | \
        dialog --title "Check & Repair" --backtitle "$backtitle" \
        --extra-button --extra-label "Repair" \
        --programbox 25 85
    d_exit=$?
    colors

    if [[ $d_exit -eq 3 ]]; then
        dialog --title "Repair" --backtitle "$backtitle" --msgbox "Coming Soon." 7 40
    fi

    check_dialog
}

#TODO 6. Manage ipsets:
function handle_ipsets_dialog() {
    backtitle="VIPB - Manage ipsets"
    if [[ "$FIREWALL" == "firewalld" ]]; then
        select_ipsets=($(sudo firewall-cmd --permanent --get-ipsets; firewall-cmd --get-ipsets | tr ' ' '\n' | sort -u))
        select_ipsets=($(printf "%s\n" "${select_ipsets[@]}" | awk '!seen[$0]++'))
        #select_ipsets=($(sudo firewall-cmd ${PERMANENT:+$PERMANENT} --get-ipsets)
    elif [[ "$IPSET" == "true" ]]; then
        select_ipsets=($(ipset list -n))
    fi


    ERRORS=0
    list_options=()

    if [[ ${#select_ipsets[@]} -eq 0 ]]; then
        dialog --title "Error" --backtitle "$backtitle" --msgbox "No ipsets found in system." 10 50
        return 1
    else
        ipsets_options=()
        for ipset in "${select_ipsets[@]}"; do
            count=$(ipset list "$ipset" | grep -c '^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
            if [[ "$ipset" != vipb-* ]]; then
                ipsets_options+=("V $ipset" "$count entries")
            else
                ipsets_options+=("$ipset" "$count entries")
            fi
        done

        selected_ipset=$(dialog --title "Select ipset" --backtitle "$backtitle" --colors \
            --default-item 2 \
            --menu "Select an ipset:" 15 50 8 \
            "${ipsets_options[@]}" \
            3>&1 1>&2 2>&3)
        d_exit=$?

    fi
    check_dialog
}

#TODO 7. Manage firewall:
function handle_firewalls_dialog() {
    backtitle="VIPB - Firewall rules"

    if get_fw_rules; then
                nocolors
                function fw_rules_list {
                    for i in "${!FW_RULES_LIST[@]}"; do
                        echo "${FW_RULES_LIST[$i]}"
                    done
                    check_vipb_rules
                }

                fw_rules_list | \
                dialog --title "Firewall rules" --backtitle "$backtitle" \
                --programbox 25 85
            d_exit=$?
            colors
    fi

    check_dialog
}

# 8. Change default LV
function change_default_lv_dialog() {
    backtitle="VIPB - Change IPsum ▼ download list level"
    local new_lv
    new_lv=$(dialog --title "Change Default IPsum Level" --backtitle "$backtitle" --colors \
        --rangebox "Select the new default IPsum list level that will be used by VIPB as default.\nUse arrow keys up/down or enter a number:${BD}(2 = less strict, 8 = very strict)${NC}\n" 11 60 2 8 "$BLACKLIST_LV" 2>&1 >/dev/tty)
    d_exit=$?
    if [[ $d_exit -eq 0 && -n "$new_lv" ]]; then
        set_blacklist_level "$new_lv"
        dialog --title "Default Level Changed" --backtitle "$backtitle" --msgbox "Default IPsum list level set to $new_lv." 7 40
    fi
}

# 9. Cron Job
function cron_job_dialog() {
    backtitle="VIPB - Daily Cron Autoban Job"
    if [[ "$DAILYCRON" == "true" ]]; then
        cronstatus_msg="VIPB autoban job ${GRN}found${NC}."
    else
        cronstatus_msg="VIPB autoban job ${RED}not found${NC}."
    fi
    dialog --colors --backtitle "$backtitle" --yesno "$cronstatus_msg\n\nDo you want to ${RV}$( [[ "$DAILYCRON" == "true" ]] && echo "remove" || echo "add" )${NC} the daily VIPB autoban job?" 8 50
    yn_exit=$?
    if [[ $yn_exit -eq 0 ]]; then
        if [[ "$DAILYCRON" == "true" ]]; then
        DAILYCRON=false
        crontab -l | grep -v "vipb.sh" | crontab -
        dialog --title "VIPB autoban job" --backtitle "$backtitle" --msgbox "VIPB daily ban job has been removed." 7 40
        else
        subtitle="add daily ban job"
        (crontab -l 2>/dev/null; echo "10 4 * * * $SCRIPT_DIR/vipb.sh") | crontab -
        dialog --title "VIPB autoban job" --backtitle "$backtitle" --msgbox "Cron Job added for daily VIPB autoban on blacklist at 4:10 AM server time." 8 50
        DAILYCRON=true
        fi
    fi
}

# 10. Geo IP info
function geo_ip_dialog() {
    backtitle="VIPB - Geo IP Lookup"
    local ip_input
    ip_input=$(dialog --title "Geo IP Lookup" --backtitle "$backtitle" --inputbox "Enter an IP address to lookup:" 8 50 2>&1 >/dev/tty)
    d_exit=$?
    if [[ $d_exit -ne 0 || -z "$ip_input" ]]; then
        return 1
    fi
    nocolors
    geo_ip "$ip_input" | dialog --title "Geo IP Info" --backtitle "$backtitle" --programbox 20 70
    colors
}

# 11. Log Extractor & Vars
function log_vars_dialog() {
    backtitle="VIPB - Vars & Logs Extractor"

    LOGVARS_CHOICE=$(dialog --title "Manual Ban" --clear --colors --backtitle "$backtitle" --menu "View system logs and ★ extract IPs." 15 45 10 \
        1 "VIPB log" \
        2 "VIPB log *reset*" \
        3 "VIPB variables"\
        4 "syslog"\
        5 "journalctl"\
        6 "★ auth.log"\
        7 "${BD}★ custom log${NC}"\
        2>&1 >/dev/tty)

    case $LOGVARS_CHOICE in
        1)  dialog --title "VIPB log" --backtitle "$backtitle" \
            --tailbox $LOG_FILE 25 100
            log_vars_dialog ;;
        2)  > "$SCRIPT_DIR/vipb-log.log"
            dialog --title "VIPB log *reset*" --colors --backtitle "$backtitle" --msgbox "VIPB log resetted." 6 25
            log_vars_dialog ;;
        3)  vars_list=()
            vars=(
                "VER:$VER"
                "CLI:$CLI"
                "DEBUG:$DEBUG"
                "SCRIPT_DIR:$SCRIPT_DIR"
                "LOG_FILE:$LOG_FILE"
                "BLACKLIST_LV:$BLACKLIST_LV"
                "VIPB_IPSET_NAME:$VIPB_IPSET_NAME"
                "VIPB_STATUS:$VIPB_STATUS"
                "MANUAL_IPSET_NAME:$MANUAL_IPSET_NAME"
                "USER_STATUS:$USER_STATUS"
                "FIREWALL:$FIREWALL"
                "IPSET:$IPSET"
                "IPTABLES:$IPTABLES"
                "FIREWALLD:$FIREWALLD"
                "UFW:$UFW"
                "PERSISTENT:$PERSISTENT"
                "PERMANENT:$PERMANENT"
                "CRON:$CRON"
                "DAILYCRON:$DAILYCRON"
            )

            menu_items=()
            for var in "${vars[@]}"; do
                key="${var%%:*}"
                value="${var#*:}"
                menu_items+=("$key" "$value")
                ((i++))
            done

            dialog --title "VIPB variables" --backtitle "$backtitle" --no-cancel \
                --menu "Environment vars:" 25 60 15 \
                "${menu_items[@]}"

            log_vars_dialog ;;
        4)  dialog --title "syslog" --backtitle "$backtitle" \
            --tailbox /var/log/syslog 25 100
            log_vars_dialog ;;
        5)  dialog --title "journalctl" --colors --backtitle "$backtitle" --msgbox "This section is not available in $CLI gui, use the classic CLI ui for now.\n\n${YLW}Feature coming soon!${NC}" 10 50
            log_vars_dialog;;
        6)  dialog --title "★ auth.log" --backtitle "$backtitle" \
            --tailbox /var/log/auth.log 25 100
            log_vars_dialog;;
        7)  dialog --title "★ custom log" --colors --backtitle "$backtitle" --msgbox "This section is not available in $CLI gui yet, use the classic CLI ui for now.\n\n${YLW}Feature coming soon!${NC}" 10 50
            log_vars_dialog;;
        *) break ;;
    esac
}

check_dialog
while true; do
    colors
    backtitle="${RED}VIPB - Versatile IP Blacklister${NC} - $VER (2025) by simonquasar";
    [[ $DEBUG == "true" ]] && backtitle+=" - DEBUG MODE";

    VLT='\Zr\Z5'

    CHOICE=$(dialog --clear --colors --backtitle "$backtitle" --title "VIPB Main Menu" \
    --extra-button --extra-label "About" --cancel-label "Exit" --ok-label "Select" \
    --menu "\n   ${BLU}VIPB Banned:${NC} ${VLT} $VIPB_BANS ${NC}     ${BLU}Firewall:${NC} $FIREWALL\n   ${BLU}User Banned:${NC} ${VLT} $USER_BANS ${NC}" 22 55 12 \
    1 "Download IPsum list" \
    2 "Aggregate IPs" \
    3 "Ban from blacklists" \
    ">>" "${VLT}Download > Aggregate > Ban!" \
    4 "Manual ban" \
    5 "Manage ipsets" \
    6 "Firewall rules" \
    7 "${RED}Check + Repair" \
    8 "IPsum level [${VLT} $BLACKLIST_LV ${NC}]" \
    9 "Daily Job${NC} [$( [[ "$DAILYCRON" == "true" ]] && echo "${GRN}↺${NC}" || echo "${RED}✗${NC}")]"\
    10 "Geo IP lookup" \
    11 "Logs Extractor" \
    2>&1 >/dev/tty)
    d_exit=$?
    VLT='\Z5'
    if [[ $d_exit -eq 3 ]]; then
        dialog --title "About VIPB" --backtitle "$backtitle" --colors --msgbox "\n${BLU}VIPB - Versatile IP Blacklister\n$VER (2025)${NC}\n\nA simple, versatile and efficient IP ban script for Linux servers.\n\nAuthor: simonquasar\nGitHub: ${UL}https://github.com/simonquasar/vipb${NC}\n\n${VLT}Protect your server with ease!\n${RV}${RED}Use at your own risk! Please review and test before deploying in production.${NC}" 18 60
        continue
    fi

    case $CHOICE in
        1) download_ipsum_dialog ;;
        2) aggregator_dialog ;;
        3) blacklists_ban_dialog ;;
        4) manual_ban_dialog ;;
        5)  [[ $IPSET == "true" ]] && handle_ipsets_dialog ;;
        6)  [[ ! $FIREWALL == "ERROR" ]] && handle_firewalls_dialog ;;
        7) check_repair_dialog ;;
        8) change_default_lv_dialog ;;
        9)  [[ $CRON == "true" ]] && cron_job_dialog ;;
        10) geo_ip_dialog ;;
        11) log_vars_dialog ;;
        ">>") dab;;
        *) break ;;
    esac
done

clear