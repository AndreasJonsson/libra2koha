
create_tables.pl  --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}" --table "Loans"  | eval $MYSQL_LOAD
