echo create marc records

echo $PERL5LIB

#create_tables.pl --format="$SOURCE_FORMAT" --quote="$QUOTE_CHAR" --escape="$ESCAPE_CHAR" --headerrows=$HEADER_ROWS --encoding=utf8 --ext=$TABLEEXT --spec "$SPECDIR" --columndelimiter="$COLUMN_DELIMITER" --dir "$tabledir" --rowdelimiter="\r\n" --table 'caMarcRecords' | eval $MYSQL_LOAD

"$LIBRIOTOOLS_DIR"/line2iso.pl --format="$SOURCE_FORMAT" --quote="$QUOTE_CHAR" --escape="$ESCAPE_CHAR" --headerrows=$HEADER_ROWS --encoding=utf8 --ext=$TABLEEXT  --columndelimiter="$COLUMN_DELIMITER" --dir "$tabledir" --rowdelimiter="
" --table 'caMarcRecords' --xml >"$MARC"

