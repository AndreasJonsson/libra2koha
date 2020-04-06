
tabledir="${OUTPUTDIR}"/utf8dir
mkdir -p "$tabledir"

name=Borrowers
delimtabletransform  --encoding=utf8               \
		     --column-delimiter="," \
		     --row-delimiter='\n'               \
		     --row-delimiter='\r\n'             \
		     --output-row-delimiter='\n'        \
		     --enclosed-by="$QUOTE_CHAR"        \
		     --null-literal                     \
		     "$DIR/${name}$TABLEEXT" > "$tabledir"/"${name}${TABLEEXT}"

name=Holds
delimtabletransform  --encoding=utf8               \
		     --column-delimiter=";" \
		     --row-delimiter='\n'               \
		     --row-delimiter='\r\n'             \
		     --output-row-delimiter='\n'        \
		     --enclosed-by="$QUOTE_CHAR"        \
		     --null-literal                     \
		     "$DIR/${name}$TABLEEXT" > "$tabledir"/"${name}${TABLEEXT}"

name=Loans
delimtabletransform  --encoding=utf8               \
		     --column-delimiter=";" \
		     --row-delimiter='\n'               \
		     --row-delimiter='\r\n'             \
		     --output-row-delimiter='\n'        \
		     --enclosed-by="$QUOTE_CHAR"        \
		     --null-literal                     \
		     "$DIR/${name}$TABLEEXT" > "$tabledir"/"${name}${TABLEEXT}"

name=Orders
delimtabletransform  --encoding=utf8               \
		     --column-delimiter="," \
		     --row-delimiter='\n'               \
		     --row-delimiter='\r\n'             \
		     --output-row-delimiter='\n'        \
		     --enclosed-by="$QUOTE_CHAR"        \
		     --null-literal                     \
		     "$DIR/${name}$TABLEEXT" > "$tabledir"/"${name}${TABLEEXT}"


echo "kodsodertorn Borrowers"

create_tables.pl  --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}" --table Borrowers  | eval $MYSQL_LOAD

echo "kodsodertorn Holds"

create_tables.pl  --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}" --table "Holds"  | eval $MYSQL_LOAD

echo "kodsodertorn Loans"

create_tables.pl  --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}" --table "Loans" | eval $MYSQL_LOAD

echo "kodsodertorn Orders"

create_tables.pl  --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}" --table "Orders"  | eval $MYSQL_LOAD


mysql -u libra2koha -ppass kosodertorn -s --batch -e 'SELECT id, ADDRESS FROM Borrowers' > "$OUTPUTDIR"/address1.txt

split-address.hs --output "$OUTPUTDIR"/address1.sql --order 1 "$OUTPUTDIR"/address1.txt

mysql -u libra2koha -ppass kosodertorn -s <<EOF

CREATE TABLE BorrowerAddresses
 (IdBorrower int,
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


mysql -u libra2koha -ppass kosodertorn -s  < "$OUTPUTDIR"/address1.sql
