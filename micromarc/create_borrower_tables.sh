create_tables.pl --format="$SOURCE_FORMAT" --quote='"' --headerrows=$HEADER_ROWS --encoding=utf8 --ext=$TABLEEXT --spec "$SPECDIR" --columndelimiter="$COLUMN_DELIMITER" --rowdelimiter='
' --dir="$tabledir" --table=shBorrower --table=shBorrowerParent --table=shBorrowerGroup --table=shBorrowerDefaultCause --table=shBorrowerBarcode --table=shContact | eval $MYSQL_LOAD

eval $MYSQL_LOAD <<EOF
CREATE INDEX shBorrower_Id ON shBorrower(Id);
CREATE INDEX shBorrowerDefaultCause_Id ON shBorrowerDefaultCause(Id);
CREATE INDEX shBorrowerParent_Id ON shBorrowerParent(Id);
CREATE INDEX shBorrowerParent_ParentId ON shBorrowerParent(BorrowerParentId);
CREATE INDEX shBorrowerParent_ChildId ON shBorrowerParent(BorrowerChildId);
CREATE INDEX shBorrowerGroup_Id ON shBorrowerGroup(Id);
CREATE INDEX shBorrowerBarcode_Id ON shBorrowerBarcode(Id);
CREATE INDEX shBorrowerBarcode_BorrowerId ON shBorrowerBarcode(BorrowerId);
CREATE INDEX shBorrowerBarcode_Barcode ON shBorrowerBarcode(Barcode);
EOF
