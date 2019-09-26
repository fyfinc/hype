#!/bin/bash

# hype.sh: lints, formats, documents, and tests php files.
# options:
# -i              : install hype.sh: working dir must be inside repo dir.
# -n              : lint file supplied with -f.
# -p              : format file supplied with -f.
# -d <output dir> : generate documentation to <output dir> for file -f.
# -t <test dir>   : run all unit test files in <test dir> for file -f.
# -r <repo>       : run config script to run options over all staged files in repo.
# -c <cmd>        : edit config: <cmd> is either "show", "add", or "delete".
#
# ~/.hype/config.sh is the config bash script. All it does is map repo names with
# their paths and then scans the given repo's staged php files and runs the supplied
# options over each php file. It does this by scanning the -f file for @docpath and
# @testpath directives, where each is followed by a path that is extracted and used.
# config.sh works by calling hype.sh for each staged php file.
#
# ~/.hype must also contain php_ini_fig.sh which is used to insert ini directives in
# a given php.ini file.

(
    i=false;
    n=false;
    p=false;
    d=false;
    t=false;
    f=false;
    r=false;
    c=false;
    any=false;
    file='';
    repo='';
    ddest='';
    tdest='';
    hype_opts='';
    while getopts ':[i]:[n]:[p]:d:t:f:r:c:' opt; do
        hype_opts="$hype_opts$opt";
        if [ $opt = 'i' ]; then
            i=true;
            any=true;
        elif [ $opt = 'n' ]; then
            n=true;
            any=true;
        elif [ $opt = 'p' ]; then
            p=true;
            any=true;
        elif [ $opt = 'd' ]; then
            ddest=$( echo $OPTARG );
            d=true;
            any=true;
        elif [ $opt = 't' ]; then
            tdest=$( echo $OPTARG );
            t=true;
            any=true;
        elif [ $opt = 'f' ]; then
            f=true;
            file=$( echo $OPTARG );
        elif [ $opt = 'r' ]; then
            r=true;
            repo=$( echo $OPTARG );
        elif [ $opt = 'c' ]; then
            c=true;
            fig=$( echo $OPTARG );
            any=true;
        fi
    done
    
    valid_args=false;
    if [ "$f" = false ] && [ "$i" = false ] && [ "$c" = false ]; then
        echo "hype.sh error: a file path or repo path must be supplied to -f or -r option.";
    elif [ "$d" = true ] && [ -z "$ddest" ] && [ "$r" = false ]; then
        echo "hype.sh error: destination file path arg missing in -d option.";
    elif [ "$t" = true ] && [ -z "$tdest" ] && [ "$r" = false ]; then
        echo "hype.sh error: destination file path arg missing in -t option.";
    elif [ "$c" = true ] && [ -z "$fig" ]; then
        echo "hype.sh error: -c arg value missing.";
    elif [ $any = false ]; then
        echo "hype.sh error: -npdta option(s) must be supplied.";
    elif [ "$f" = true ] && [ ! -f $file ]; then
        echo "hype.sh error: -f arg file path does not exist.";
    elif [ "$i" = true ]; then
        echo "hype.sh: installing hype...";
        valid_args=true;
    else
        echo "hype.sh: begin processing...";
        valid_args=true;
    fi
    if [ "$valid_args" = true ]; then
        if [ "$i" = true ]; then
            # start installation.
            wd=$( pwd );
            valid_deps=true;
            # homebrew: /usr/local/etc/php/7.2/php.ini
            ini=$( php -r 'phpinfo();' | sed -n 's/.\{1,\} \([a-z\/0-9\.]\{1,\}php\.ini\)/\1/p' );
            ini=${ini/ /''};
            if [ -z "$( command -v composer )" ]; then
                valid_deps=false;
                echo "hype.sh error: composer is required to install hype.";
            fi
            if [ -z "$( php -v | grep -E '7.2' )" ]; then
                valid_deps=false;
                echo "hype.sh error: PHP 7.2 is required to install hype.";
            fi
            if [ -z "$( command -v npm )" ]; then
                valid_deps=false;
                echo "hype.sh error: npm is required to install hype.";
            fi
            if [ -z "$( command -v gem )" ]; then
                valid_deps=false;
                echo "hype.sh error: gem is required to install hype.";
            fi
            # confirm php.ini.
            inidos='';
            echo "hype.sh: is your php.ini at: $ini (y/n)?";
            read REPLY;
            reply=$( echo $REPLY );
            if [ "$reply" = 'n' ]; then
                while [ -z "$inidos" ]; do
                    echo "hype.sh: enter absolute path to your php.ini file:";
                    read REPLY;
                    inidos=$( echo $REPLY );
                    if [ -z "$inidos" ]; then
                        echo "hyper.sh error: please try again.";
                        inidos='';
                    elif [ ! -f $inidos ]; then
                        echo "hype.sh error: ini file not found. Try again:";
                        inidos='';
                    fi
                done
            else
                inidos=$ini;
            fi
            ini=$inidos;
            echo "hype.sh: enter the name of your bash profile e.g. .profile.";
            # confirm bash profile.
            profile='';
            while [ -z "$profile" ]; do
                read REPLY;
                profile=$( echo $REPLY );
                profile="$HOME/$profile";
                if [ -z "$profile" ]; then
                    profile='';
                    echo "hype.sh error: please try again.";
                elif [ ! -f $profile ]; then
                    profile='';
                    echo "hype.sh error: unable to find profile. Please try agian.";
                else
                    break;
                fi
            done
            if [ "$valid_deps" = true ]; then
                # install php-ast extension.
                if [ -z "$( cat $ini | grep -qE 'ast.so' )" ]; then
                    echo "hype.sh: installing phan...";
                    git clone git@github.com:nikic/php-ast.git;
                    cd php-ast;
                    phpize;
                    ./configure --enable-ast;
                    make install;
                    cd .. && rm -rf php-ast;
                    # add php-ast extension to php.ini.
                    ./php_ini_fig.sh -f $ini -i 'extension=ast.so';
                fi
                if [ -z "$( echo $PATH | grep -qE '.composer/vendor/bin' )" ]; then
                    # add composer global bin to PATH.
                    echo "hype.sh: adding composer bin to PATH...";
                    echo 'export PATH="'$HOME'/.composer/vendor/bin:$PATH"' >> $profile;
                fi
                # install phan composer package.
                if [ -z "$( command -v phan )" ]; then
                    echo "hype.sh: installing phan...";
                    composer global require "phan/phan:2.x";
                    mkdir -p ~/.phan;
                    # add default phan config.
                    curl 'https://raw.githubusercontent.com/phan/phan/master/.phan/config.php' > ~/.phan/config.php;
                fi
                # install prettier.
                if [ -z "$( npm list -g --depth 0 | grep -qE 'prettier' )" ]; then
                    echo "hype.sh: installing prettier...";
                    sudo npm install --global prettier @prettier/plugin-php;
                fi
                # install phrocco.
                if [ -z "$( composer global show | grep -qE 'phrocco' )" ]; then
                    echo "hype.sh: installing phrocco...";
                    composer global require rossriley/phrocco:dev-master;
                fi
                # make .hype project.
                echo '#!/bin/bash' > ./config.sh;
                # change exec modes.
                chmod +x ./hype.sh;
                chmod +x ./stage.sh;
                chmod +x ./php_ini_fig.sh;
                chmod +x ./config.sh;
                cp -R . ~/.hype;
                if [ -z "$( cat $profile | grep -E 'alias hype' )" ]; then
                    echo 'alias hype=~/.hype/hype.sh' >> $profile;
                fi
                echo "hype.sh: finished installing hype.";
                echo "hype.sh: hype config file at ~/.hype/config.sh.";
            fi
        elif [ "$c" = true ]; then
            source ~/.hype/config.sh;
            declare -a HYPE_REPOS=(${HYPE_REPOS[@]});
            declare -a HYPE_REPOS_DOC_PATHS=(${HYPE_REPOS_DOC_PATHS[@]});
            declare -a HYPE_REPOS_TEST_PATHS=(${HYPE_REPOS_TEST_PATHS[@]});
            len=${#HYPE_REPOS[@]};
            fig () {(
                repos=(${1/:/' '});
                docs=(${2/:/' '});
                units=(${3/:/' '});
                bang='#!/bin/bash';
                repo_config="export HYPE_REPOS=(${repos[@]});";
                doc_config="export HYPE_REPOS_DOC_PATHS=(${docs[@]});";
                unit_config="export HYPE_REPOS_TEST_PATHS=(${units[@]});";
                echo $bang > ~/.hype/config.sh;
                echo $repo_config >>  ~/.hype/config.sh;
                echo $doc_config >>  ~/.hype/config.sh;
                echo $unit_config >>  ~/.hype/config.sh;
                chmod +x  ~/.hype/config.sh;
            )}
            if [ "$fig" = 'add' ]; then
                stop=false;
                declare -a repo_list;
                declare -a doc_list;
                declare -a test_list;
                i=0;
                while [ "$stop" = false ]; do
                    # collect repo path.
                    echo "hype.sh: enter absolute repo path:";
                    read REPLY;
                    repo=$( echo $REPLY );
                    if [ -z "$repo" ]; then
                        echo "hype.sh error: please try again.";
                    elif [ ! -d $repo ]; then
                        echo "hype.sh error: repo directory not found.";
                    else
                        repo_list[$i]=$repo;
                    fi
                    # collect repo doc path.
                    
                    echo "hype.sh: enter absolute repo docs path:";
                    read REPLY;
                    doc=$( echo $REPLY );
                    if [ -z "$doc" ]; then
                        echo "hype.sh error: please try again.";
                    elif [ ! -d $doc ]; then
                        echo "hype.sh error: repo docs directory not found.";
                    else
                        doc_list[$i]=$doc;
                    fi
                    echo "hype.sh: enter absolute repo tests path:";
                    read REPLY;
                    unit=$( echo $REPLY );
                    if [ -z "$unit" ]; then
                        echo "hype.sh error: please try again.";
                    elif [ ! -d $unit ]; then
                        echo "hype.sh error: repo tests directory not found.";
                    else
                        repo_list[$i]=$unit;
                    fi
                    echo "hype.sh: is [repo=$repo][docs=$doc][tests=$unit] correct? (y/n)";
                    read REPLY;
                    confirm=$( echo $REPLY );
                    if [ "$confirm" = 'y' ]; then
                        HYPE_REPOS[$len]=$repo;
                        HYPE_REPOS_DOC_PATHS[$len]=$doc;
                        HYPE_REPOS_TEST_PATHS[$len]=$unit;
                        echo "hype.sh: add another repo config? (y/n)";
                        read REPLY;
                        another=$( echo $REPLY );
                        if [ "$another" = 'n' ]; then
                            # rebuild config file.
                            stop=true;
                            repos=${HYPE_REPOS[@]};
                            docs=${HYPE_REPOS_DOC_PATHS[@]};
                            units=${HYPE_REPOS_TEST_PATHS[@]};
                            fig ${repos/ /:} ${docs/ /:} ${units/ /:};
                        fi
                    fi
                    i=$(( $i + 1 ));
                done
                echo "hype.sh: done.";
            elif [ "$fig" = 'show' ]; then
                if [[ $len > 0 ]]; then
                    i=0;
                    echo "repo configs:";
                    for config in $HYPE_REPOS; do
                        echo "#$i - [repo=${HYPE_REPOS[$i]}][docs=${HYPE_REPOS_DOC_PATHS[$i]}][tests=${HYPE_REPOS_TEST_PATHS[$i]}]";
                        i=$(( $i + 1 ));
                    done
                else
                    echo "hype.sh: you have no repos.";
                fi
                echo "hype.sh: done.";
            elif [ "$fig" = 'delete' ]; then
                if [[ $len > 0 ]]; then
                    for config in $HYPE_REPOS; do
                        echo "#$i - [repo=${HYPE_REPOS[$i]}][docs=${HYPE_REPOS_DOC_PATHS[$i]}][tests=${HYPE_REPOS_TEST_PATHS[$i]}]";
                        echo "hype.sh: delete? (y/n)";
                        read REPLY;
                        confirm=$( echo $REPLY );
                        if [ "$confirm" = 'y' ]; then
                            unset HYPE_REPOS[$i];
                            unset HYPE_REPOS_DOC_PATHS[$i];
                            unset HYPE_REPOS_TEST_PATHS[$i];
                        fi
                    done
                    repos=${HYPE_REPOS[@]};
                    docs=${HYPE_REPOS_DOC_PATHS[@]};
                    units=${HYPE_REPOS_TEST_PATHS[@]};
                    fig ${repos/ /:} ${docs/ /:} ${units/ /:};
                else
                    echo "hype.sh: you have no repos.";
                fi
                echo "hype.sh: done.";
            fi
        else
            if [ -f ~/.hype/config.sh ]; then
                export HYPE_OPTS=$hype_opts;
                export HYPE_REPO=$repo;
                if [ "$r" = true ]; then
                    # run config script.
                    source ~/.hype/config.sh;
                    source ~/.hype/stage.sh;
                elif [ "$r" = false ]; then
                    # run manual command.
                    if [ "$n" = true ] && [ "$f" = true ]; then
                        echo "Analyzing $file...";
                        phan -f $file;
                    fi
                    echo "hype: continue (y/n)?";
                    read REPLY;
                    reply=$( echo $REPLY );
                    if [ "$reply" = "y" ]; then
                        # prettify file.
                        if [ "$p" = true ] && [ "$f" = true ]; then
                            echo "Prettifying $file...";
                            prettier $file --write;
                        fi
                        # document file.
                        if [ "$d" = true ] && [ "$f" = true ]; then
                            echo "Documenting $file...";
                            tmpdir=~/.hype/copies/$( md5 -q $file );
                            rm -rf $tmpdir && mkdir -p $tmpdir;
                            tmpfile=$tmpdir/$( basename $file );
                            cp -f $file $tmpfile;
                            phrocco -i $tmpdir -o $ddest;
                            rm -rf $tmpdir;
                        fi
                        # unit test file.
                        if [ "$t" = true ] && [ "$f" = true ]; then
                            echo "Unit testing $file...";
                            tmpdir=~/.hype/tests/$( md5 -q $file );
                            rm -rf $tmpdir && mkdir -p $tmpdir;
                            units=$( ls $tdest );
                            for unit in $units; do
                                echo "Running $unit...";
                                php $tdest/$unit > $tmpdir/$unit;
                                echo "Save results (yes/no/show)?";
                                reply='';
                                while -z "$reply"; do
                                    read REPLY;
                                    reply=$( echo $REPLY );
                                    if [ "$reply" = "yes" ]; then
                                        echo "Test log saved at $tmpdir/$unit.";
                                    elif [ "$reply" = "no" ]; then
                                        rm $tmpdir/$unit;
                                        echo "$tmpdir/$unit log deleted.";
                                    elif [ "$reply" = "show" ]; then
                                        echo "Showing log $tmpdir/$unit.";
                                        cat $tmpdir/$unit;
                                        reply='';
                                    else
                                        echo "Please try again.";
                                        reply='';
                                    fi
                                done
                            done
                        fi
                    else
                        echo "hype.sh: aborting...";
                    fi
                fi
            else
                echo "hype.sh error: you have not installed hype yet. Please use -i option.";
            fi
        fi
    fi
)