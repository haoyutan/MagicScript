#!/bin/bash


#-------------------------------------------------------------------------------
# Logging library functions
#-------------------------------------------------------------------------------
_ms_random_filename() {
    local prefix=$1
    printf "$prefix%s%06d" $(ms_datetime simple) $RANDOM
}

ms_log_setup() {
    local log_file="${1:-"/dev/null"}"
    MS_LOG_OUTPUT=$log_file
    ms_debug_info "Output log to $MS_LOG_OUTPUT."
}


_ms_log_log() {
    local level="$1"; shift
    >>$MS_LOG_OUTPUT printf "[%s] %-5s: %s: %s\n" \
        "$(ms_datetime iso)" "$level" "${FUNCNAME[2]}" "$*"
}


ms_log_info() {
    _ms_log_log "INFO" $*
}


ms_log_warn() {
    _ms_log_log "WARN" $*
}


ms_log_assign() {
    local name="$1"
    local value="$2"
    eval "$name=\$value"
    ms_log_info "$name=$value"
}
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Import function
#-------------------------------------------------------------------------------
ms_log_import() {
    ms_import aloha
    export MS_LOG_OUTPUT="/dev/stderr"
}
#-------------------------------------------------------------------------------
