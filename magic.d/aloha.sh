#!/bin/bash


#-------------------------------------------------------------------------------
# Basic utiity functions for writing other functions
#-------------------------------------------------------------------------------

# Error codes
MS_EC_FAILED=1
MS_EC_WRONG_ARGS=127

# Other shared variables
MS_SPLIT_LINE=$(printf "#%79s" | tr ' ' '-')


ms_debug() {
    test "$MS_DEBUG" == "yes"
}


ms_debug_info() {
    local info=$(echo "$*" | tr "\n" " ")
    if ms_debug; then
        >&2 printf "[%s] DEBUG: %s: %s\n" \
            "$(ms_datetime time)" "${FUNCNAME[1]}" "$*"
    fi
}


ms_output_block() {
    local type=$1
    case $type in
    begin)
        local title="$2"
        printf "$MS_SPLIT_LINE\n"
        if [ "$title" != "" ]; then
            printf "$title\n\n"
        fi
        ;;
    end)
        printf "$MS_SPLIT_LINE\n"
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
        printf "%-20s at line %-5s in %20s\n" $func $lineno $src
    done
    ms_output_block end
}


ms_die() {
    local trace_default="notrace"
    if ms_debug; then trace_default="trace"; fi

    local message=${1:-"Unknown error."}
    local exit_code=${2:-$MS_EC_FAILED}
    local trace=${3:-$trace_default}

    >&2 printf "ERROR: $message\n"

    if [ "$trace" == "trace" ]; then
        >&2 ms_print_trace_stack
    fi

    exit $exit_code
}


ms_die_on_error() {
    local exit_code=$?
    if [ "$1" != "" ]; then
        $@
        exit_code=$?
    fi

    if [ "$exit_code" != "0" ]; then
        ms_die "$(printf "Exit code is %s." "$exit_code")" $exit_code
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


ms_import() {
    local library=$1
    if [ "$library" == "" ]; then
        ms_print_usage "LIBRARY_NAME" die
    fi

    eval "local imported=\${__MS_IMPORTED_${library}__}"
    if [ "$imported" == "yes" ]; then
        ms_debug_info "Library already imported: $library. Skip."
        return
    fi

    ms_${library}_import
    if [ "$?" != "0" ]; then
        ms_die "Import library $library failed."
    fi
    eval "export __MS_IMPORTED_\${library}__=yes"

    if ms_debug; then
        ms_debug_info "Library imported: $library."
    fi
}


ms_declare_list() {
    local type=$1
    case $type in
    functions) # functions
        declare -F | sed 's/^declare -f //'
        ;;
    variables) # variables
        declare -x | grep "^declare -x" | sed -e "s/.* \(.*\)=.*/\1/"
        ;;
    *)
        ms_print_usage "[functions|variables]" die
        ;;
    esac
}


ms_declared_function() {
    local function=$1
    if [ $function == "" ]; then
        ms_print_usage "FUNCTION_NAME" die
    fi
    ms_declare_list functions | grep -q "^$target_func$"
}
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Unittest functions
#-------------------------------------------------------------------------------
ms_unittest_test() {
    local pattern="^unittest_$1_"
    local unittest_funcs=$(ms_declare_list functions | sort | grep "$pattern")
    ms_debug_info "pattern='$pattern', unittest_funcs='$unittest_funcs'"

    if [ -z "$unittest_funcs" ]; then
        printf "WARNING: No test case with pattern '$pattern'.\n" $pattern
        return
    fi

    local total=$(echo "$unittest_funcs" | grep -c "^")
    local current=0
    local passed=0
    local errfile="$MS_TMP_DIR/_unittest.err"
    ms_output_block begin \
        "$(printf "Unittest: Running %s test cases..." $total)"
    for func in $unittest_funcs; do
        current=$(expr $current "+" 1)
        progress=$(printf "[%${#total}s/%s]" $current $total)
        printf "%s Checking %-55s " "$progress" "$func..."
        $func 2>$errfile >/dev/null
        local exit_code=$?
        if [ "$exit_code" == "0" ]; then
            passed=$(expr $passed "+" 1)
            printf "ok\n"
        else
            printf "FAILED\n"
        fi

        if [ -s "$errfile" ]; then
            ms_debug_info "$(printf "stderr:\n%s" "$(cat $errfile)")"
        fi
    done

    local failed=$(expr $total "-" $passed)
    printf "\nUnittest: Ran %d test cases, %d passed, %d failed.\n" \
           $total $passed $failed
    ms_output_block end

    [ "$passed" == "$total" ]; return
}


ms_assert() {
    "$@" >/dev/null 2>&1
    local exit_code="$?"
    if [ "$exit_code" != "0" ]; then
        ms_die "$(printf "Assertion '%s' failed." "$*")"
    fi
}
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Standard library functions
#-------------------------------------------------------------------------------
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


ms_random_filename() {
    local prefix=$1
    printf "$prefix%s%06d" $(ms_datetime simple) $RANDOM
}


ms_word_in_string() {
    local argv=("$@")
    local word="${argv[0]}"
    local string="${argv[1]}"

    for piece in $string; do
        if [ "$piece" == "$word" ]; then return 0; fi
    done
    return 1
}
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Import function
#-------------------------------------------------------------------------------
ms_aloha_import() {
    export MS_TMP_DIR=$(mktemp -d -t ms.XXXXX)
}
#-------------------------------------------------------------------------------
