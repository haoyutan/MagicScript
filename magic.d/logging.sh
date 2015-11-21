#!/bin/bash


#-------------------------------------------------------------------------------
# Logging library functions
#-------------------------------------------------------------------------------
ms_logging_setup() {
    trap 'kill -9 -$$' INT

    local log_file=$1
    if [ "$log_file" == "" ]; then
        ms_print_usage "LOG_FILE" die
    fi

    if [ "$MS_CHILD" != "yes" ]; then
        local pipe=$(ms_random_filename "$MS_TMP_DIR/pipe.")
        mkfifo $pipe
    
        # Keep PID of this process
        export MS_CHILD="yes"
        sh $0 $MS_ARGV >$pipe 2>&1 &
        local pid=$!
    
        tee -a $log_file <$pipe &
    
        wait $pid
    
        # Return same error code as original process
        exit $?
    fi

    export MS_LOGGING_LOG_FILE=$log_file
    ms_logging_log "New logging session begins at $(ms_datetime iso)."
}


ms_logging_log() {
    if ms_debug; then
        >&2 printf "[%s] INFO : %s: %s\n" \
            "$(ms_datetime time)" "${FUNCNAME[1]}" "$*"
    else
        if [ "$MS_LOGGING_LOG_FILE" != "" ]; then
            >>$MS_LOGGING_LOG_FILE printf "[%s] INFO : %s: %s\n" \
                "$(ms_datetime time)" "${FUNCNAME[1]}" "$*"
        elif [ "$MS_LOGGING_STDERR" == "yes" ]; then
            >&2 printf "[%s] INFO : %s: %s\n" \
                "$(ms_datetime time)" "${FUNCNAME[1]}" "$*"
        fi
    fi
}


ms_logging_exec() {
    ms_logging_log "$(printf "Executing '%s'..." "$*")"
    tmpfile=$MS_TMP_DIR/$(ms_random_filename "ms_logging_exec_")
    >$tmpfile $@ 2>&1
    local exit_code=$?
    ms_logging_log "$(printf "Output:\n%s" "$(cat $tmpfile)")"
    rm -rf $tmpfile
    return $exit_code
}


ms_logging_assign() {
    local name="$1"
    local value="$2"
    eval "$name=\$value"
    ms_logging_log "$name=$value"
}


ms_logging_import() {
    ms_import aloha
    export MS_LOGGING_LOG_FILE=/dev/null
}
#-------------------------------------------------------------------------------
