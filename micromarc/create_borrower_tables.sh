create_tables.pl --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}" --table=shBorrower --table=shBorrowerGroup --table=shBorrowerBarcode --table=shContact --table=shBorrowerDefaultCause | eval $MYSQL_LOAD

eval $MYSQL_LOAD <<EOF
CREATE INDEX shBorrower_Id ON shBorrower(Id);
CREATE INDEX shBorrower_BorrowerGroupId ON shBorrower(BorrowerGroupId);
CREATE INDEX shBorrowerGroup_Id ON shBorrowerGroup(Id);
CREATE INDEX shBorrowerBarcode_Id ON shBorrowerBarcode(Id);
CREATE INDEX shBorrowerBarcode_BorrowerId ON shBorrowerBarcode(BorrowerId);
CREATE INDEX shBorrowerBarcode_Barcode ON shBorrowerBarcode(Barcode);
CREATE INDEX shContact_Id ON shContact(Id);
CREATE INDEX shBorrowerDefaultCause_Id ON shBorrowerDefaultCause(Id);
EOF
