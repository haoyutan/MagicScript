#!/bin/bash


#-------------------------------------------------------------------------------
# **NOTE**
# The codes of function ms_ini_parse and ms_ini_dump are mostly borrowed
# from ajdiaz's blog post:
# http://theoldschooldevops.com/2008/02/09/bash-ini-parser/
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Ini library functions
#-------------------------------------------------------------------------------
ms_ini_parse() {
    OLDIFS=$IFS

    local cfg_file="$1"
    local cfg_name="$2"

    if [ ! -f "$cfg_file" ]; then
        ms_die "$cfg_file does not exist."
    fi

    ini="$(<$cfg_file)"                              # read the file
    ini="${ini//[/\[}"                               # escape [
    ini="${ini//]/\]}"                               # escape ]
    IFS=$'\n' && ini=( ${ini} )                      # convert to line-array
    ini=( ${ini[*]//;*/} )                           # remove comments with ;
    ini=( ${ini[*]/\    =/=} )                       # remove tabs before =
    ini=( ${ini[*]/=\   /=} )                        # remove tabs after =
    ini=( ${ini[*]/\ =\ /=} )                        # remove spaces around =
    ini=( ${ini[*]/#\\[/\}$'\n'${cfg_name}_} )       # set section prefix
    ini=( ${ini[*]/%\\]/ \(} )                       # convert text2function (1)
    ini=( ${ini[*]/=/=\( } )                         # convert item to array
    ini=( ${ini[*]/%/ \)} )                          # close array parenthesis
    ini=( ${ini[*]/%\\ \)/ \\} )                     # the multiline trick
    ini=( ${ini[*]/%\( \)/\(\) \{} )                 # convert text2function (2)
    ini=( ${ini[*]/%\} \)/\}} )                      # remove extra parenthesis
    ini[0]=""                                        # remove first element
    ini[${#ini[*]} + 1]='}'                          # add the last brace
    eval "$(echo "${ini[*]}")"                       # eval the result

    IFS=$OLDIFS                                      # IMPORTANT!
}


ms_ini_dump() {
    OLDIFS=$IFS

    local cfg_name="$1"
    IFS=' '$'\n'
    fun="$(declare -F)"
    fun="${fun//declare -f/}"
    for f in $fun; do
        [ "${f#${cfg_name}_}" == "${f}" ] && continue
        item="$(declare -f ${f})"
        item="${item##*\{}"
        item="${item%\}}"
        item=$(echo "$item" | sed 's/=.*$//')
        vars="${item}"
        eval $f
        echo "[${f#${cfg_name}_}]"
        for var in $vars; do
            echo "$var=$(eval echo \${$var[*]})"
        done
    done

    IFS=$OLDIFS                                      # IMPORTANT!
}


ms_ini_import()
{
    ms_import aloha
}
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# demo function
#-------------------------------------------------------------------------------
ms_ini_demo()
{
    # Create a temp ini file.
    local tmpfile=$PWD/__tmp_ms_ini_demo.ini
    printf "[demo_sec_a]\nfoo=1\nbar=2\nfoobar=3\n`
           `[demo_sec_b]\nfoo=x\nbar=y\nfoobar=z\n" \
        >$tmpfile

    # Parse ini file.
    ms_ini_parse $tmpfile "ini_demo"

    # Read variables in demo_sec_a
    ini_demo.section.demo_sec_a
    printf "Section demo_sec_a: foo=%s, bar=%s, foobar=%s\n" $foo $bar $foobar

    # Read variables in demo_sec_b
    ini_demo.section.demo_sec_b
    printf "Section demo_sec_b: foo=%s, bar=%s, foobar=%s\n" $foo $bar $foobar

    # Dump to ini format.
    printf "\nDump:\n"
    ms_ini_dump "ini_demo"

    # Clean up.
    rm -rf $tmpfile
}
#-------------------------------------------------------------------------------
