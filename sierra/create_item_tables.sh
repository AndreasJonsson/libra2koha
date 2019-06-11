
create_tables.pl --spec "$SPECDIR" --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}" --table "Item" --table "Patrons" --table "Bibliographic" | eval $MYSQL_LOAD

eval $MYSQL_LOAD <<'EOF'
CREATE TABLE biblio_mapping (marc001 varchar(32), marc003 varchar(16), item_id varchar(16), barcode varchar(16), PRIMARY KEY (marc001, marc003), UNIQUE KEY(item_id), UNIQUE KEY(barcode));
ALTER TABLE Item ADD COLUMN (done  boolean);
ALTER TABLE Item ADD COLUMN (total_renewals int);
ALTER TABLE Item ADD COLUMN (total_checkouts int);
ALTER TABLE Item ADD COLUMN (price varchar(16));
ALTER TABLE Item ADD COLUMN (created date);
ALTER TABLE Item ADD COLUMN (marc003001 varchar(16));
CREATE INDEX Item_streckkod ON Item(Streckkod);
CREATE INDEX Item_systemnummer ON Item(Systemnummer);
CREATE INDEX Patron_systemnummer ON Patrons(`Systemnr(Patron)`);
CREATE INDEX Item_003 ON Item(`003`);
CREATE INDEX Item_001 ON Item(`001`);
CREATE INDEX Item_003_001 ON Item(`003`, `001`);
CREATE INDEX Item_cat_003_001 ON Item(`marc003001`);
UPDATE Item SET marc003001 = CONCAT(`003`, `001`);
CREATE INDEX Bibliographic_sysnr ON Bibliographic(`Systemnummer`);
CREATE INDEX Bibliographic_code3 ON Bibliographic(`Bib kod 3`);
CREATE TABLE BorrowerAddresses (
  IdBorrower VARCHAR(16) NOT NULL,
  Batch Int NOT NULL,
  Recipient VARCHAR(256),
  CO VARCHAR(256),
  Address1 VARCHAR(256),
  Postal VARCHAR(32),
  City VARCHAR(256),
  Country VARCHAR(256)
);
CREATE INDEX BorrowerAddresses_Id ON BorrowerAddresses(IdBorrower);
EOF


eval $MYSQL_LOAD  < $DIR/addresses.sql
eval $MYSQL_LOAD  < $DIR/addresses2.sql

#table_from_marc.pl --config "$CONFIG" --outputdir "$OUTPUTDIR" --infile "$SIERRA_ITEMMARC" --tablename "Item" --idcolumn '("Systemnummer", "sierra_sysid")' --column '("sierra_total_checkouts", "total_checkouts")' --column '("sierra_total_renewals", "total_renewals")' --column '("sierra_price", "price")' --column '("sierra_created", "created")'
