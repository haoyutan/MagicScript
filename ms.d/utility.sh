#!/bin/bash


#-------------------------------------------------------------------------------
# Utility library functions
#-------------------------------------------------------------------------------
_ms_declare_list() {
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


_ms_word_in_string() {
    local argv=("$@")
    local word="${argv[0]}"
    local string="${argv[1]}"

    for piece in $string; do
        if [ "$piece" == "$word" ]; then return 0; fi
    done
    return 1
}


ms_utility_setup() {
    local argv=("$@")
    local prog=${argv[0]}
    local prefix=${argv[1]}
    local commands=${argv[2]}

    if [ "$prefix" == "" ] | [ "$commands" == "" ]; then
        ms_print_usage "PROG PREFIX COMMANDS" die
    fi

    local utility_funcs=$(_ms_declare_list functions | sed -n "/^$prefix/p")

    if [ "$utility_funcs" == "" ]; then
        ms_debug_info "WARN : No utility function found (prefix='$prefix')."
        return
    fi

    local defined_commands=""
    for command in $commands; do
        real_command=$(echo $command | sed "s/-/_/g")
        _ms_word_in_string "${prefix}_${real_command}" "$utility_funcs"
        if [ "$?" != "0" ]; then
            ms_debug_info "WARN : Utility function ${prefix}_${real_command}" \
                          "is not defined."
        else
            defined_commands="$defined_commands $command"
        fi
        defined_commands=${defined_commands# }
    done

    export MS_UTILITY_PROG=$prog
    export MS_UTILITY_PREFIX=$prefix
    export MS_UTILITY_COMMANDS=$defined_commands
    ms_debug_info "MS_UTILITY_PROG='$MS_UTILITY_PROG'"
    ms_debug_info "MS_UTILITY_PREFIX='$MS_UTILITY_PREFIX'"
    ms_debug_info "MS_UTILITY_COMMANDS='$MS_UTILITY_COMMANDS'"
}


ms_utility_print_help() {
    printf "Usage: %s %s\n" "$MS_UTILITY_PROG" \
           "$(echo $MS_UTILITY_COMMANDS | tr ' ' '|')"
}


ms_utility_run() {
    command=$1
    real_command=$(echo $command | sed "s/-/_/g")

    if [ "$command" == "" ]; then
        >&2 ms_utility_print_help
        ms_die "No command specified." $MS_EC_WRONG_ARGS
    fi

    _ms_word_in_string "$command" "$MS_UTILITY_COMMANDS"
    if [ "$?" == "0" ]; then
        shift
        ${MS_UTILITY_PREFIX}_${real_command} "$@"
    else
        >&2 ms_utility_print_help
        ms_die "Wrong command: $command." $MS_EC_WRONG_ARGS
    fi
}
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Import function
#-------------------------------------------------------------------------------
ms_utility_import() {
    ms_import aloha
}
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Demo functions
#-------------------------------------------------------------------------------
ms_utility_demo_help() {
    echo "This is $FUNCNAME."
}


ms_utility_demo_foo() {
    echo "This is $FUNCNAME."
}


ms_utility_demo_bar() {
    echo "This is $FUNCNAME."
}


ms_utility_demo_foo_bar() {
    echo "This is $FUNCNAME."
}


ms_utility_demo() {
    ms_utility_setup "ms_utility_demo" "ms_utility_demo" "help foo bar foo-bar"
    ms_utility_print_help
    ms_utility_run foo
    ms_utility_run bar
    ms_utility_run foo-bar
}
#-------------------------------------------------------------------------------
