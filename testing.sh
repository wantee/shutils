#!/usr/bin/env bash

function shu_testing_help()
{
    echo "shu-testing [dir] [tests]: Run tests"
    echo "shu-testing new [dir]: Create a new test site"
    echo "shu-testing list [dir] [tests]: List tests"
    echo "shu-testing accept [dir] [tests]: Accept build: overwrite expected files with build files"
    echo "  default <dir>: ./tests"
    echo "  empty <tests> denotes all tests "
}

shopt -s expand_aliases
alias shu_testing_clear='local name=""; local before=""; local script=""; local after=""; local compare=()'

function shu_testing_new()
{
    local dir=$1

    mkdir -p $dir
    mkdir -p $dir/expected
    mkdir -p $dir/conf.d
    
    cat <<-EOF > "$dir/conf.d/case.1.cnf"
name="First Case"                    # name of this test case
before="mkdir -p output"             # script run before testing script
script="echo \$name > output/1.txt"   # testing script
after="echo Finish"                  # script run after compare
compare=("expected/:output/")        # files to be compared, each pair separated by a colon
EOF
}

function shu_testing_list()
{
    local dir=$1

    if [ ! -d $dir/conf.d ]; then
        shu-err "No conf.d found under <$dir>"
        return 1
    fi

    local cases=`ls $dir/conf.d/case.*.cnf | awk -F'.' '{print $(NF-1)}' | sort -n`
    for c in $cases; do
        echo "Test $c:"
        shu_testing_clear
        source "$dir/conf.d/case.$c.cnf"
        echo "  Name: $name"
    done
}

function shu_testing_accept()
{
    local dir=$1
    local tests=$2

    if [ ! -d $dir/conf.d ]; then
        shu-err "No conf.d found under <$dir>"
        return 1
    fi

    local cases=`ls $dir/conf.d/case.*.cnf | awk -F'.' '{print $(NF-1)}' | sort -n`
    for c in $cases; do
        if shu-in-range $c $tests; then
            echo "Accept test $c."
            shu_testing_clear
            source "$dir/conf.d/case.$c.cnf"
            for pair in "${compare[@]}"; do
                dst="$dir/${pair%%:*}"
                src="${pair#*:}"
                if [ -d "$src" ]; then
                    mkdir -p "$dst"
                    if ls $src/* > /dev/null 2>&1; then
                        cp -r $src/* $dst
                    fi
                else
                    mkdir -p `dirname $dst`
                    cp $src $dst
                fi
            done
        fi
    done
}

function shu_testing_test()
{
    local dir=$1
    local tests=$2

    if [ ! -d $dir/conf.d ]; then
        shu-err "No conf.d found under <$dir>"
        return 1
    fi

    local failed=()
    local passed=()
    local cases=`ls $dir/conf.d/case.*.cnf | awk -F'.' '{print $(NF-1)}' | sort -n`
    local c=""
    for c in $cases; do
        if shu-in-range $c $tests; then
            shu_testing_clear
            source "$dir/conf.d/case.$c.cnf"
            echo "Test $c: $name"

            ( eval $before )
            ret=$?
            if [ $ret -ne 0 ]; then
                shu-err "Failed to run before script"
                shu-err "[ Failed ]"
                failed+=($c)
                continue
            fi

            ( eval $script )
            ret=$?
            if [ $ret -ne 0 ]; then
                shu-err "Failed to run script"
                shu-err "[ Failed ]"
                failed+=($c)
                continue
            fi


            local fail_one=0
            for pair in "${compare[@]}"; do
                local dst="$dir/${pair%%:*}"
                local src="${pair#*:}"
                if diff --exclude=.keep -r $src $dst; then
                    echo "[ OK ]"
                else
                    shu-err "[ Failed ]"
                    failed+=($c)
                    fail_one=1
                fi
            done

            if [ $fail_one -eq 0 ]; then
                passed+=($c)
            fi

            ( eval $after )
            ret=$?
            if [ $ret -ne 0 ]; then
                shu-err "Failed to run after script"
                shu-err "[ Failed ]"
                failed+=($c)
                continue
            fi
        fi
    done

    echo -e "\n\n\033[1mTest summary:\033[0m"
    echo -e "\033[01;33m Tests run: $(( ${#failed[@]} + ${#passed[@]} ))\033[0m"
    echo -e -n "\033[01;32m Passed ${#passed[@]}\033[0m"
    if [ ${#passed[@]} -gt 0 ]; then
        echo -n " - Tests: ${passed[@]}"
    fi
    echo ""

    echo -e -n "\033[01;31m Failed ${#failed[@]}\033[0m"
    if [ ${#failed[@]} -gt 0 ]; then
        echo -n " - Tests: ${failed[@]}"
    fi
    echo ""

    if [ ${#failed[@]} -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

shu_func_desc "shu-testing [new | accept | list | help] [dir] [tests]" "Diff based testing framework"
function shu-testing() 
{
    local cmd="shu_testing_test"
    local dir="test"
    local tests=""

    if [ $# -ge 1 ]; then
        case "$1" in
        new)
            cmd=shu_testing_new
            shift
            ;;
        accept)
            cmd=shu_testing_accept
            shift
            ;;
        list)
            cmd=shu_testing_list
            shift
            ;;
        help)
            shu_testing_help
            return 0
            ;;
        *) 
            ;;
        esac
    fi

    if [ $# -eq 1 ]; then
        if [ $cmd == "shu_testing_accept" -o $cmd == "shu_testing_test" ] \
            && shu-valid-range $1; then
            tests=$1
        else
            dir=$1
        fi
    elif [ $# -gt 1 ]; then
        dir=$1
        tests=$2
    fi

    ( eval $cmd $dir $tests )
    return $?
}

