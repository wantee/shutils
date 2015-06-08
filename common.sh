#!/usr/bin/env bash

function shu_func_desc() 
{
    if [ -n "$SHUTILS_HELP" ]; then
        echo -n "  $1: "
        shift
        echo "$@"
    fi
}

shu_func_desc "shu-err [string ...]" "Print to stderr, red color"
function shu-err() 
{
    echo -e "\033[01;31m$@\033[0m" >&2
}

shu_func_desc "shu-valid-range <range>" "Return 0 if <range> is valid"
function shu-valid-range() 
{
    range=$1

    if [ -z "$range" ]; then
        return 0;
    fi

    if echo $range | grep '[^-0-9,]' > /dev/null; then
        return 1
    fi

    for r in ${range//,/ }; do
        if [ $r == "-" ]; then
            return 1
        fi

        hyphen=`echo $r | grep -o '-' | wc -l`
        if [ $hyphen -gt 1 ]; then
            return 1
        fi
    done

    return 0;
}

shu_func_desc "shu-in-range <n> [range]" "Return 0 if <n> is in <range>, <range> can be: -3,5,7-9,10-"
function shu-in-range() 
{
    t=$1
    range=$2

    if [ -z "$range" ]; then
        return 0;
    fi

    for r in ${range//,/ }; do
        echo $r | grep '-' > /dev/null
        hyphen=$?

        if [ $hyphen -eq 0 ]; then
            s=`echo $r | cut -d'-' -f1`
            e=`echo $r | cut -d'-' -f2`

            if [ -n "$s" -a -z "$e" ]; then
                if [ $t -ge $s ]; then
                    return 0;
                fi
            elif [ -z "$s" -a -n "$e" ]; then
                if [ $t -le $e ]; then
                    return 0;
                fi
            elif [ -n "$s" -a -n "$e" ]; then
                if [ $s -le $t -a $t -le $e ]; then
                    return 0;
                fi
            fi
        else
            if [ $r -eq $t ]; then
                return 0;
            fi
        fi
    done

    return 1;
}
