bib_tables="$(mktemp)"
create_tables.pl --format="$SOURCE_FORMAT" --quote='"' --headerrows=$HEADER_ROWS --encoding=utf8 --ext=$TABLEEXT --spec "$SPECDIR" --columndelimiter="$COLUMN_DELIMITER" --rowdelimiter='\r\n' --dir "$tabledir" --table 'CA_COPY' --table 'CA_COPY_LABEL' --table 'CA_COPY_TYPE' --table 'CA_NOT_AVAILABLE_CAUSE' --table 'CA_MEDIA_TYPE' --table 'CI_UNIT' --table 'CA_CATALOG' --table 'GE_LA_KEY' --table 'GE_LA_TXT' --table CI_CAT --table IL_LOAN --table IL_STATUS --table IL_LIBRARY --table CA_LOC --table CA_SUPPLIER --table LA_TXT > "$bib_tables"
eval $MYSQL_LOAD < "$bib_tables"
eval $MYSQL_LOAD <<'EOF'
CREATE TABLE catalog_isbn_issn (CA_CATALOG_ID int, isbn VARCHAR(32), issn VARCHAR(32));
CREATE INDEX catalog_isbn_issn_id ON catalog_isbn_issn(CA_CATALOG_ID);
CREATE INDEX catalog_isbn_issn_isbn ON catalog_isbn_issn(isbn);
CREATE INDEX catalog_isbn_issn_issn ON catalog_isbn_issn(issn);
ALTER TABLE CA_COPY ADD COLUMN done INT(1) DEFAULT 0;
CREATE INDEX ca_catalog_title_no_index  ON CA_CATALOG (`ca_catalog.title_no`);
CREATE INDEX ca_catalog_id_index  ON CA_CATALOG (`ca_catalog.ca_catalog_id`);
CREATE UNIQUE INDEX items_itemid_index ON CA_COPY (CA_COPY_ID);
CREATE INDEX items_catalog_id_index ON CA_COPY (CA_CATALOG_ID);
CREATE INDEX barcode_iditem_index ON CA_COPY_LABEL (CA_COPY_ID);
CREATE INDEX barcode_iditem_label_index ON CA_COPY_LABEL (CA_COPY_LABEL_ID);
CREATE INDEX barcode_iditem_barcode_index ON CA_COPY_LABEL (LABEL);
CREATE INDEX LA_KEY_ID ON LA_TXT(LA_KEY_ID);
CREATE INDEX LA_TXT ON LA_TXT(TXT);
CREATE INDEX LA_LANG_ID ON LA_TXT(LA_LANGUAGE_ID);
CREATE INDEX GE_LA_KEY_ID ON GE_LA_KEY(GE_LA_KEY_ID);
CREATE INDEX GE_LA_KEY_TABLE_NAME ON GE_LA_KEY(TABLE_NAME);
CREATE INDEX GE_LA_KEY_FIELD_NAME ON GE_LA_KEY(FIELD_NAME);
CREATE INDEX GE_LA_TXT_LA_KEY_ID ON GE_LA_TXT(GE_LA_KEY_ID);
CREATE INDEX GE_LA_TXT_LA_LANGUAGE_ID ON GE_LA_TXT(LA_LANGUAGE_ID);
CREATE INDEX CA_NOT_AVAILABLE_CAUSE_ID_1 ON CA_NOT_AVAILABLE_CAUSE(CA_NOT_AVAILABLE_CAUSE_ID);
CREATE INDEX CA_COPY_GE_ORG_ID_UNIT ON CA_COPY(GE_ORG_ID_UNIT);
CREATE INDEX CA_COPY_LABEL_LABEL_TYPE ON CA_COPY_LABEL(LABEL_TYPE);
CREATE INDEX CA_COPY_TYPE_ID ON CA_COPY_TYPE(CA_COPY_TYPE_ID);
CREATE INDEX CA_SUPPLIER_ID ON CA_SUPPLIER(CA_SUPPLIER_ID);
CREATE INDEX CA_LOC_ID ON CA_LOC(CA_LOC_ID);
CREATE INDEX CA_LOC_NAME ON CA_LOC(NAME);
CREATE TABLE labels (row_number int, CA_COPY_ID int, LABEL VARCHAR(256));

SET @rn := 0;
INSERT INTO labels
SELECT @rn := @rn + 1 AS rn,
            CA_COPY_ID, LABEL
 FROM CA_COPY_LABEL
       ORDER BY CA_COPY_ID DESC, LABEL_TYPE ASC;
CREATE TEMPORARY TABLE tmp_labels (row_number int, CA_COPY_ID int, LABEL VARCHAR(256));
INSERT INTO tmp_labels (SELECT * FROM labels);
CREATE INDEX tmp_labels_id ON tmp_labels(CA_COPY_ID);
UPDATE labels SET row_number = row_number - (SELECT MIN(row_number) FROM tmp_labels where labels.CA_COPY_ID = tmp_labels.CA_COPY_ID);
CREATE INDEX labels_rn ON labels(row_number);
CREATE INDEX labels_ca_copy_id ON labels(CA_COPY_ID);
CREATE INDEX ci_cat_id ON CI_CAT(CI_CAT_ID);
EOF
