#!/bin/bash

write_log_entry() {
    local log_entry=$1
    local source_name=${log_entry%%:*}
    local message=${log_entry#*:}

    source_name=${source_name%"${source_name##*[![:space:]]}"}
    message=${message# }
    printf '%s : %-27s : %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$source_name" "$message"
}