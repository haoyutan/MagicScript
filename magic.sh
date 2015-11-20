#!/bin/bash


#M=============================================================================S
# MAGIC-SCRIPT source codes
#M=============================================================================S
__initialize__() {
    prog=${1:-$0}

    MS_WORK_DIR=$PWD
    MS_PROG_DIR=$(dirname $prog)
    MS_PROG=$(basename $prog)

    case "$MS_PROG" in
    *.sh)
        MS_NS=${MS_PROG%.sh}
        MS_COMPILED="no"
        ;;
    *)
        MS_NS=$MS_PROG
        MS_COMPILED="yes"
        ;;
    esac

    export MS_WORK_DIR MS_PROG_DIR MS_PROG MS_NS MS_COMPILED
}


__sub_scripts__() {
    scripts_dir=${1:-$MS_PROG_DIR/$MS_NS.d}
    if [ -d "$scripts_dir" ]; then
        cd $scripts_dir; find -L . -type f -name "*.sh" \
            | sort | tr '\n' ' '; cd $OLDPWD
    fi
}


__source_all__() {
    sub_scripts=$(__sub_scripts__)
    if [ ! -z "$sub_scripts" ]; then
        for sub_script in $sub_scripts; do
            source $MS_PROG_DIR/$MS_NS.d/$sub_script
        done
    fi
}


__initialize_compiler__() {
    export MS_SUB_SCRIPTS=$(__sub_scripts__)
    export MS_MAGIC_SPLIT_LINE=$(printf "#M%77sS" | tr ' ' '=')
    export MS_MAGIC_LEADING="# Compiled by MAGIC-SCRIPT from source:"
    export MS_MAGIC_PATTERN="[#] Compiled by MAGIC-SCRIPT from source: *.sh"
}


__expand__() {
    script=$1
    printf "$MS_MAGIC_SPLIT_LINE\n"
    printf "$MS_MAGIC_LEADING ${script#./}\n"
    printf "$MS_MAGIC_SPLIT_LINE\n"
    cat $MS_PROG_DIR/$MS_NS.d/$script
    printf "$MS_MAGIC_SPLIT_LINE\n"
}


__make__() {
    if [ "$MS_COMPILED" == "yes" ]; then
        >&2 echo "ERROR: Cannot make $MS_PROG_DIR/$MS_PROG."
        exit 127
    fi

    tmp_file=$(TMPDIR=$MS_WORK_DIR; mktemp -t __tmp_make_${MS_NS}.XXXXX)

    while IFS='' read -r line; do
        case "$line" in
        "__main__ \"\$@\"")
            for sub_script in $MS_SUB_SCRIPTS; do
                >>$tmp_file printf "%s\n\n\n" "$(__expand__ $sub_script)"
            done
            printf "%s\n" "$line" >>$tmp_file
            ;;
        *)
            printf "%s\n" "$line" >>$tmp_file
        esac
    done <$MS_PROG_DIR/$MS_PROG

    chmod +x $tmp_file

    if [ -e "$MS_WORK_DIR/$MS_NS" ]; then
        >&2 printf "WARNING: The compiled script is named as "
        >&2 printf "'$(basename $tmp_file)' because '$MS_NS' already exists.\n"
    else
        mv $tmp_file $MS_WORK_DIR/$MS_NS
    fi
}


__unmake__() {
    if [ "$MS_COMPILED" == "no" ]; then
        >&2 echo "ERROR: Cannot unmake $MS_PROG."
        exit 127
    fi

    tmp_dir=$(TMPDIR=$MS_WORK_DIR; mktemp -d -t __tmp_unmake_${MS_NS}.XXXXX)
    mkdir $tmp_dir/$MS_NS.d
    touch $tmp_dir/$MS_NS.sh
    main_buffer=$tmp_dir/__main_buffer
    magic_block_buffer=$tmp_dir/__magic_block_buffer

    parse_state="before_magic_blocks"
    while IFS='' read -r line; do
        # >&2 printf "[%24s] %s\n" "$parse_state" "$line"
        case "$parse_state" in
        before_magic_blocks)
            case "$line" in
            $MS_MAGIC_PATTERN)
                size=$(wc -c <$main_buffer)
                size_tail=$(tail -n1 $main_buffer | wc -c)
                size=$(expr $size "-" $size_tail)
                dd if=$main_buffer of=$tmp_dir/$MS_NS.sh bs=1 count=$size \
                    >/dev/null 2>&1
                >>$tmp_dir/$MS_NS.sh printf '__main__ "$@"\n'

                parse_state="entering_a_magic_block"
                sub_script=${line#$MS_MAGIC_LEADING }
                ;;
            __main__\ \"\$@\")
                >>$main_buffer printf '__main__ "$@"\n'
                mv $main_buffer $tmp_dir/$MS_NS.sh
                # We stop here because it is supposed to be the last line.
                break
                ;;
            *)
                >>$main_buffer printf "%s\n" "$line"
                ;;
            esac
            ;;
        entering_a_magic_block)
            case "$line" in
            $MS_MAGIC_SPLIT_LINE)
                parse_state="inside_a_magic_block"
                touch $magic_block_buffer
                ;;
            *)
                >&2 printf "ERROR: parse error around line:\n%s\n" "$line"
                ;;
            esac
            ;;
        inside_a_magic_block)
            case "$line" in
            $MS_MAGIC_SPLIT_LINE)
                sub_script_dir=$(dirname $sub_script)
                mkdir -p $tmp_dir/$MS_NS.d/$sub_script_dir
                mv $magic_block_buffer $tmp_dir/$MS_NS.d/$sub_script
                parse_state="between_magic_blocks"
                ;;
            *)
                >>$magic_block_buffer printf "%s\n" "$line"
                ;;
            esac
            ;;
        between_magic_blocks)
            case "$line" in
            $MS_MAGIC_PATTERN)
                parse_state="entering_a_magic_block"
                sub_script=${line#$MS_MAGIC_LEADING }
                ;;
            __main__\ \"\$@\")
                rm -f $main_buffer $magic_block_buffer
                # We stop here because it is supposed to be the last line.
                break
                ;;
            *)
                ;;
            esac
            ;;
        esac
    done <$MS_PROG_DIR/$MS_PROG

    chmod +x $tmp_dir/$MS_NS.sh

    if [ -e "$MS_WORK_DIR/$MS_NS.sh" ] | [ -e "$MS_WORK_DIR/$MS_NS.d" ]; then
        >&2 printf "WARNING: The uncompiled script and sub-scripts "
        >&2 printf "are placed under '$tmp_dir' because "
        >&2 printf "'$MS_NS.sh' or '$MS_NS.d' already exists.\n"
    else
        mv $tmp_dir/$MS_NS.sh $MS_WORK_DIR/$MS_NS.sh
        mv $tmp_dir/$MS_NS.d $MS_WORK_DIR/$MS_NS.d
        rm -rf $tmp_dir
    fi
}


