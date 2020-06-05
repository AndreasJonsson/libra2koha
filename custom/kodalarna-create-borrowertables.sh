
tabledir="${OUTPUTDIR}"/utf8dir
mkdir -p "$tabledir"

echo "kodalarna Patrons"

name=03
delimtabletransform  --encoding=utf8               \
		     --column-delimiter="$COLUMN_DELIMITER" \
		     --row-delimiter='\n'               \
		     --row-delimiter='\r\n'             \
		     --output-row-delimiter='\n'        \
		     --enclosed-by="$QUOTE_CHAR"        \
		     --null-literal                     \
		     "$DIR/${name}$TABLEEXT" > "$tabledir"/"${name}${TABLEEXT}"

name=Patrons
delimtabletransform  --encoding=iso-8859-1               \
		     --column-delimiter="," \
		     --row-delimiter='\n'               \
		     --row-delimiter='\r\n'             \
		     --output-row-delimiter='\n'        \
		     --enclosed-by="$QUOTE_CHAR"        \
		     --null-literal                     \
		     "$DIR/${name}$TABLEEXT" > "$tabledir"/"${name}${TABLEEXT}"

name=Loans
delimtabletransform  --encoding=iso-8859-1              \
		     --column-delimiter="," \
		     --row-delimiter='\n'               \
		     --row-delimiter='\r\n'             \
		     --output-row-delimiter='\n'        \
		     --enclosed-by="$QUOTE_CHAR"        \
		     --null-literal                     \
		     "$DIR/${name}$TABLEEXT" > "$tabledir"/"${name}${TABLEEXT}"

name=Orders
delimtabletransform  --encoding=iso-8859-1               \
		     --column-delimiter="$COLUMN_DELIMITER" \
		     --row-delimiter='\n'               \
		     --row-delimiter='\r\n'             \
		     --output-row-delimiter='\n'        \
		     --enclosed-by="$QUOTE_CHAR"        \
		     --null-literal                     \
		     "$DIR/${name}$TABLEEXT" > "$tabledir"/"${name}${TABLEEXT}"


create_tables.pl  --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}" --table "Patrons"  | eval $MYSQL_LOAD

echo "kodalarna Loans"

create_tables.pl  --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}" --table "Loans"  | eval $MYSQL_LOAD

echo "kodalarna Orders"
create_tables.pl  --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}" --table "Orders"  | eval $MYSQL_LOAD


mysql -u libra2koha -ppass kodalarna -s --batch -e 'SELECT `RECORD #(PATRON)`, ADDRESS FROM Patrons' > "$OUTPUTDIR"/address1.txt
mysql -u libra2koha -ppass kodalarna -s --batch -e 'SELECT `RECORD #(PATRON)`, ADDRESS2 FROM Patrons' > "$OUTPUTDIR"/address2.txt

split-address.hs --output "$OUTPUTDIR"/address1.sql --order 1 "$OUTPUTDIR"/address1.txt
split-address.hs --output "$OUTPUTDIR"/address2.sql --order 1 "$OUTPUTDIR"/address2.txt

mysql -u libra2koha -ppass kodalarna -s <<EOF

CREATE TABLE BorrowerAddresses
 (IdBorrower varchar(16),
  Batch int, 
  Address1 varchar(256),
  City varchar(32),
  Postal varchar(32),
  Recipient varchar(32),
  CO varchar(256),
  Country varchar(32));

CREATE INDEX BorrowerAddresses_id ON BorrowerAddresses(IdBorrower);
CREATE INDEX BorrowerAddresses_batch ON BorrowerAddresses(Batch);
EOF


mysql -u libra2koha -ppass kodalarna -s  < "$OUTPUTDIR"/address1.sql
mysql -u libra2koha -ppass kodalarna -s  < "$OUTPUTDIR"/address2.sql

