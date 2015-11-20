#!/bin/bash


#-------------------------------------------------------------------------------
# Utility library functions
#-------------------------------------------------------------------------------
ms_utility_setup() {
    local argv=("$@")
    local prog=${argv[0]}
    local prefix=${argv[1]}
    local commands=${argv[2]}

    if [ "$prefix" == "" ] | [ "$commands" == "" ]; then
        ms_print_usage "PROG PREFIX COMMANDS" die
    fi

    local utility_funcs=$(ms_declare_list functions | sed -n "/^$prefix/p")

    if [ "$utility_funcs" == "" ]; then
        ms_debug_info "WARNING: No utility function found (prefix='$prefix')."
        return
    fi

    local defined_commands=""
    for command in $commands; do
        real_command=$(echo $command | sed "s/-/_/g")
        ms_word_in_string "${prefix}_${real_command}" "$utility_funcs"
        if [ "$?" != "0" ]; then
            ms_debug_info "WARNING: Utility function ${prefix}_${real_command}" \
                          "is not defined."
        else
            defined_commands="$defined_commands $command"
        fi
        defined_commands=${defined_commands# }
    done

    export MS_UTILITY_PROG=$prog
    export MS_UTILITY_PREFIX=$prefix
    export MS_UTILITY_COMMANDS=$defined_commands
    ms_debug_info "export MS_UTILITY_PROG='$MS_UTILITY_PROG'"
    ms_debug_info "export MS_UTILITY_PREFIX='$MS_UTILITY_PREFIX'"
    ms_debug_info "export MS_UTILITY_COMMANDS='$MS_UTILITY_COMMANDS'"
}


ms_utility_print_help() {
    printf "Usage: %s %s\n" "$MS_UTILITY_PROG" \
           "$(echo $MS_UTILITY_COMMANDS | tr ' ' '|')"
}


ms_utility_run() {
    command=$1
    real_command=$(echo $command | sed "s/-/_/g")

    if [ "$command" == "" ]; then
        ms_utility_print_help
        return $MS_EC_WRONG_ARGS
    fi

    ms_word_in_string "$command" "$MS_UTILITY_COMMANDS"
    if [ "$?" == "0" ]; then
        shift
        ${MS_UTILITY_PREFIX}_${real_command} "$@"
    else
        ms_die "Wrong utility command: $command.\n$(ms_utility_print_help)" \
            $MS_EC_WRONG_ARGS
    fi
}


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
