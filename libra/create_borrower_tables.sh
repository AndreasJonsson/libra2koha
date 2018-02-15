create_tables.pl  --format="$SOURCE_FORMAT" --quote='"' --headerrows=$HEADER_ROWS --encoding=utf8 --ext=$TABLEEXT  --spec "$SPECDIR" --columndelimiter="$COLUMN_DELIMITER" --rowdelimiter='\r\n' --dir "$tabledir" --table "Borrowers" --table "BorrowerPhoneNumbers" --table "BarCodes" --table "BorrowerAddresses" --table "BorrowerRegId" --table ILL --table ILL_Libraries --table BorrowerDebts --table BorrowerDebtsRows --table FeeTypes  --table "BorrowerBlocked" | eval $MYSQL_LOAD