bib_tables="$(mktemp)"

create_tables.pl --format="$SOURCE_FORMAT" --quote='"' --headerrows=$HEADER_ROWS --encoding=utf8 --ext=$TABLEEXT --spec="$SPECDIR" --columndelimiter="$COLUMN_DELIMITER" --rowdelimiter="$ROW_DELIMITER" --dir "$tabledir" --table "item"  --table "shelf" --table "local_shelf" --table "branch" --table "lending_time" > "$bib_tables"

eval $MYSQL_LOAD < "$bib_tables"

eval $MYSQL_LOAD <<'EOF'
CREATE INDEX item_id ON item(id);
CREATE INDEX item_barcode ON item(barcode);
CREATE INDEX record_id ON item(record_id);
ALTER TABLE item ADD COLUMN done INT(1) DEFAULT 0;
CREATE INDEX shelf_id ON shelf(id);
CREATE INDEX local_shelf_id ON local_shelf(id);
CREATE INDEX branch_id ON branch(id);
CREATE INDEX lending_time_id ON lending_time(id);
EOF
