https://yad-guide.ingk.se/paned/yad-paned.html#_splitterpos

Usage:
  yad [OPTION…] - Yet another dialoging program

Help Options:
  -h, --help                                     Show help options
  --help-all                                     Show all help options
  --help-general                                 Show general options
  --help-common                                  Show common options
  --help-calendar                                Show calendar options
  --help-color                                   Show color selection options
  --help-dnd                                     Show drag-n-drop options
  --help-entry                                   Show text entry options
  --help-file                                    Show file selection options
  --help-font                                    Show font selection options
  --help-form                                    Show form options
  --help-icons                                   Show icons box options
  --help-list                                    Show list options
  --help-multi-progress                          Show multi progress bars options
  --help-notebook                                Show notebook dialog options
  --help-notification                            Show notification icon options
  --help-paned                                   Show paned dialog options
  --help-picture                                 Show picture dialog options
  --help-print                                   Show print dialog options
  --help-progress                                Show progress options
  --help-scale                                   Show scale options
  --help-text                                    Show text information options
  --help-filter                                  Show file filter options
  --help-misc                                    Show miscellaneous options
  --help-gtk                                     Show GTK+ Options

General options
  --title=TITLE                                  Set the dialog title
  --window-icon=ICONPATH                         Set the window icon
  --width=WIDTH                                  Set the window width
  --height=HEIGHT                                Set the window height
  --posx=NUMBER                                  Set the X position of a window
  --posy=NUMBER                                  Set the Y position of a window
  --geometry=WxH+X+Y                             Set the window geometry
  --timeout=TIMEOUT                              Set dialog timeout in seconds
  --timeout-indicator=POS                        Show remaining time indicator (top, bottom, left, right)
  --text=TEXT                                    Set the dialog text
  --text-align=TYPE                              Set the dialog text alignment (left, center, right, fill)
  --image=IMAGE                                  Set the dialog image
  --image-on-top                                 Show image above main widget
  --icon-theme=THEME                             Use specified icon theme instead of default
  --expander=[TEXT]                              Hide main widget with expander
  --button=NAME:ID                               Add dialog button (may be used multiple times)
  --no-buttons                                   Don't show buttons
  --buttons-layout=TYPE                          Set buttons layout type (spread, edge, start, end or center)
  --no-markup                                    Don't use pango markup language in dialog's text
  --no-escape                                    Don't close dialog if Escape was pressed
  --escape-ok                                    Escape acts like OK button
  --borders=NUMBER                               Set window borders
  --always-print-result                          Always print result
  --response=NUMBER                              Set default return code
  --selectable-labels                            Dialog text can be selected
  --sticky                                       Set window sticky
  --fixed                                        Set window unresizable
  --on-top                                       Place window on top
  --center                                       Place window on center of screen
  --mouse                                        Place window at the mouse position
  --undecorated                                  Set window undecorated
  --skip-taskbar                                 Don't show window in taskbar
  --maximized                                    Set window maximized
  --fullscreen                                   Set window fullscreen
  --no-focus                                     Don't focus dialog window
  --close-on-unfocus                             Close window when it sets unfocused
  --splash                                       Open window as a splashscreen
  --plug=KEY                                     Special type of dialog for XEMBED
  --tabnum=NUMBER                                Tab number of this dialog
  --kill-parent=[SIGNAL]                         Send SIGNAL to parent
  --print-xid=[FILENAME]                         Print X Window Id to the file/stderr

Common options
  --date-format=PATTERN                          Set the format for the returned date
  --float-precision=NUMBER                       Set presicion of floating numbers (default - 3)
  --command=CMD                                  Set command handler
  --listen                                       Listen for data on stdin
  --separator=SEPARATOR                          Set common separator character
  --item-separator=SEPARATOR                     Set item separator character
  --editable                                     Allow changes to text in some cases
  --tail                                         Autoscroll to end of text
  --quoted-output                                Quote dialogs output
  --num-output                                   Output number instead of text for combo-box
  --fontname=FONTNAME                            Specify font name to use
  --multiple                                     Allow multiple selection
  --add-preview                                  Enable preview
  --show-hidden                                  Show hidden files in file selection dialogs
  --filename=FILENAME                            Set source filename
  --vertical                                     Set vertical orientation
  --key=KEY                                      Identifier of embedded dialogs
  --complete=TYPE                                Set extended completion for entries (any, all, or regex)
  --iec-format                                   Use IEC (base 1024) units with for size values

Calendar options
  --day=DAY                                      Set the calendar day
  --month=MONTH                                  Set the calendar month
  --year=YEAR                                    Set the calendar year
  --details=FILENAME                             Set the filename with dates details
  --show-weeks                                   Show week numbers at the left side of calendar

