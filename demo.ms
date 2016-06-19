#!/bin/bash


main() {
    export MS_DEBUG="yes"
    ms_import aloha log

    ms_log_setup
    ms_utility_demo
}
