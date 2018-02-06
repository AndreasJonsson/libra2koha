bib_tables="$(mktemp)"
create_tables.pl --quote='"' --headerrows=$HEADER_ROWS --encoding=utf8 --ext=$TABLEEXT --spec "$SPECDIR" --columndelimiter="$COLUMN_DELIMITER" --rowdelimiter='\r\n' --dir "$tabledir" --table 'CA_COPY' --table 'CA_COPY_LABEL' --table 'CA_CATALOG' > "$bib_tables"
eval $MYSQL_LOAD < "$bib_tables"
eval $MYSQL_LOAD <<EOF 
ALTER TABLE CA_COPY ADD COLUMN done INT(1) DEFAULT 0;
CREATE UNIQUE INDEX ca_catalog_title_no_index  ON CA_CATALOG (`ca_catalog.title_no`);
CREATE UNIQUE INDEX ca_catalog_id_index  ON CA_CATALOG (`ca_catalog.ca_catalog_id`);
CREATE UNIQUE INDEX items_itemid_index ON CA_COPY (CA_COPY_ID);
CREATE UNIQUE INDEX items_catalog_id_index ON CA_COPY (CA_CATALOG_ID);
CREATE INDEX barcode_iditem_index ON CA_COPY_LABEL (CA_COPY_ID);
CREATE INDEX barcode_iditem_label_index ON CA_COPY_LABEL (CA_COPY_LABEL_ID);
CREATE INDEX barcode_iditem_barcode_index ON CA_COPY_LABEL (CA_COPY_LABEL);
EOF
