#!/bin/bash


unittest_foo_1() {
    return 0
}


unittest_foo_2() {
    return 0
}


unittest_bar_1() {
    return 0
}

unittest_bar_2() {
    return 1
}


unittest_foobar_1() {
    return 0
}


ms_demo() {
    export MS_DEBUG="yes"

    ms_import logging
    ms_import utility

    ms_logging_setup $MS_WORK_DIR/ms_demo.log

    echo $MS_SPLIT_LINE
    echo "Hi there! This is libmagic."
    echo $MS_SPLIT_LINE

    cmd=$1
    if [ ! -z "$cmd" ]; then
        shift
        $cmd "$@"
        exit
    fi

    ms_unittest_test
    ms_unittest_test foo
    ms_unittest_test bar

    echo
    echo $MS_SPLIT_LINE
    ms_utility_demo
    echo $MS_SPLIT_LINE
}


main() {
    ms_demo "$@"
}