Color selection options
  --init-color=COLOR                             Set initial color value
  --gtk-palette                                  Show system palette in color dialog
  --palette=[FILENAME]                           Set path to palette file. Default - /etc/X11/rgb.txt
  --expand-palette                               Expand user palette
  --mode=MODE                                    Set output mode to MODE. Values are hex (default) or rgb
  --extra                                        Use #rrrrggggbbbb format instead of #rrggbb
  --alpha                                        Add opacity to output color value

DND options
  --tooltip                                      Use dialog text as tooltip
  --exit-on-drop=NUMBER                          Exit after NUMBER of drops

Text entry options
  --entry-label=TEXT                             Set the entry label
  --entry-text=TEXT                              Set the entry text
  --hide-text=TEXT                               Hide the entry text
  --completion                                   Use completion instead of combo-box
  --numeric                                      Use spin button for text entry
  --licon=IMAGE                                  Set the left entry icon
  --licon-action=CMD                             Set the left entry icon action
  --ricon=IMAGE                                  Set the right entry icon
  --ricon-action=CMD                             Set the right entry icon action

File selection options
  --directory                                    Activate directory-only selection
  --save                                         Activate save mode
  --confirm-overwrite=[TEXT]                     Confirm file selection if filename already exists

Font selection options
  --preview=TEXT                                 Set text string for preview
  --separate-output                              Separate output of font description

Form options
  --field=LABEL[:TYPE]                           Add field to form (see man page for list of possible types)
  --align=TYPE                                   Set alignment of filed labels (left, center or right)
  --columns=NUMBER                               Set number of columns in form
  --scroll                                       Make form scrollable
  --output-by-row                                Order output fields by rows
  --focus-field=NUMBER                           Set focused field
  --cycle-read                                   Cycled reading of stdin data

Icons box options
  --read-dir=DIR                                 Read data from .desktop files in specified directory
  --compact                                      Use compact (list) view
  --generic                                      Use GenericName field instead of Name for icon label
  --item-width                                   Set the width of dialog items
  --term=PATTERN                                 Use specified pattern for launch command in terminal (default: xterm -e %s)
  --sort-by-name                                 Sort items by name instead of filename
  --descend                                      Sort items in descending order
  --single-click                                 Activate items by single click
  --monitor                                      Watch fot changes in directory

List options
  --column=COLUMN[:TYPE]                         Set the column header (see man page for list of possible types)
  --checklist                                    Use checkboxes for first column
  --radiolist                                    Use radioboxes for first column
  --no-headers                                   Don't show column headers
  --no-click                                     Disable clickable column headers
  --no-rules-hint                                Disable rules hints
  --grid-lines=TYPE                              Set grid lines (hor[izontal], vert[ical] or both)
  --print-all                                    Print all data from list
  --editable-cols=LIST                           Set the list of editable columns
  --wrap-width=NUMBER                            Set the width of a column for start wrapping text
  --wrap-cols=LIST                               Set the list of wrapped columns
  --ellipsize=TYPE                               Set ellipsize mode for text columns (none, start, middle or end)
  --ellipsize-cols=LIST                          Set the list of ellipsized columns
  --print-column=NUMBER                          Print a specific column. By default or if 0 is specified will be printed all columns
  --hide-column=NUMBER                           Hide a specific column
  --expand-column=NUMBER                         Set the column expandable by default. 0 sets all columns expandable
  --search-column=NUMBER                         Set the quick search column. Default is first column. Set it to 0 for disable searching
  --tooltip-column=NUMBER                        Set the tooltip column
  --sep-column=NUMBER                            Set the row separator column
  --sep-value=TEXT                               Set the row separator value
  --limit=NUMBER                                 Set the limit of rows in list
  --dclick-action=CMD                            Set double-click action
  --select-action=CMD                            Set select action
  --add-action=CMD                               Set add action
  --regex-search                                 Use regex in search
  --no-selection                                 Disable selection
  --add-on-top                                   Add new records on the top of a list

Multi progress bars options
  --bar=LABEL[:TYPE]                             Add the progress bar (norm, rtl, pulse or perm)
  --watch-bar=NUMBER                             Watch for specific bar for auto close
  --align=TYPE                                   Set alignment of bar labels (left, center or right)
  --auto-close                                   Dismiss the dialog when 100% of all bars has been reached
  --auto-kill                                    Kill parent process if cancel button is pressed

Notebook options
  --tab=LABEL                                    Add a tab to notebook
  --tab-pos=TYPE                                 Set position of a notebook tabs (top, bottom, left or right)
  --tab-borders=NUMBER                           Set tab borders
  --active-tab=NUMBER                            Set active tab

