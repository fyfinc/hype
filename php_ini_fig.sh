#!/bin/bash

# php_ini_fig.sh accepts php.ini directive key/value pairs and configures given php.ini file.
# options:
# -i 'directive_name=value' (repeatable option).
# -f path/to/php.ini
# ex: php_ini_fig -f ~/php.ini -i 'short_open_tag="On"' -i 'expose_php="Off"'

(
	declare -a ds;
	declare -a vs;
	declare -i i;
	i=0;
	file='';
	error='';
	while getopts ':i:f:' opt; do
		val="$OPTARG";
		# trim val.
		val=$( echo $val );
		if [ "$opt" = "i" ] && ! [ -z "$val" ] && [ $( echo $val | grep '=' ) ]; then
			# escape forward slashes (e.g. path slahes) in $val.
			val=$( sed 's|\(/\)|\\\/|g' <<< $val );
			# collect directive name.
			ds[$i]=$( sed 's/^\([a-zA-Z_\.0-9]\{1,\}\)[^ ]\{0\}\=[^ ]\{0\}.\{1,\}$/\1/g' <<< $val );
			# collect directive value.
			vs[$i]=$( sed 's/^[a-zA-Z_\.0-9]\{1,\}[^ ]\{0\}\=[^ ]\{0\}\(.\{1,\}\)$/\1/g' <<< $val );
			i=$(( $i + 1 ));
			# escape dots in directive name.
			if [ $( echo ${ds[$i]} | egrep -i '[\.]' ) ] && ! [ $( echo ${ds[$i]} | egrep -i '\\' ) ]; then
				ds[$i]=$( sed 's/\(\.\)/\\./g' <<< ${ds[$i]} );
			fi
			# directive values don't further escaping.
		elif [ "$opt" = 'i' ]; then
			error="Error: invalid $opt option or invalid $val value.";
			break;
		fi
		if [ "$opt" = 'f' ] && ! [ -z "$val" ]; then
			file="$val";
		elif [ "$opt" = 'f' ]; then
			error="Error: invalid $opt option or file not found.";
			break;
		fi
	done
	if [ -z "$error" ]; then
		for ((i=0; i < ${#ds[@]}; i++)); do
			d=${ds[$i]};
			v=${vs[$i]};
			r1_no_semicolon="1 s/^;\{0\}$d\( \)\{0,\}\=.\{0,\}$/$d = $v/; t";
			r1_semicolon="1 s/^;$d\( \)\{0,\}\=.\{0,\}$/$d = $v/; t";
			r1_test=$( egrep "^(;){0}$d( ){0,}\=.{0,}$" $file );
			r2="1,// s//$d = $v/";
			if ! [ -z "$r1_test" ]; then
				r1=$r1_no_semicolon;
			else
				r1=$r1_semicolon;
			fi
			sed -i '' -e "$r1" -e "$r2" $file;
		done
	else
		echo $error;
	fi
)