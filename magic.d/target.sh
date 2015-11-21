#!/bin/bash


#-------------------------------------------------------------------------------
# Target library functions
#-------------------------------------------------------------------------------
ms_target_make() {
    local prefix="$1"
    local target="$2"
    if [ "$prefix" == "" ] || [ "$target" == "" ]; then
        ms_print_usage "PREFIX TARGET" die
    fi

    ms_debug_info "prefix=$prefix, target=$target"
    local target_func="${prefix}_${target}"
    if ms_declared_function $target_func; then
        ms_debug_info "Found target function $target_func."
    else
        ms_debug_info "Cannot find target function $target_func."
        ms_die "Target $target is not defined."
    fi

    if ! $target_func is_not_done; then
        ms_logging_log "Target $target is already made. Skip."
        return 0
    fi

    local deps="$($target_func deps)"
    ms_debug_info "deps='$deps'"
    [ "$deps" != "" ] && for dep in $deps; do
        ms_logging_log "Make $target's dependent target $dep."
        ms_target_make $prefix $dep
    done

    ms_logging_log "Making target $target: Started."
    $target_func run
    local exit_code_run=$?
    ms_debug_info "$target_func run exits with code $exit_code_run"
    if [ "$exit_code_run" != "0" ]; then
        ms_logging_log "Making target $target: Error occured."
        $target_func onerror "$?"
        local exit_code_onerror=$?
        ms_debug_info "$target_func onerror exits with code $exit_code_onerror"
        if [ "$exit_code_onerror" == "0" ]; then
            ms_logging_log "Making target $target: Error ignored."
        else
            ms_logging_log "Making target $target: Abort."
            ms_die "Making target $target failed."
        fi
    fi
    ms_logging_log "Making target $target: Finished."
}


ms_target_task_run() {
     local description="$1"
     local command="$2"
     local check_command="$3"

     printf "%-70s " "$description"

     sleep 0.1
     if [ "$check_command" != "" ]; then
         >>$MS_LOGGING_LOG_FILE printf "\nChecking %s\n" "$check_command"
         $(eval $check_command >>$MS_LOGGING_LOG_FILE 2>&1)
         if [ "$?" != "0" ]; then
             printf "skip\n"
             return 0
         else
             >>$MS_LOGGING_LOG_FILE printf "continue\n"
         fi
     else
         >>$MS_LOGGING_LOG_FILE printf "\n"
     fi

     >>$MS_LOGGING_LOG_FILE printf "Executing %s\n" "$command"
     $(eval $command >>$MS_LOGGING_LOG_FILE 2>&1)
     local exit_code="$?"
     if [ "$exit_code" == "0" ]; then
         printf "ok\n"
     else
         printf "FAILED\n"
     fi
     return $exit_code
}


ms_target_check() {
     local description="$1"
     local check_command="$2"
     local if_no_command="$3"

     printf "%-70s " "$description"

     >>$MS_LOGGING_LOG_FILE printf "\nChecking %s\n" "$check_command"
     $(eval $check_command >>$MS_LOGGING_LOG_FILE 2>&1)
     local exit_code="$?"
     if [ "$exit_code" == "0" ]; then
         printf "yes\n"
     else
         printf "no\n"
         if [ "$if_no_command" != "" ]; then
             $(eval $if_no_command)
             exit_code="$?"
         fi
     fi
     return $exit_code
}


ms_target_import() {
    ms_import logging
}
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Demo functions
#-------------------------------------------------------------------------------
ms_target_demo_clean() {
    command="$1"
    case $command in
    is_not_done)
        ;;
    deps)
        ;;
    run)
        ms_output_block begin "Clean"
        printf "Let's clean.\n"
        ms_target_task_run "Deleting ~/tmp/MONSTER..." \
            rm ~/tmp/MONSTER
        ms_output_block end
        return 1
        ;;
    onerror)
        return 0
        ;;
    *)
        ;;
    esac
}


ms_target_demo_build() {
    command="$1"
    case $command in
    is_not_done)
        ;;
    deps)
        printf "clean"
        ;;
    run)
        ms_output_block begin "Build"
        printf "Let's build.\n"
        ms_output_block end
        ;;
    onerror)
        ;;
    *)
        ;;
    esac
}


ms_target_demo_install() {
    command="$1"
    case $command in
    is_not_done)
        ;;
    deps)
        printf "clean build"
        ;;
    run)
        ms_output_block begin "Install"
        printf "Let's install.\n"
        ms_target_task_run "Testing pipe..." \
            "echo 'ABC' | grep 'ABC' >/tmp/test_ms_target.tmp"
        ms_target_task_run "Cleaning up..." \
            "rm -rf /tmp/test_ms_target.tmp" \
            "stat /tmp/test_ms_target.tmp"
        ms_target_task_run "Cleaning up again..." \
            "rm -rf /tmp/test_ms_target.tmp" \
            "stat /tmp/test_ms_target.tmp"
        ms_output_block end
        return 1
        ;;
    onerror)
        return 1
        ;;
    *)
        ;;
    esac
}


ms_target_demo() {
    ms_target_make "ms_target_demo" "install"
}
#-------------------------------------------------------------------------------
