#!/bin/bash


#-------------------------------------------------------------------------------
# Global settings and variables
#-------------------------------------------------------------------------------
# Disable debug mode by default
MS_DEBUG="no"

# Error codes
MS_EC_FAILED=1
MS_EC_WRONG_ARGS=127
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Core utiity functions
#-------------------------------------------------------------------------------
ms_debug() {
    test "$MS_DEBUG" == "yes"
}


ms_debug_info() {
    local info=$(echo "$*" | tr "\n" " ")
    if ms_debug; then
        >&2 printf "[%s] DEBUG: %s: %s\n" \
            "$(date +%FT%T%z)" "${FUNCNAME[1]}" "$*"
    fi
}


ms_output_block() {
    local type=$1

    local SPLIT_LINE=$(printf "#%79s" | tr ' ' '-')
    case $type in
    begin)
        local title="$2"
        printf "$SPLIT_LINE\n"
        if [ "$title" != "" ]; then
            printf "$title\n\n"
        fi
        ;;
    end)
        printf "$SPLIT_LINE\n"
        ;;
    *)
        >&2 printf "ERROR: Internal error.\n"
        exit $MS_EC_WRONG_ARGS
        ;;
    esac
}


ms_print_trace_stack() {
    local stack_size=${#FUNCNAME[@]}

    ms_output_block begin "Trace stack:"
    for (( i=1; i<$(expr $stack_size "-" 2); i++ )); do
        local func="${FUNCNAME[$i]}"
        local lineno="${BASH_LINENO[$(( i - 1 ))]}"
        local src="${BASH_SOURCE[$i]}"
        printf "%-20s at line %-5s in %-30s\n" $func $lineno $src
    done
    ms_output_block end
}


ms_die() {
    local message=${1:-"Unknown error."}
    local exit_code=${2:-$MS_EC_FAILED}
    local trace=${3:-$trace_default}

    >&2 printf "ERROR: $message\n"

    if ms_debug; then
        >&2 ms_print_trace_stack
    fi

    exit $exit_code
}


ms_assert() {
    "$@" >/dev/null 2>&1
    local exit_code="$?"
    if [ "$exit_code" != "0" ]; then
        ms_die "$(printf "Assertion '%s' failed." "$*")"
    fi
}


ms_print_usage() {
    local prog=""
    if [ "$1" == "-p" ]; then
        prog="$2"
        shift 2
    else
        prog=${FUNCNAME[1]}
    fi

    local argv=("$@")
    local usage="${argv[0]}"
    local die="${argv[1]}"

    case $die in
    "" | live | and_live | continue | and_continue)
        printf "Usage: %s %s\n" "$prog" "$usage"
        ;;
    die | die | and_die | exit | and_exit)
        printf "Usage: %s %s\n" "$prog" "$usage"
        local exit_code=${3:-$MS_EC_WRONG_ARGS}
        ms_die "Wrong arguments." $exit_code
        ;;
    *)
        printf "Usage: ${FUNCNAME[0]} ARGS_SPECS [live|die EXIT_CODE]\n"
        ms_die "Wrong arguments." $MS_EC_WRONG_ARGS
        ;;
    esac
}


ms_trap() {
    local handler="$1"; shift

    if [ "${handler#*\'}" != "$handler" ]; then
        ms_die "Does not support character ' in signal handler."
    fi

    for signal in "$@"; do
        local old_handler=$(echo $(trap -p $signal) | sed "s/.*'\(.*\)'.*/\1/g")
        local new_handler="$handler"
        if [ ! -z "$old_handler" ]; then
            new_handler="$new_handler; $old_handler"
        fi
        trap "$new_handler" $signal
    done
}


ms_datetime() {
    local fmt=$1
    case $fmt in
    "" | iso)
        date +%FT%T%z
        ;;
    simple)
        date +%Y%m%d%H%M%S
        ;;
    date)
        date +%Y-%m-%d
        ;;
    time)
        date +%H:%M:%S
        ;;
    *)
        ms_print_usage "[iso|simple|date|time]" die
        ;;
    esac
}


ms_import() {
    local library=$1
    if [ "$library" == "" ]; then
        ms_print_usage "LIBRARY_NAME" die
    fi

    eval "local imported=\${__MS_IMPORTED_${library}__}"
    if [ "$imported" == "yes" ]; then return; fi

    ms_${library}_import
    if [ "$?" != "0" ]; then
        ms_die "Importing library $library failed."
    fi
    eval "export __MS_IMPORTED_\${library}__=yes"

    if ms_debug; then
        ms_debug_info "Imported library $library."
    fi
}
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Import function
#-------------------------------------------------------------------------------
ms_aloha_import() {
    ms_trap 'kill -9 -$$' INT

    export MS_TMP_DIR=$(mktemp -d -t ms.XXXXX)
    ms_trap "rm -rf \$MS_TMP_DIR" EXIT
}
#-------------------------------------------------------------------------------
