#!/bin/bash

# hype.sh: lints, formats, documents, and tests php files.
# options:
# -i              : install hype.sh.
# -n              : lint file supplied with -f.
# -p              : format file supplied with -f.
# -d <output dir> : generate documentation to <output dir> for file -f.
# -t <test dir>   : run all unit test files in <test dir> for file -f.
# -r <repo>       : run config script to run options over all staged files in repo.
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
    any=false;
    file='';
    repo='';
    ddest='';
    tdest='';
    hype_opts='';
    while getopts ':[i]:[n]:[p]:d:t:f:r:' opt; do
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
        fi
    done
    
    valid_args=false;
    if [ "$f" = false ] && [ "$r" = false ] && [ "$x" = false ]; then
        echo "hype.sh error: a file path or repo path must be supplied to -f or -r option.";
    elif [ "$d" = true ] && [ -z "$ddest" ] && [ "$r" = false ]; then
        echo "hype.sh error: destination file path arg missing in -d option.";
    elif [ "$t" = true ] && [ -z "$tdest" ] && [ "$r" = false ]; then
        echo "hype.sh error: destination file path arg missing in -t option.";
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
            valid_deps=true;
            ini='/usr/local/etc/php/7.2/php.ini';
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
            if [ ! -f $ini ]; then
                valid_deps=false;
                echo "hype.sh error: php 7.2 must be installed with homebrew.";
            fi
            if [ "$valid_deps" = true ]; then
                # install phan.
                echo "hype.sh: installing phan...";
                # install php-ast extension.
                if [ -z "$( cat $ini | grep -E 'extension=ast.so' )" ]; then
                    git clone git@github.com:nikic/php-ast.git;
                    cd php-ast;
                    phpize;
                    ./configure --enable-ast;
                    make install;
                    cd .. && rm -rf php-ast;
                fi
                if [ -z "$( echo $PATH | grep -E '.composer/vendor/bin' )" ]; then
                    echo "hype.sh: enter the absolute path to your bash profile file.";
                    profile='';
                    while -z "$profile"; do
                        read REPLY;
                        profile=$( echo $REPLY );
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
                    # add composer global bin to PATH.
                    echo 'export PATH="'$HOME'/.composer/vendor/bin:$PATH"' >> $profile;
                fi
                if [ -z "$( command -v phan )" ]; then
                    # install phan composer package.
                    composer global require "phan/phan:2.x";
                    mkdir -p ~/.phan;
                    # add default phan config.
                    curl 'https://raw.githubusercontent.com/phan/phan/master/.phan/config.php' > ~/.phan/config.php;
                fi
                # install prettier.
                echo "hype.sh: installing prettier...";
                if [ -z "$( npm list -g --depth 0 | grep -E 'prettier' )" ]; then
                    npm install --global prettier @prettier/plugin-php;
                fi
                # install phrocco.
                echo "hype.sh: installing phrocco...";
                if [ -z "$( composer global show | grep -E 'phrocco' )" ]; then
                    composer global require rossriley/phrocco:dev-master;
                fi
                # make .hype project.
                echo "hype.sh: cloning hype repo...";
                git clone https://github.com/fyfinc/hype.git;
                mv hype ~/.hype;
                echo '#!/bin/bash' > ~/.hype/config.sh;
                # change exec modes.
                chmod +x ~/.hype/hype.sh;
                chmod +x ~/.hype/stage.sh;
                chmod +x ~/.hype/php_ini_fig.sh;
                chmod +x ~/.hype/config.sh;
                # add php-ast extension to php.ini.
                ~/.hype/php_ini_fig.sh -f $ini -i 'extension=ast.so';
                echo "hype.sh: finished installing hype.";
                echo "hype.sh: hype config file at ~/.hype/config.sh.";
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