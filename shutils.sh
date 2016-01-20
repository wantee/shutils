#!/usr/bin/env bash

if [ -n "$SHUTILS_HOME" ]; then return; fi

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || {
    echo "Usage:"
    echo "  $ source $0"  
    echo "  $ shu_help"  
    exit 1
}

unset SHUTILS_HELP

SHUTILS_HOME=$(cd `dirname ${BASH_SOURCE[0]}`; pwd)

function shu_source_all()
{
    source $SHUTILS_HOME/common.sh
    source $SHUTILS_HOME/testing.sh
}

function shu-help()
{
    SHUTILS_HELP="true"
    echo "Available commands:"
    shu_source_all
    unset SHUTILS_HELP
}

shu_source_all
