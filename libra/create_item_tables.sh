bib_tables="$(mktemp)"
create_tables.pl --format="$SOURCE_FORMAT" --quote='"' --headerrows=$HEADER_ROWS --encoding=$TABLEENC --ext=$TABLEEXT --spec="$SPECDIR" --columndelimiter="$COLUMN_DELIMITER" --escape="$ESCAPE_CHAR" --rowdelimiter='\r\n' --dir "$tabledir" --table 'Items' --table 'BarCodes' --table 'StatusCodes' --table 'CA_CATALOG' --table 'LoanPeriods' > "$bib_tables"
eval $MYSQL_LOAD < "$bib_tables"
eval $MYSQL_LOAD <<EOF 
ALTER TABLE Items ADD COLUMN done INT(1) DEFAULT 0;
CREATE UNIQUE INDEX ca_catalog_title_no_index  ON CA_CATALOG (TITLE_NO);
CREATE UNIQUE INDEX items_itemid_index ON Items (IdItem);
CREATE INDEX barcode_iditem_index ON BarCodes (IdItem);
CREATE INDEX items_catid_index ON Items (IdCat);
CREATE INDEX CA_CATALOG_ID_index ON CA_CATALOG (CA_CATALOG_ID);
EOF
