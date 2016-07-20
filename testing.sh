#!/usr/bin/env bash

function shu_testing_help()
{
    echo "shu-testing [dir] [cases]: Run tests"
    echo "shu-testing new [dir]: Create a new test site"
    echo "shu-testing list [dir] [cases]: List cases"
    echo "shu-testing accept [dir] [cases]: Accept build: overwrite expected files with build files"
    echo "shu-testing add [dir] [case]: Add a new case"
    echo "shu-testing del [dir] [case]: Delete a case"
    echo "  default <dir>: ./tests"
    echo "  empty <cases> denotes all cases "
}

shopt -s expand_aliases
alias shu_testing_clear='local name=""; local before=""; local script=""; local after=""; local compare=(); local normalize=""; local compare_normalize=(); export SHU_CASE=$c'

function shu_testing_new()
{
    local dir=$1

    mkdir -p $dir
    mkdir -p $dir/expected
    mkdir -p $dir/conf.d

    cat <<-EOF > "$dir/conf.d/case.1.cnf"
name="First Case"                    # name of this test case
before="mkdir -p output"             # script run before testing script
script="echo "\$name \$SHU_CASE" > output/1.txt"   # testing script
after="echo Finish"                  # script run after compare
compare=("expected/:output/")        # files to be compared, each pair separated by a colon

normalize=""                         # scripte used to normalize files in <compare_normalize> before compare
compare_normalize=()                 # files to be compared after nomalize, each pair separated by a colon
EOF
}

function shu_testing_list()
{
    local dir=$1

    if [ ! -d $dir/conf.d ]; then
        shu-err "No conf.d found under <$dir>"
        return 1
    fi

    local all_cases=`ls $dir/conf.d/case.*.cnf | awk -F'.' '{print $(NF-1)}' | sort -n`
    for c in $all_cases; do
        echo "Test $c:"
        shu_testing_clear
        source "$dir/conf.d/case.$c.cnf"
        echo "  Name: $name"
    done
}

