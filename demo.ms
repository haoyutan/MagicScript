#!/bin/bash


main() {
    export MS_DEBUG="yes"
    ms_import aloha log target
    ms_log_setup $MS_NS.log

#    ms_log_setup
#    ms_utility_demo
    ms_target_demo
}
