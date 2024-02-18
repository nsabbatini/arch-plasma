#!/bin/sh

# Test if arguments are ethernet|wifi up|down
[[ $1 =~ ^enp.*$|^wlp.*$ && $2 =~ up|down ]] || { exit 0; }

# Search for connected ethernet; if found, turn off radio; if not, turn on radio
nmcli dev | grep -E "^enp.*ethernet.*connected.*$" > /dev/null
[[ $? -eq 0 ]] && { nmcli radio wifi off; } || { nmcli radio wifi on; }

exit 0
