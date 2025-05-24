#!/bin/bash

# VIPB Graphical User Interface
# A simple, versatile and efficient IP ban script for Linux servers

# Colors
RED=''
GRN=''
VLT=''
NC=''
BG=''
## TEXTS_BIN ##################################################################
download_ipsum_gui_text="<span weight='bold'>IPsum</span> is a feed based on 30+ publicly available lists of suspicious and/or malicious IP addresses. \nThe provided list is made of IP addresses matched with a number of (black)lists occurrences.\n<span weight='light'>More info at: <a href='https://github.com/stamparm/ipsum'>https://github.com/stamparm/ipsum</a></span>
\n      <span weight='bold'>≡ Current list $(check_blacklist_file $BLACKLIST_FILE)</span>
\n
<span weight='bold'>Select strictness level:</span>"
aggregator_gui_text="VIPB-Aggregator compresses the IPsum blacklist into a smaller set of sources (subnetworks).
\n      <span weight='bold'>≡ Current optimized list $(check_blacklist_file $OPTIMIZED_FILE)</span>\n"
download_blacklist_text="Download IPsum list\n\n"
about_gui_text="<b><big>VIPB</big></b>
version $VER\n
<b>Versatile IP Blacklister</b>
<a href='https://github.com/simonquasar/vipb'>github</a>\n
Copyright © 2025 simonquasar
<a href='https://simonquasar.net'>simonquasar.net</a>\n
Author: Simon P.
License: GPL2"
## TEXTS_BIN ##################################################################

