#!/bin/bash


#-------------------------------------------------------------------------------
# Target library functions
#-------------------------------------------------------------------------------
_ms_target_check() {
    local success_condition="$1"

    ms_log_info "Checking success condition: $success_condition"
    $(eval $success_condition >>$MS_LOG_OUTPUT 2>&1)
    local exit_code=$?
    if [ "$exit_code" == "0" ]; then
        ms_log_info "Success condition is TRUE."
    else
        ms_log_info "Success condition is FALSE."
    fi
    return $exit_code
}


ms_target_task_run() {
    local description="$1"
    local command="$2"
    local success_condition="$3"

    ms_log_info "Task start: $description"
    printf "%-70s " "$description"

    if [ ! -z "$success_condition" ]; then
        _ms_target_check "$success_condition"
        if [ "$?" == "0" ]; then
            printf "skip\n"
            ms_log_info "Task finish: skip"
            return 0
        fi
    fi

    ms_log_info "Executing task: $command"
    $(eval $command >>$MS_LOG_OUTPUT 2>&1)
    local exit_code="$?"
    if [ "$exit_code" == "0" ]; then
        _ms_target_check "$success_condition"
        if [ "$?" == "0" ]; then
            ms_log_info "Task finish: ok"
            printf "ok\n"
        else
            ms_log_warn "Task execution is ok but success `
                        `condition is still FALSE."
            ms_log_info "Task finish: FAILED"
            printf "FAILED\n"
            return $MS_EC_FAILED
        fi
    else
        ms_log_info "Task finish: FAILED"
        printf "FAILED\n"
    fi
    return $exit_code
}


ms_target_check() {
    local description="$1"
    local check_command="$2"

    ms_log_info "Check start: $description"
    printf "%-70s " "$description"

    _ms_target_check "$check_command"
    local exit_code="$?"
    if [ "$exit_code" == "0" ]; then
        ms_log_info "Check result: yes"
        printf "yes\n"
    else
        ms_log_info "Check result: no"
        printf "no\n"
    fi
    return $exit_code
}


ms_target_demo() {
    local tmp_path="$HOME/NOT-EXIST"

    ms_output_block begin "ms_target_demo"
    ms_target_check "Checking if directory $tmp_path exists..." \
        "stat $tmp_path"
    ms_target_task_run "Removing directory $tmp_path..." \
        "rmdir $tmp_path" "! test -e $tmp_path"
    ms_target_task_run "Creating directory $tmp_path with wrong command..." \
        "true" "test -e $tmp_path"
    ms_target_task_run "Creating directory $tmp_path..." \
        "mkdir $tmp_path" "test -e $tmp_path"
    ms_target_task_run "Creating directory $tmp_path again..." \
        "mkdir $tmp_path" "test -e $tmp_path"
    ms_target_task_run "Removing directory $tmp_path..." \
        "rmdir $tmp_path" "! test -e $tmp_path"
    ms_target_task_run "Removing directory $tmp_path again..." \
        "rmdir $tmp_path" "! test -e $tmp_path"
    ms_output_block end
}


ms_target_import() {
    ms_import log
}
#-------------------------------------------------------------------------------
