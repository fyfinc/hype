#!/bin/bash

# php_ini_fig.sh accepts php.ini directive key/value pairs and configures given php.ini file.
# options:
# -i <'directive_name@anchor=value'> (repeatable option).
# -s <'@anchor=section'> anchor is a spot under a ini section to put directives. An
#    anchor can be referenced by an -i option 1+ times and if an anchor ref has the
#    same name as its section then no explicit -s option for it is necessary. -s options
#    must come before they are referenced.
# -f <path/to/php.ini>
# -c This option is not a CLI option and is substituted when -p is not supplied. -c is
#    used to prompt the user for the path to copy their php.ini.
# -p <path/to/copypasta> php.ini file without prompt.
# ex: php_ini_fig -f ~/php.ini -i 'short_open_tag@achor1="On"' -i 'expose_php@anchor2="Off"'

(
	declare -a ds;
	declare -a vs;
	declare -i i;
	declare -A as=();
	declare -A ss=();
	declare -A sal=();
	declare -A sections=( [extensions]="; Dynamic Extensions ;" [misc]="; Miscellaneous ;" );
	i=0;
	s=0;
	work='';
	backup='';
	error='';
	iopt=''; sopt=''; fopt=''; copt=''; popt='';
	implode () {(
		delimiter=$1;
		arr=$2;
		rex=$( echo $arr | awk -v d=$delimiter '{record = $0; gsub(" ", d, record); print "(" record ")";}' );
		rex=${rex//()/'^$'};
		echo $rex;
	)}
	refar () {(
		seg=$1;
		input=$2;
		declare -A segs=( [dir]="1" [anchor]="3" [val]="5" );
		cap=${segs[$seg]};
		val=$( echo $input | sed 's/\([a-zA-Z_\.0-9]\{0,\}\)\{0,1\}\(@\)\([a-zA-Z_\.0-9]\{0,\}\)\{1\}\(=\)\{1\}\([a-zA-Z_\.0-9]\{0,\}\)\{1\}/\'$cap'/g' );
		echo $val;
	)}
	sector () {(
		seg=$1;
		input=$2;
		declare -A segs=( [anchor]="2" [section]="4" );
		cap=${segs[$seg]};
		val=$( echo $input | sed 's/\(@\)\{1\}\([a-zA-Z_\.0-9]\{0,\}\)\{1\}\(=\)\([a-zA-Z_\.0-9]\{0,\}\)\{1\}/\'$cap'/g' );
		echo $val;
	)}
	while getopts ':i:s:f:p:' opt; do
		val=$OPTARG;
		# remove spaces.
		val=${val// /};
		# check is -s val isn't empty, follows syntax, and doesn't belong already to the given section.
		sed_anchor=$( refar 'anchor' "$val" );
		sed_section=$( sector 'section' "$val" );
		echo stop;
		if [ "$opt" = "s" ]; then
			if [ ! -z "$val" ] && [ ! -z "$sed_anchor" ]; then
				sopt='s';
				# collect anchor.
				anchor=$sed_anchor;
				section=$sed_section;
				rex=$( implode '|' "${as[$section]}" );
				is_old_anchor=$( echo $sed_anchor | egrep $rex );
				echo stop;
				if [ -z "$section" ]; then
					section=$anchor;
				fi
				if [ -z "$is_old_anchor" ]; then
					# add anchor to config.
					as[$section]=${as[$section]:+$anchor};
					ss[$section]=$( echo "${as[$section]} $achor" );
					sal[$anchor]=$section;
				fi
				echo stop;
			else
				error="Error: invalid $opt option or invalid $val value.";
				break;
			fi
		elif [ "$opt" = "i" ]; then
			if [ ! -z "$val" ] && [ ! -z "$( echo $val | grep '=' )" ]; then
				iopt='i';
				# find anchor.
				anchor=$sed_anchor;
				rex=$( implode '|' "${as[$section]}" );
				is_old_anchor=$( echo $sed_anchor | egrep $rex );
				if [[ ${#sal[@]} > 0 ]] && [ -v ${sal[$anchor]} ] && [ -z "$is_old_anchor" ]; then
					# -s option omitted: add anchor to config.
					section=${sal[$anchor]};
					as[$section]=${as[$section]:+$anchor};
					ss[$section]=$( echo "${as[$section]} $anchor" );
				fi
				echo stop;
				# escape forward slashes (e.g. path slahes) in $val.
				val=$( echo $val | sed 's|\(/\)|\\\/|g' );
				# collect directive name.
				ds[$i]=$( refar 'dir' $val );
				# collect directive value.
				vs[$i]=$( refar 'val' $val );
				i=$(( $i + 1 ));
				# escape dots in directive name.
				if [ $( echo ${ds[$i]} | egrep -i '[\.]' ) ] && ! [ $( echo ${ds[$i]} | egrep -i '\\' ) ]; then
					ds[$i]=$( sed 's/\(\.\)/\\./g' <<< ${ds[$i]} );
				fi
				# directive values don't further escaping.
			else
				error="Error: invalid $opt option or invalid $val value.";
				break;
			fi
		elif [[ "$opt" = "f" ]]; then
			if [ ! -z "$val" ]; then
				fopt='f';
				work=$val;
				work=$( eval 'echo $(dirname '$work' )''/''$(basename '$work' )');
			else
				error="Error: invalid $opt option or file not found.";
				break;
			fi
		elif [[ "$opt" = "p" ]]; then
			if [ ! -z "$val" ]; then
				popt='p';
				backup=$val;
				backup=$( sed 's|^\(.\{1,\}\)\(/\)$|\1|g' <<< $backup );
				backup=$( eval 'cd '$backup'; pwd;' );
				backup=$val;
			else
				backup="Error: invalid $opt option or file not found.";
				break;
			fi
		fi
	done
	echo stop;
	optlist="$iopt$sopt$fopt$popt";
	# if no errors and all required opts given.
	if [ -z "$( echo $optlist | egrep 'c' )" ]; then
		optlist="c$optlist";
		copt='c';
		while [ -z "$backup" ]; do
			echo "php_ini_fig.sh: what directory should php.ini be backed up to:";
			read REPLY;
			backup=${REPLY// /};
			backup=$( sed 's|^\(.\{1,\}\)\(/\)$|\1|g' <<< $backup );
			backup=$( eval 'cd '$backup'; pwd;' );
			if [[ $( dirname $work ) = $( echo $backup ) ]]; then
				echo "php_ini_fig.sh: working php.ini dir cannot be the same as backup dir! try again.";
				backup='';
			fi
		done
	fi
	if [ -z "$error" ] && [ ! -z $( echo $optlist | egrep '^[isf(c|p)]{4}$' ) ]; then
		# backup ini.
		backup="$backup/php.ini";
		cp $work $backup;
		# swap files.
		read bw <<< $work && read wb <<< $backup;
		work=$wb;
		backup=$bw;
		# add anchors to ini.
		echo stop;
		for section in ${!ss[@]}; do
			declare -a anchors;
			declare -a findnkeep;
			ln=$( read d <<< $( grep -n "${sections[$section]}" $file ) && cut -f1 -d $d );
			if [ ! -z "$ln" ]; then
				anchors=(${ss[$section]});
				for k in ${!anchors[@]}; do
					anchor=${anchors[$k]};
					nxt=$(( ${nxt:-ln} + 2 ));
					awk -v ln=$ln -v anchor=$anchor 'if (NR == ln) {print ""; print "; @",anchor;}' $work > $work;
					findnkeep[$anchor]=$section;
				done
			fi
		done
		for ((i=0; i < ${#ds[@]}; i++)); do
			# line cursor for each section.
			d=${ds[$i]};
			v=${vs[$i]};
			# find achor ref.
			anchor=$( refar 'anchor' $d );
			if [ -v ${findnkeep[$anchor]} ]; then
				# remove anchor ref from directive.
				d=$( refar 'ref' $d );
				# find anchor line num.
				ln=$( read d <<< $( grep -n "@$anchor" $work ) && cut -f1 -d $d );
				patnosemi="^;{0}$d( ){0,}=.{0,}$";
				patsemi="^;$d( ){0,}=.{0,}$";
				before=$( md5 $work );
				# try to replace existing dir.
				awk -v ln=$ln -v dir=$d -v val=$v '{ print $1,$NF; if ($0 ~ patnosemi) { print dir " = " val; } else if ($0 ~ patsemi) { print dir " = " val; } }' $work > $work;
				after=$( md5 $work );
				if [[ "$before" = "$after" ]]; then
					# dir is new: apply under anchor.
					 awk -v dir="$d" -v val="$v" -v pat="@$anchor" '{ print $1,$NF; if ($0 ~ pat) {Dir = dir " = " val; print ""; print Dir;} }' $work > $work;
				fi
			fi
		done
		# unswap files.
		if [ ! -z "$copt" ]; then
			echo "php_ini_fig.sh: ini changes complete. Use backup? (y/n)";
			read reply;
			reply=${reply// /};
			if [[ "$reply" = 'y' ]]; then
				# replace ini.
				tw=/tmp/hype/work.php.ini;
				tb=/tmp/type/backup.php.ini;
				cat $work > $tw;
				cat $backup > $tb;
				cat $tw > $backup;
				cat $tb > $work;
				rm $tw && rm $tb;
				echo "php_ini_fig.sh: original php.ini at $work.";
			else
				echo "php_ini_fig.sh: changed php.ini at $work.";	
			fi
		else
			# replace ini.
			cat $work > $backup;
			echo "php_ini_fig.sh: original php.ini at $work.";
		fi
	else
		if [ ! -z "$error" ]; then
			echo "php_ini_fig.sh: $error";
		else
			echo "php_ini_fig.sh: invalid -$optlist options given.";
		fi
	fi
)