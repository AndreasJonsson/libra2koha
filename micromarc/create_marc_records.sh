echo create marc records

create_tables.pl  --use-bom --spec "$SPECDIR" --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}"  --table 'caMarcRecords' | eval $MYSQL_LOAD

echo done

"$LIBRIOTOOLS_DIR"/line2iso.pl --delimited --format="$SOURCE_FORMAT" --quote="$QUOTE_CHAR" --escape="$ESCAPE_CHAR" --headerrows=$HEADER_ROWS --encoding=utf8 --ext=$TABLEEXT  --columndelimiter="$COLUMN_DELIMITER" --dir "$tabledir" --rowdelimiter="
" --table 'caMarcRecords' --xml >"$MARC"

