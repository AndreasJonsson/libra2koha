echo create marc records

create_tables.pl --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}"  --table 'caMarcRecords' | eval $MYSQL_LOAD

echo done

"$LIBRIOTOOLS_DIR"/line2iso.pl --delimited --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}" --table 'caMarcRecords' --xml >"$MARC"