## START
# Check if the script is running from CLI
if (echo "$DISPLAY" | grep -qE ':[0-9]'); then
    echo "Loading GUI..."
    echo "##################################################################"
    echo "         WARNING: GUI mode is still under development!"
    echo "##################################################################"
    # Check if yad is installed
    if ! command -v yad &> /dev/null; then
        echo "YAD is not installed. Please install YAD to use VIPB-gui."
        exit 1
    fi
    # Constants and styling
    TITLE="VIPB $VER"
    WINDOW_WIDTH=600
    WINDOW_HEIGHT=400
    ICON="$SCRIPT_DIR/ico/vipb.png"
    BASE_WINDOW="--window-icon=$ICON --center --borders=20 --fixed --buttons-layout=center"

    ### GUI-CORE functions
    # --info) ARGS="$ARGS --image=gtk-dialog-info" ;;
    #	    --question) ARGS="$ARGS --image=gtk-dialog-question" ;;
    #	    --warning) ARGS="$ARGS --image=gtk-dialog-warning" ;;

    show_error() {
        yad --error --title="VIPB Error" --image="dialog-error" --on-top \
            --text="$1" \
            --button="OK:0"\
            $BASE_WINDOW
    }

    show_info() {
        yad --info --title="VIPB Info" --image="dialog-information" --on-top \
            --text="$*" \
            --button="OK!gtk-ok:0"\
            $BASE_WINDOW
    }

    # Ensure this script is only run via vipb.sh with 'gui' argument
    if [[ "$(basename "$0")" != "vipb.sh" ]] && [[ "$(basename "$0")" != "vipb" ]]; then
        show_error "VIPB GUI must be launched via\n ./vipb.sh gui"
        exit 1
    fi
    # Check root
    if [ "$EUID" -ne 0 ]; then
        show_error "<span weight='bold'>This script must be run as root.</span>\nPlease use sudo."
        exit 1
    fi

        # 1. Download IPsum list
        download_ipsum_gui() {
            response=$(yad --scale --title="Download IPsum list" \
                --image="document-save" \
                --text="${download_ipsum_gui_text}" \
                --inc-buttons --min-value=2 --max-value=8 --value=4 \
                --mark="2 - Less strict (larger list)":2 --mark=4:4 --mark="8 - Very strict (smaller list)":8 \
                --button="Download!document-save:0" \
                --button="Cancel:1"\
                $BASE_WINDOW )

            if [ $? -ne 0 ]; then
                return 1
            else
                local select_lv="$response"
                echo "# Selected level: $select_lv"
                (
                    echo "# Preparing download..."
                    echo "10"

                    echo "# Downloading IPsum list $select_lv..."
                    download_blacklist $select_lv
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
                ) | yad --progress --title="Downloading LV $select_lv" \
                    --width=300 \
                    --progress-text="Starting download..." \
                    --percentage=0 \
                    --auto-close \
                    --auto-kill \
                    $BASE_WINDOW

                local downloaded_count=$(wc -l < "$BLACKLIST_FILE")
                yad --info --title="Download Complete"\
                    --image="document-save" \
                    --text="Download completed successfully!\n\nDownloaded <span weight='bold'>$downloaded_count IP addresses</span> \n@ IPsum level $select_lv" \
                    --button="OK:0"\
                    $BASE_WINDOW
            fi
        }

        # 2. Aggregate IPs into subnets
        aggregator_gui() {

            # Get the list of blacklists
            mapfile -t blacklist_files < <(ls ./*.ipb 2>/dev/null)
            if [ ${#blacklist_files[@]} -eq 0 ]; then
                show_error "No blacklist files found in $BLACKLIST_DIR."
                return 1
            fi

            # Join array with ! for yad combo box
            blacklist_combo=$(printf ",%s" "${blacklist_files[@]}")
            blacklist_combo=${blacklist_combo:1}

            response=$(yad --form --title="VIPB Aggregator" --width=600 \
                --image="gtk-copy" \
                --text="$aggregator_gui_text" \
                --separator="," --item-separator="," \
                --field="Select Blacklist:CB" "$blacklist_combo" \
                --field="for CIDR /24 subnets (#.#.#.0) @ x:CB" "2,3,4,5,6,7,8,9" \
                --field="for CIDR /16 subnets (#.#.0.0) @ x:CB" "3,4,5,6,7,8,9,10" \
                --button="Aggregate,gtk-ok:0" \
                --button="Cancel,gtk-cancel:1" \
                --button="Help,gtk-help:2" \
                $BASE_WINDOW
            )
            yad_exit=$?

            if [ $yad_exit -eq 1 ] || [ $yad_exit -eq 252 ]; then
                return 1
            elif [ $yad_exit -eq 2 ]; then
                show_info "\nThis will aggregate the selected blacklist into subnets.\n\nThe tolerance level is used to determine how strict the aggregation should be.\n\nA lower tolerance level will result in a larger list of subnets, while a higher tolerance level will result in a smaller list of subnets."
                aggregator_gui
            else
                echo "$response"
                selected_blacklist=$(echo "$response" | cut -d',' -f1)
                if [[ -z "$selected_blacklist" || ! -f "$selected_blacklist" || "${selected_blacklist##*.}" != "ipb" ]]; then
                    show_error "No valid blacklist file selected. Please select a file with .ipb extension."
                    aggregator_gui
                fi

                (
                    p=0
                    compressor "$selected_blacklist" | while read -r line; do
                        echo "# $line"
                        p=$((p + 4))
                        [ $p -lt 99 ] && echo $p || echo 99;
                        #sleep 0.1
                    done
                ) | yad --progress \
                    --title="Compressing Blacklist" \
                    --progress-text="Starting compression..." \
                    --auto-close \
                    --auto-kill \
                    --width=600 \
                    $BASE_WINDOW
                yad_exit=$?

                if [ $yad_exit -ne 0 ] && [ $yad_exit -ne 252 ]; then
                    show_error "Compression cancelled."
                    return 1
                fi

                local uncompressed_count=$(wc -l < "$selected_blacklist")
                local compressed_count=$(wc -l < "$OPTIMIZED_FILE")
                show_info "\nThe aggregation is complete!\n\nThe optimized list contains <span weight='bold'>$compressed_count sources.</span> \n(Single IPs, CIDR /24 (#.#.#.0) and /16 (#.#.0.0) subnets.)\n\nThe original list contained <span weight='bold'>$uncompressed_count IP addresses</span>.\n\n\t\t<span weight='bold'>Compression: $(awk "BEGIN {if ($uncompressed_count > 0) printf \"%.2f\", 100 - ($compressed_count / $uncompressed_count * 100); else print \"0.00\"}")%</span>"
            fi
        }

        # 3. Ban from Blacklists
        blacklists_ban_gui () {
            # Get the list of blacklists
            blacklist_files=$(ls "$SCRIPT_DIR"/*.ipb 2>/dev/null)
            if [ -z "$blacklist_files" ]; then
                show_error "No blacklist files found in $BLACKLIST_DIR."
                return 1
            fi

            # Show the list of blacklists in a dialog
            selected_blacklist=$(yad --list \
                --title="Select Blacklist" \
                --image="document-open" \
                --column="Blacklist" \
                $blacklist_files \
                --button="OK:0" \
                --button="Cancel:1" \
                --width=600 \
                --height=400 \
                --text="Select a blacklist file to ban IPs from:" \
                $BASE_WINDOW)

            if [ $? -ne 0 ]; then
                return 1
            else
                echo "$selected_blacklist"
                selected_blacklist=$(echo "$selected_blacklist" | cut -d'|' -f1)
                if [[ -z "$selected_blacklist" || ! -f "$selected_blacklist" || "${selected_blacklist##*.}" != "ipb" ]]; then
                    show_error "No valid blacklist file selected. Please select a file with .ipb extension."
                    blacklists_ban_gui
                fi
                (
                    p=0
                    echo "$p"
                    ban_core "$selected_blacklist" | while read -r line; do
                        echo "# $line"
                    done
                    echo "100"
                ) | yad --progress \
                    --title="Banning Blacklist" \
                    --progress-text="Starting ban $selected_blacklist..." \
                    --enable-log="Ban details" \
                    --pulsate \
                    --auto-close \
                    --auto-kill \
                    --width=600 \
                    $BASE_WINDOW
                yad_exit=$?

                if [ $yad_exit -ne 0 ] && [ $yad_exit -ne 252 ]; then
                    show_error "Ban cancelled."
                    return 1
                fi

                local banlist_count=$(wc -l < "$selected_blacklist")
                show_info "\nThe ban is complete!\n\nThe ban list contained <span weight='bold'>$banlist_count sources.</span> \nVIPB Banned <span weight='bold'>XXX sources</span> ."
            fi
        }

        # 4. Manual ban IPs
        # 5. Check & Repair
        # 6. Manage ipsets
        # 7. Manage firewall
        # 8. Daily Cron Job & download L▼
        # 9. Geo IP lookup
        # 10. Log Extractor & Vars
        # ++. Download > Aggregate > Ban!

    # Main menu

    ### https://yad-guide.ingk.se/paned/yad-paned.html#_splitterpos

        show_main_menu() {
            yad --list --no-headers --hide-column=1 --title="$TITLE" \
                --width=$WINDOW_WIDTH \
                --height=$WINDOW_HEIGHT \
                --image="$SCRIPT_DIR/ico/vipb.ico" \
                --text="VIPB Versatile IP Blacklister" \
                --column="_" \
                --column="Action" \
                --column="Description" \
                "1" "Download " "IPsum blacklist" \
                "2" "Aggregate" "IPs into subnets" \
                "3" "Ban" "from Blacklists" \
                "4" "[2do] Manual ban" "IPs" \
                "5" "[2do] Check &amp; Repair" "" \
                "6" "[2do] Manage ipsets" "" \
                "7" "[2do] Manage firewall" "" \
                "8" "[2do] Daily Cron Job" "&amp; download L▼" \
                "9" "[2do] Geo IP" "lookup" \
                "10" "[2do] Log Extractor" "&amp; Vars" \
                --button="Download > Aggregate > Ban!applications-utilities-symbolic:9" \
                --button="About!help-contents:3" \
                --button="Select!gtk-ok:0" \
                --button="Quit!application-exit:1" \
                $BASE_WINDOW \
                --buttons-layout=spread
        }

        # Main loop
        while true; do
            # Show main menu and get selection
            selection=$(show_main_menu)
            ret=$?

            # Exit if window is closed or Exit is clicked
            if [[ $ret -eq 1 || $ret -eq 252 ]]; then
                echo "Exit."
                exit 0
            elif [[ $ret -eq 3 ]]; then
                yad --title="About VIPB" \
                    --image="$SCRIPT_DIR/ico/icon-192.png" \
                    --width=500 \
                    --height=100 \
                    --text-align=center \
                    --text="$about_gui_text" \
                    --button="Close:0" \
                    $BASE_WINDOW

            elif [[ $ret -eq 9 ]]; then
                echo "Download > Aggregate > Ban!"
                show_error "DAB! In development."
            else
                selected_id=$(echo $selection | cut -d'|' -f1)
                case $selected_id in
                    1)  download_ipsum_gui ;;
                    2)  aggregator_gui ;;
                    3)  blacklists_ban_gui ;;
                    4)  show_error "$selected_id In development." ;;
                    5)  show_error "$selected_id In development."  ;;
                    6)  show_error "$selected_id In development."  ;;
                    7)  show_error "$selected_id In development."  ;;
                    8)  show_error "$selected_id In development."  ;;
                    9)  show_error "$selected_id In development."  ;;
                    10)  show_error "$selected_id In development."  ;;
                esac
            fi
        done

    else
        echo "No graphical interface detected. Please run this script in a graphical environment."
        exit 1
    fi