__check_diff__() {
    file1=$1
    file2=$2
    printf "Checking if %s == %s... " "$file1" "$file2"
    diff "$file1" "$file2" >/dev/null 2>&1
    if [ "$?" == "0" ]; then
        printf "ok\n"
    else
        printf "FAILED\n"
    fi
}


__test__() {
    # Save context.
    orig_work_dir=$MS_WORK_DIR

    # Switch to a new context for testing.
    test_dir=$(TMPDIR=$MS_WORK_DIR; mktemp -d -t test_${MS_NS}.XXXXX)
    cp $MS_PROG_DIR/$MS_PROG $test_dir/$MS_PROG
    if [ "$MS_COMPILED" == "no" ] && [ -d "$MS_PROG_DIR/$MS_NS.d" ]; then
        cp -r $MS_PROG_DIR/$MS_NS.d $test_dir/$MS_NS.d
    fi
    cd $test_dir;
    __initialize__ $test_dir/$MS_PROG
    __initialize_compiler__

    test_dir_rel=${test_dir/#$orig_work_dir/"."}
    printf "$MS_MAGIC_SPLIT_LINE\n"
    printf "The working directory of this test is $test_dir_rel.\n\n"
    if [ "$MS_COMPILED" == "yes" ]; then
        printf "Unmaking ./$MS_NS to ./$MS_NS.sh... "
        ./$MS_NS __unmake__ >/dev/null
        printf "done\n"

        printf "Renaming the original file to ./$MS_NS.orig... "
        mv ./$MS_NS ./$MS_NS.orig
        printf "done\n"

        printf "Making ./$MS_NS.sh to ./$MS_NS... "
        ./$MS_NS.sh __make__ >/dev/null
        printf "done\n"

        __check_diff__ "$MS_NS" "$MS_NS.orig"
    elif [ "$MS_COMPILED" == "no" ]; then
        printf "Making ./$MS_NS.sh and ./$MS_NS.d to ./$MS_NS... "
        ./$MS_NS.sh __make__ >/dev/null
        printf "done\n"

        printf "Renaming the original files to "
        printf "./$MS_NS.sh.orig and ./$MS_NS.d.orig... "
        mv $MS_NS.sh $MS_NS.sh.orig
        mv $MS_NS.d $MS_NS.d.orig
        printf "done\n"

        printf "Unmaking $MS_NS to $MS_NS.sh and $MS_NS.d... "
        ./$MS_NS __unmake__ >/dev/null
        printf "done\n"

        __check_diff__ "$MS_NS.sh" "$MS_NS.sh.orig"
        for sub_script in $(__sub_scripts__ $MS_NS.d); do
            sub_script=${sub_script#./}
            __check_diff__ "$MS_NS.d/$sub_script" "$MS_NS.d.orig/$sub_script"
        done
    else
        >&2 echo "ERROR: Unknown error."
    fi

    clean=${1:-"clean"}
    case $clean in
    noclean)
        printf "\nWARNING: The test directory $test_dir_rel was not removed.\n"
        ;;
    *)
        printf "\nRemoving $test_dir_rel... "
        rm -rf $test_dir
        printf "done\n"
        ;;
    esac

    printf "$MS_MAGIC_SPLIT_LINE\n"

    # Restore context.
    cd $orig_work_dir
    __initialize__
    __initialize_compiler__
}


__main__() {
    export MS_ARGV="$*"

    __initialize__

    case "$1" in
    __make__ | __unmake__ | __test__)
        __initialize_compiler__
        func=$1; shift
        $func "$@"
        ;;
    *)
        if [ "$MS_COMPILED" == "no" ]; then
            __source_all__
        fi
        main "$@"
        ;;
    esac
}
#M=============================================================================S


__main__ "$@"
