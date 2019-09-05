if [ ! -f "$CONFIG/config.yaml" ]; then
    echo "Missing $CONFIG/config.yaml"
    MISSING_FILE=1
    cp "$SCRIPTDIR/config_sample/config.yaml" "$CONFIG/"
fi

longest_common_prefix () {
    local s0="$1"
    local s1="$2"

    let i=0
    while [[ "${s0:$i:1}" == "${s1:$i:1}" ]]; do
	let i++
    done
    echo "${s0:0:$i}"
}

link_table () {
   local table="$1";
   if [[ ! -e "$DIR"/"$table$TABLEEXT" ]]; then
       if ls "$DIR"/*"_$table$TABLEEXT"; then
	   local target;
	   if (( "$(ls "$DIR"/*"_$table$TABLEEXT" | wc -l)" > 1)); then
	       local prefix=
	       for file in $(ls "$DIR"/*"_$table$TABLEEXT") ; do
		   if [[ -f "$file" && ! -L "$file" ]]; then
		      echo file: $file
		      if [[ -z "$prefix" ]] ; then
			  prefix=$file
		      else
			  prefix=$(longest_common_prefix $file $prefix)
		      fi
		      echo prefix: "'$prefix'"
		   fi
	       done
	       target="$prefix$table$TABLEEXT"
	   else
	       target="$(ls "$DIR"/*"_$table$TABLEEXT")"
	   fi
	   echo target: "'$target'"
	   if [[ ! -e "$target" ]] ; then
	       echo "'$target' does not exist"
	       exit 1
	   fi
	   ln -s "$target" "$DIR"/"$table$TABLEEXT"
       fi
   fi
}

link_table branch
link_table item
link_table lending_time
link_table local_shelf
link_table shelf

if [ ! -f "$CONFIG/branchcodes.yaml" ]; then
    echo "Missing $CONFIG/branchcodes.yaml"
    MISSING_FILE=1
    echo    table2config.pl --ext="$TABLEEXT" --encoding=$TABLEENC --columndelim="$COLUMN_DELIMITER" --headerrows=$HEADER_ROWS --dir="$DIR" --name='branch' --key=0 --comment=1
    if ! table2config.pl --ext="$TABLEEXT" --encoding=$TABLEENC --columndelim="$COLUMN_DELIMITER" --headerrows=$HEADER_ROWS --dir="$DIR" --name='branch' --key=0 --comment=1 > "$CONFIG/branchcodes.yaml"; then
	rm -f "$CONFIG/branchcodes.yaml"
    fi
fi
if [ ! -f "$CONFIG/loc.yaml" ]; then
    echo "Missing $CONFIG/loc.yaml"
    MISSING_FILE=1
    if ! table2config.pl --ext="$TABLEEXT" --encoding=$TABLEENC --columndelim="$COLUMN_DELIMITER" --headerrows=$HEADER_ROWS  --dir="$DIR" --name='local_shelf' --key=0 --comment=1 --value=1 > "$CONFIG/loc.yaml" ; then
	rm -f "$CONFIG/loc.yaml"
    fi
fi
if [ ! -f "$CONFIG/ccode.yaml" ]; then
    echo "Missing $CONFIG/ccode.yaml"
    MISSING_FILE=1
    if ! table2config.pl --ext="$TABLEEXT" --encoding=$TABLEENC --columndelim="$COLUMN_DELIMITER" --headerrows=$HEADER_ROWS  --dir="$DIR" --name='shelf' --key=0 --comment=1 --value=1 > "$CONFIG/ccode.yaml"; then
	rm -f "$CONFIG/ccode.yaml"
    fi
fi
