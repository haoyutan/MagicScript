#!/bin/bash


main() {
    export MS_DEBUG="yes"
    ms_import aloha
    ms_import log
    ms_log_setup

    ms_utility_demo
}
