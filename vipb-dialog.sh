#!/bin/bash

# VIPB dialog interface
# A simple, versatile and efficient IP ban script for Linux servers

# https://www.geeksforgeeks.org/creating-dialog-boxes-with-the-dialog-tool-in-linux/
# dialog --common-options --boxType "Text" Height Width --box-specific-option

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

display() { #2do
    local title="$1"
    local backtitle="$2"
    local message="$3"
    dialog --title "$title" --backtitle "VIPB - $backtitle" --msgbox "$message"
}

while true; do
    backtitle="VIPB - Versatile IP Blacklister - $VER"
    colors
    check_vipb_ipsets

    CHOICE=$(dialog --clear --colors --backtitle "$backtitle" --title "VIPB Main Menu" \
    --extra-button --extra-label "About" \
    --menu "\n    ${BLU}VIPB Banned:${NC} ${VLT}$VIPB_BANS${NC}   ${BLU}User Banned:${NC} ${VLT}$USER_BANS${NC}" 20 55 12 \
    1 "Download IPsum blacklist" \
    2 "Aggregate IPs into subnets" \
    3 "Ban from Blacklists" \
    4 "Manual ban IPs" \
    ">>" "${RED}Download > Aggregate & Ban!" \
    5 "${RED}Check & Repair" \
    6 "${BLU}Manage ipsets" \
    7 "${BLU}Manage firewall" \
    8 "${BLU}Change IPsum level ${NC}$BLACKLIST_LV" \
    9 "${BLU}Daily Cron Job${NC}$( [[ "$DAILYCRON" == "true" ]] && echo " ↺")"\
    10 "${BLU}Geo IP lookup" \
    11 "${BLU}Vars & Logs ${YLW}Extractor${NC}" \
    2>&1 >/dev/tty)

    d_exit=$?
    if [[ $d_exit -eq 3 ]]; then
        dialog --title "About VIPB" --backtitle "$backtitle" --colors --msgbox "\n${BLU}VIPB - Versatile IP Blacklister\n$VER (2025)${NC}\n\nA simple, versatile and efficient IP ban script for Linux servers.\n\nAuthor: simonquasar\nGitHub: ${UL}https://github.com/simonquasar/vipb${NC}\n\n${VLT}Protect your server with ease!\n${RV}${RED}Use at your own risk! Please review and test before deploying in production.${NC}" 18 60
        continue
    fi

    # 1. Download IPsum list
    function download_dialog() {
        select_lv=${1:-$BLACKLIST_LV}
        (
            echo "# Preparing download..."
            echo "10"

            echo "# Downloading IPsum list $select_lv..."
            download_blacklist $select_lv >/dev/null 2>&1

            PID=$!

            while kill -0 $PID 2>/dev/null; do
                echo "# Downloading... Please wait"
                echo "50"
                sleep 1
            done

            echo "# Processing downloaded list..."
            echo "75"

            wait $PID

            echo "# Download complete!"
            echo "100"
        ) | dialog --title "Downloading LV $select_lv" --backtitle "$backtitle" --gauge "Starting download..." 10 60 0

        local downloaded_count=$(wc -l < "$BLACKLIST_FILE")
        dialog --title "Download Complete"  --backtitle "$backtitle" --colors \
            --msgbox "Download completed successfully!\n\nDownloaded ${VLT}$downloaded_count IP addresses${NC} @ IPsum level $select_lv" 8 60
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
        cidr24_tol=$(dialog --title "CIDR /24 subnet tolerance" --backtitle "$backtitle" \
            --rangebox "Set CIDR /24 tolerance (2-9):" 7 40 2 9 3 2>&1 >/dev/tty)
        d_exit=$?
        if [ $d_exit -ne 0 ]; then
            return 1
        fi

        cidr16_tol=$(dialog --title "CIDR /16 subnet tolerance" --backtitle "$backtitle" \
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
            selected_blacklist="$selected_blacklist"
            if [[ -z "$selected_blacklist" || ! -f "$selected_blacklist" || "${selected_blacklist##*.}" != "ipb" ]]; then
                dialog --title "Error" --backtitle "$backtitle" --msgbox "No valid blacklist file selected. Please select a file with .ipb extension." 10 50
                aggregator_dialog
                return 1
            fi

            nocolors
            compressor "$selected_blacklist" "$cidr24_tol" "$cidr16_tol" | \
                dialog --title "Compressing Blacklist" --backtitle "VIPB - Download IPsum" \
                --programbox 22 70
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

            dialog --title "Aggregator Info" --backtitle "$backtitle" --colors \
                --msgbox "\nThe aggregation is complete!\n\nThe original list contained ${BLU}$uncompressed_count IP addresses${NC}.\nThe optimized list contains ${VLT}$compressed_count sources${NC}.\n(Including ${VLT}$subnet24_count${CYN}@$cidr24_tol${NC} /24 subnets & ${VLT}$subnet16_count${CYN}@$cidr16_tol${NC} /16 subnets)\n\n    ${BD}Compressed: $(awk "BEGIN {if ($uncompressed_count > 0) printf \"%.2f\", 100 - ($compressed_count / $uncompressed_count * 100); else print \"0.00\"}")%${NC}\n\nThe optimized list is saved as ${VLT}$OPTIMIZED_FILE${NC}" 16 75

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

        radiolist_options=()
        for file in $blacklist_files; do
            rel_file="$(basename "$file")"
            count=$(wc -l < "$file")
            radiolist_options+=("$rel_file" "$count entries" "off")
        done

        selected_blacklist=$(dialog --title "Select Blacklist file" --backtitle "$backtitle" --radiolist "Select a blacklist file to ban IPs from:" 15 60 10 "${radiolist_options[@]}" \
            2>&1 >/dev/tty)
        d_exit=$?

        if [[ $d_exit -eq 0 && -n "$selected_blacklist" ]]; then
            selected_blacklist="$SCRIPT_DIR/${selected_blacklist#./}"

            total_lines=$(wc -l < "$selected_blacklist")

            nocolors
            ban_core "$selected_blacklist" | \
                dialog --title "Banning IPs" --backtitle "$backtitle" \
                --programbox 20 70
            d_exit=$?
            ban_exit=${PIPESTATUS[0]}  # Ottiene l'exit code di ban_core
            colors

            dialog --title "DEBUG" --backtitle "$backtitle" --msgbox "d_exit=$d_exit\nselected_blacklist=$selected_blacklist\ntotal_lines=$total_lines\nban_exit=$ban_exit" 10 50

            banlist_count=$(wc -l < "$selected_blacklist")
            dialog --title "Ban Info" --backtitle "$backtitle" --colors --msgbox "\nThe ban is complete!\n\nThe ban list contained $banlist_count sources.\nVIPB Banned ## sources."
        fi
    }

    # 4. Manual banning
    function manual_ban_dialog() {
        backtitle="VIPB - Manual Ban"
        USER_STATUS=$(check_ipset "$MANUAL_IPSET_NAME" &>/dev/null)
        USER_BANS=$(count_ipset "$MANUAL_IPSET_NAME")

        MANUAL_CHOICE=$(dialog --title "Manual Ban" --clear --colors --backtitle "$backtitle" --menu "User bans are stored in ipset ${BLU}$MANUAL_IPSET_NAME${NC} (max 254 sources allowed)" 11 45 10 \
            1 "Ban IP" \
            2 "View Banned IPs" \
            3 "Export to file"\
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
                    manual_ban_dialog
                fi

                # Add to ipset
                if [[ "$FIREWALL" == "firewalld" ]]; then
                    firewall-cmd ${PERMANENT:+$PERMANENT} --ipset="$MANUAL_IPSET_NAME" --add-entry="$ip_input"
                elif [[ "$FIREWALL" == "iptables" ]]; then
                    ipset add "$MANUAL_IPSET_NAME" "$ip_input"
                fi

                dialog --title "Manual Ban" --backtitle "$backtitle" --msgbox "IP/CIDR '$ip_input' has been banned." 8 40
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
    }

    # >>. DOWNLOAD, COMPRESS & BAN
    function dab() {
        backtitle="VIPB - DOWNLOAD, COMPRESS & BAN"
        download_dialog
        nocolors
        compressor | \
            dialog --title "Compressing Blacklist" --backtitle "$backtitle" \
            --programbox 22 70
        colors
        nocolors
        ban_core "$BLACKLIST_FILE" | \
            dialog --title "Banning IPs" --backtitle "$backtitle" \
            --programbox 20 70
        d_exit=$?
        ban_exit=${PIPESTATUS[0]}  # exit code di ban_core
        colors
    }

    # 5. Check & Repair
    function check_repair_dialog() {
        backtitle="VIPB - Check & Repair"
        dialog --title "Cron Job" --colors --backtitle "$backtitle" --msgbox "This section will allow you to view and eventually repair the ipsets.\n\n${YLW}Feature coming soon!${NC}" 10 50
        nocolors
        check_and_repair | \
            dialog --title "Check & Repair" --backtitle "$backtitle" \
            --programbox 25 90
        colors

    }

    # 6. Manage ipsets
    # 7. Manage firewall

    # 8. Change default LV
    function change_default_lv_dialog() {
        backtitle="VIPB - Change IPsum ▼ download list level"
        local new_lv
        new_lv=$(dialog --title "Change Default IPsum Level" --backtitle "$backtitle" --colors \
            --rangebox "Select the new default IPsum list level.\nUse arrow keys up/down or enter a number.\n${BD}(2 = less strict, 8 = very strict):" 10 60 2 8 "$BLACKLIST_LV" 2>&1 >/dev/tty)
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
        dialog --title "Logs & Vars" --colors --backtitle "$backtitle" --msgbox "This section will allow you to view logs and variables.\n\n${YLW}Feature coming soon!${NC}" 10 50
    }

    case $CHOICE in
        1) download_ipsum_dialog ;;
        2) aggregator_dialog ;;
        3) blacklists_ban_dialog ;;
        4) manual_ban_dialog ;;
        ">>") dab;;
        5) check_repair_dialog ;;
        6)  [[ $IPSET == "true" ]] && handle_ipsets_dialog ;;
        7)  [[ ! $FIREWALL == "ERROR" ]] && handle_firewalls_dialog ;;
        8) change_default_lv_dialog ;;
        9)  [[ $CRON == "true" ]] && cron_job_dialog ;;
        10) geo_ip_dialog ;;
        11) log_vars_dialog ;;
        *) break ;;
    esac
done

clear