Notification icon options
  --menu=STRING                                  Set initial popup menu
  --no-middle                                    Disable exit on middle click
  --hidden                                       Doesn't show icon at startup
  --icon-size=SIZE                               Set icon size for fully specified icons (default - 16)

Paned dialog options
  --orient=TYPE                                  Set orientation (hor[izontal] or vert[ical])
  --splitter=POS                                 Set initial splitter position

Picture dialog options
  --size=TYPE                                    Set initial size (fit or orig)
  --inc=NUMBER                                   Set increment for picture scaling (default - 5)

Print dialog options
  --type=TYPE                                    Set source type (text, image or raw)
  --headers                                      Add headers to page

Progress options
  --progress-text=TEXT                           Set progress text
  --percentage=PERCENTAGE                        Set initial percentage
  --pulsate                                      Pulsate progress bar
  --auto-close                                   Dismiss the dialog when 100% has been reached
  --auto-kill                                    Kill parent process if cancel button is pressed
  --rtl                                          Right-To-Left progress bar direction
  --enable-log=[TEXT]                            Show log window
  --log-expanded                                 Expand log window
  --log-on-top                                   Place log window above progress bar
  --log-height                                   Height of log window

Scale options
  --value=VALUE                                  Set initial value
  --min-value=VALUE                              Set minimum value
  --max-value=VALUE                              Set maximum value
  --step=VALUE                                   Set step size
  --page=VALUE                                   Set paging size
  --print-partial                                Print partial values
  --hide-value                                   Hide value
  --invert                                       Invert direction
  --inc-buttons                                  Show +/- buttons in scale
  --mark=NAME:VALUE                              Add mark to scale (may be used multiple times)

Text information options
  --fore=COLOR                                   Use specified color for text
  --back=COLOR                                   Use specified color for background
  --wrap                                         Enable text wrapping
  --justify=TYPE                                 Set justification (left, right, center or fill)
  --margins=SIZE                                 Set text margins
  --show-cursor                                  Show cursor in read-only mode
  --show-uri                                     Make URI clickable
  --uri-color=COLOR                              Use specified color for links

File filter options
  --file-filter=NAME | PATTERN1 PATTERN2 ...     Sets a filename filter
  --mime-filter=NAME | MIME1 MIME2 ...           Sets a mime-type filter
  --image-filter=[NAME]                          Add filter for images

Miscellaneous options
  --about                                        Show about dialog
  --version                                      Print version
  --gtkrc=FILENAME                               Load additional GTK settings from file
  --hscroll-policy=TYPE                          Set policy for horizontal scrollbars (auto, always, never)
  --vscroll-policy=TYPE                          Set policy for vertical scrollbars (auto, always, never)
  --image-path=PATH                              Add path for search icons by name

GTK+ Options
  --class=CLASS                                  Program class as used by the window manager
  --name=NAME                                    Program name as used by the window manager
  --gtk-module=MODULES                           Load additional GTK+ modules
  --g-fatal-warnings                             Make all warnings fatal

Application Options:
  --rest=FILENAME                                Load extra arguments from file
  --calendar                                     Display calendar dialog
  --color                                        Display color selection dialog
  --color-selection                              Alias for --color
  --dnd                                          Display drag-n-drop box
  --entry                                        Display text entry or combo-box dialog
  --file                                         Display file selection dialog
  --file-selection                               Alias for --file
  --font                                         Display font selection dialog
  --font-selection                               Alias for --font
  --form                                         Display form dialog
  --icons                                        Display icons box dialog
  --list                                         Display list dialog
  --multi-progress                               Display multi progress bars dialog
  --notebook                                     Display notebook dialog
  --notification                                 Display notification
  --paned                                        Display paned dialog
  --picture                                      Display picture dialog
  --print                                        Display printing dialog
  --progress                                     Display progress indication dialog
  --scale                                        Display scale dialog
  --text-info                                    Display text information dialog
  --display=DISPLAY                              X display to use

  # ICONS

dialog-information	ℹ️ Info
dialog-warning	⚠️ Avviso
dialog-error	❌ Errore
dialog-question	❓ Domanda
document-open	📂 Apri file/cartella
document-save	💾 Salva
edit-copy	📋 Copia
edit-paste	📄 Incolla
edit-delete	🗑️ Elimina
system-search	🔍 Cerca
view-refresh	🔄 Aggiorna
media-playback-start	▶️ Avvia
media-playback-stop	⏹️ Ferma
go-next	➡️ Avanti
go-previous	⬅️ Indietro
window-close	❎ Chiudi
help-browser	❓ Aiuto
preferences-system	⚙️ Impostazioni
user-home	🏠 Home