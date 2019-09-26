#!/bin/bash

if [ ! -z ${HYPE_REPOS:+${HYPE_REPOS[@]}} ] && [ ! -z ${HYPE_REPO:+$HYPE_REPO} ] && [ ! -z ${HYPE_REPOS_DOC_PATHS:+${HYPE_REPOS_DOC_PATHS[@]}} ] && [ ! -z ${HYPE_REPOS_TEST_PATHS:+${HYPE_REPOS_TEST_PATHS[@]}} ]; then
    # find parallel array index.
    ri=-1;
    found=false;
    for e in ${HYPE_REPOS[@]}; do
        ri=$(( $ri + 1 ));
        e=$( basename $e );
        if [ "$e" = "$HYPE_REPO" ]; then
            found=true;
            break;
        fi
    done
    if [ "$found" = true ]; then
        if [ ! -z "$HYPE_OPTS" ]; then
            # process repo.
            rp=${HYPE_REPOS[$ri]};
            docs_op=${HYPE_REPOS_DOC_PATHS[$ri]};
            tests_op=${HYPE_REPOS_TEST_PATHS[$ri]};
            shd=~/.hype/stage.txt;
            cd $rp;
            git diff --name-only --cached > $shd;
            files=$( sed 's/^.\{1,\} \([A-Za-z0-9\-\.]\{1,\}\.php\)$/\1/p' < $shd);
            # lint files.
            echo "HYPE_OPTS: $HYPE_OPTS";
            if [ ! -z "$( echo $HYPE_OPTS | grep -qE 'n' )" ]; then
                echo "hype.sh: linting files...";
                for file in $files; do
                    ~/.hype/hype.sh -n -f $file;
                done
            fi
            # auto format files.
            if [ ! -z "$( echo $HYPE_OPTS | grep -qE 'p')" ]; then
                echo "hype.sh: formatting files...";
                for file in $files; do
                    ~/.hype/hype.sh -p -f $file;
                done
            fi
            # document files.
            if [ ! -z "$( echo $HYPE_OPTS | grep -qE 'd' )" ]; then
                echo "hype.sh: documenting files...";
                for file in $files; do
                    ~/.hype/hype.sh -d $docs_op -f $file;
                done;
            fi
            # unit test files.
            if [ ! -z "$( echo $HYPE_OPTS | grep -qE 't' )" ]; then
                echo "hype.sh: unit testing files...";
                for file in $files; do
                    ~/.hype/hype.sh -t $tests_op -f $file;
                done;
            fi
            rm $shd;
        else
            echo "hype.sh error: missing options/args.";
        fi
    else
        echo "hype.sh error: no repo found in config file.";
    fi
else
    echo "hype.sh error: missing repo some or all config info.";
fi