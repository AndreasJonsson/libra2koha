echo create marc records

echo create_tables.pl --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}"  --table 'caMarcRecords' 
create_tables.pl --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}"  --table 'caMarcRecords' | eval $MYSQL_LOAD

echo done

echo line2iso.pl --delimited --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}" --table 'caMarcRecords' --output "$MARC"
line2iso.pl --xml --delimited --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}" --table 'caMarcRecords' --output "$MARC"