function shu_testing_accept()
{
    local dir=$1
    local cases=$2

    if [ ! -d $dir/conf.d ]; then
        shu-err "No conf.d found under <$dir>"
        return 1
    fi

    local all_cases=`ls $dir/conf.d/case.*.cnf | awk -F'.' '{print $(NF-1)}' | sort -n`
    for c in $all_cases; do
        if shu-in-range $c $cases; then
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

            for pair in "${compare_normalize[@]}"; do
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
    local cases=$2

    if [ ! -d $dir/conf.d ]; then
        shu-err "No conf.d found under <$dir>"
        return 1
    fi

    local ret=0
    local setup=""
    local cleanup=""
    if [ -e $dir/conf.d/common.cnf ]; then
        source "$dir/conf.d/common.cnf"

        if [ -n "$setup" ]; then
          echo "Setting up..."
          ( eval $setup )
          ret=$?
          if [ $ret -ne 0 ]; then
              shu-err "Failed to run setup script"
              shu-err "[ Failed ]"
              return $ret
          fi
        fi
    fi

    local failed=()
    local passed=()
    local all_cases=`ls $dir/conf.d/case.*.cnf | awk -F'.' '{print $(NF-1)}' | sort -n`
    local c=""
    for c in $all_cases; do
        if shu-in-range $c $cases; then
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
                if ! diff --exclude=.keep -r $src $dst; then
                    fail_one=1
                fi
            done

            for pair in "${compare_normalize[@]}"; do
                local dst="$dir/${pair%%:*}"
                local src="${pair#*:}"
                if [ -d "$src" ] || [ -d "$dst" ]; then
                    shu-err "compare_normlize can not be directory: $src"
                    fail_one=1
                    continue
                fi

                local tmp_src=/tmp/${src##*/}_norm_src
                local tmp_dst=/tmp/${dst##*/}_norm_dst

                ( eval "$normalize < $src > $tmp_src" )
                ret=$?
                if [ $ret -ne 0 ]; then
                    shu-err "Failed to normlize $src"
                    fail_one=1
                    continue
                fi

                ( eval "$normalize < $dst > $tmp_dst" )
                ret=$?
                if [ $ret -ne 0 ]; then
                    shu-err "Failed to normlize $dst"
                    fail_one=1
                    continue
                fi

                if ! diff $tmp_src $tmp_dst; then
                    fail_one=1
                fi
            done

            ( eval $after )
            ret=$?
            if [ $ret -ne 0 ]; then
                shu-err "Failed to run after script"
                shu-err "[ Failed ]"
                failed+=($c)
                continue
            fi

            if [ $fail_one -eq 0 ]; then
                echo "[ OK ]"
                passed+=($c)
            else
                shu-err "[ Failed ]"
                failed+=($c)
            fi

        fi
    done

    if [ -e $dir/conf.d/common.cnf ]; then
        if [ -n "$cleanup" ]; then
          echo "Cleaning up..."
          ( eval $cleanup )
          ret=$?
          if [ $ret -ne 0 ]; then
              shu-err "Failed to run cleanup script"
              return $ret
          fi
        fi
    fi

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

function shu_testing_add()
{
    local dir=$1
    local case=$2

    if [ -n "$case" ]; then
      if ! echo $case | egrep '^[0-9]+$' &> /dev/null ; then
          shu-err "<case> must be one integer."
          return 1
      fi
    fi

    if [ ! -d $dir/conf.d ]; then
      shu-err "No conf.d found under <$dir>"
      return 1
    fi

    local all_cases=`ls $dir/conf.d/case.*.cnf | awk -F'.' '{print $(NF-1)}' | sort -rn`
    if [ -z "$case" ]; then
      case=`echo $all_cases | awk '{print $1}'`
      case=$((case+1))
    fi
    for c in $all_cases; do
      if [ $c -ge $case ]; then
        # expecteds
        from=()
        shu_testing_clear
        source "$dir/conf.d/case.$c.cnf"
        for pair in "${compare[@]}"; do
          from+=($dir/${pair%%:*})
        done
        for pair in "${compare_normalize[@]}"; do
          from+=($dir/${pair%%:*})
        done

        to=()
        c=$((c+1))
        shu_testing_clear
        source "$dir/conf.d/case.$((c-1)).cnf"
        for pair in "${compare[@]}"; do
          to+=($dir/${pair%%:*})
        done
        for pair in "${compare_normalize[@]}"; do
          to+=($dir/${pair%%:*})
        done

        for i in `seq 0 $((${#from[*]} - 1))`; do
          src=${from[$i]}
          dst=${to[$i]}
          echo "Moving $src -> $dst"
          if [ "$src" != "$dst" ] && [ -e "$src" ]; then
            if [ -d "$src" ]; then
              mkdir -p "$dst"
              if ls $src/* > /dev/null 2>&1; then
                  mv -r $src/* $dst
              fi
            else
              mkdir -p `dirname $dst`
              mv $src $dst
            fi
          fi
        done
        c=$((c-1))

        src="$dir/conf.d/case.$c.cnf"
        dst="$dir/conf.d/case.$((c+1)).cnf"
        echo "Moving $src -> $dst"
        shu-run "mv $src $dst"  || return 1
      fi
    done
    touch "$dir/conf.d/case.$case.cnf"
    echo -e "Case \033[1m$case\033[0m created under $dir/conf.d/case.$case/cnf."
}

function shu_testing_del()
{
    local dir=$1
    local case=$2

    if [ -n "$case" ]; then
      if ! echo $case | egrep '^[0-9]+$' &> /dev/null ; then
          shu-err "<case> must be one integer."
          return 1
      fi
    fi

    if [ ! -d $dir/conf.d ]; then
      shu-err "No conf.d found under <$dir>"
      return 1
    fi

    local all_cases=`ls $dir/conf.d/case.*.cnf | awk -F'.' '{print $(NF-1)}' | sort -n`
    if [ -z "$case" ]; then
      case=`echo $all_cases | awk '{print $NF}'`
    fi
    found=false
    for c in $all_cases; do
      if [ $c -eq $case ]; then
        shu-run rm "$dir/conf.d/case.$c.cnf" || return 1
        echo -e "Case \033[1m$case\033[0m deleted."
        found=true
      fi
      if [ $c -gt $case ]; then
        # expecteds
        from=()
        shu_testing_clear
        source "$dir/conf.d/case.$c.cnf"
        for pair in "${compare[@]}"; do
          from+=($dir/${pair%%:*})
        done
        for pair in "${compare_normalize[@]}"; do
          from+=($dir/${pair%%:*})
        done

        to=()
        c=$((c-1))
        shu_testing_clear
        source "$dir/conf.d/case.$((c+1)).cnf"
        for pair in "${compare[@]}"; do
          to+=($dir/${pair%%:*})
        done
        for pair in "${compare_normalize[@]}"; do
          to+=($dir/${pair%%:*})
        done

        for i in `seq 0 $((${#from[*]} - 1))`; do
          src=${from[$i]}
          dst=${to[$i]}
          echo "Moving $src -> $dst"
          if [ "$src" != "$dst" ] && [ -e "$src" ]; then
            if [ -d "$src" ]; then
              mkdir -p "$dst"
              if ls $src/* > /dev/null 2>&1; then
                  mv -r $src/* $dst
              fi
            else
              mkdir -p `dirname $dst`
              mv $src $dst
            fi
          fi
        done
        c=$((c+1))

        src="$dir/conf.d/case.$c.cnf"
        dst="$dir/conf.d/case.$((c-1)).cnf"
        echo "Moving $src -> $dst"
        shu-run "mv $src $dst"  || return 1
      fi
    done
    if ! $found; then
      shu-err "No Case $case founded."
    fi
}

shu_func_desc "shu-testing [new | accept | list | add | help] [dir] [test(s)]" "Diff based testing framework"
function shu-testing()
{
    local cmd="shu_testing_test"
    local dir="test"
    local cases=""

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
        add)
            cmd=shu_testing_add
            shift
            ;;
        del)
            cmd=shu_testing_del
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
        if [ $cmd == "shu_testing_accept" -o $cmd == "shu_testing_test" \
             -o $cmd == "shu_testing_add" -o $cmd == "shu_testing_del" ] \
            && shu-valid-range $1; then
            cases=$1
        else
            dir=$1
        fi
    elif [ $# -gt 1 ]; then
        dir=$1
        cases=$2
    fi

    ( eval $cmd $dir $cases )
    return $?
}
