
create_tables.pl --spec "$SPECDIR" --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}" --table "Item" --table "Patrons" | eval $MYSQL_LOAD

eval $MYSQL_LOAD <<'EOF'
CREATE TABLE biblio_mapping (marc001 varchar(32), marc003 varchar(16), item_id varchar(16), barcode varchar(16), PRIMARY KEY (marc001, marc003), UNIQUE KEY(item_id), UNIQUE KEY(barcode));
ALTER TABLE Item ADD COLUMN (done  boolean);
CREATE INDEX Item_streckkod ON Item(Streckkod);
CREATE INDEX Item_systemnummer ON Item(Systemnummer);
CREATE INDEX Patron_systemnummer ON Patrons(`Systemnr(Patron)`);
CREATE INDEX Item_003 ON Item(`003`);
CREATE INDEX Item_001 ON Item(`001`);
CREATE INDEX Item_003_001 ON Item(`003`, `001`);
EOF

if [[-n "$PATRON_MARC"]] ; then

perl -w "$PATRON_MARC" <<'EOF'
EOF

fi
