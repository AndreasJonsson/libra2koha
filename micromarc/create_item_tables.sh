bib_tables="$(mktemp)"
create_tables.pl --format="$SOURCE_FORMAT" --quote='"' --headerrows=$HEADER_ROWS --encoding=utf8 --ext=$TABLEEXT --spec "$SPECDIR" --columndelimiter="$COLUMN_DELIMITER" --rowdelimiter='
' --dir "$tabledir" --table 'caItem' --table 'caItemStatusCode' --table 'caMaterialType' --table 'shLibrary' --table 'shLibraryType' --table 'caCategory' --table 'caCategoryCheckedIn' --table 'caMarcRecord' --table 'caMarcRecords' --table 'ciILL' --table 'ciILLStatus' --table 'ciILLStatusHistory' --table 'aqOrderLine' --table 'ciLoanType' > "$bib_tables"
eval $MYSQL_LOAD < "$bib_tables"
eval $MYSQL_LOAD <<'EOF'
CREATE INDEX caItem_id ON caItem(Id);
CREATE INDEX caItem_MarcRecordId ON caItem(MarcRecordId);
CREATE INDEX caItem_Barcode ON caItem(Barcode);
CREATE INDEX caItemStatusCode_Code ON caItemStatusCode(Code);
CREATE INDEX caMaterialType_Id ON caMaterialType(Id);
CREATE INDEX shLibrary_Id ON shLibrary(Id);
CREATE INDEX shLibraryType_Id ON shLibraryType(Id);
CREATE INDEX caCategory_Id ON caCategory(Id);
CREATE INDEX caCategoryCheckedIn_CategoryId ON caCategoryCheckedIn(CategoryId);
CREATE INDEX caMarcRecord_Id ON caMarcRecord(Id);
CREATE INDEX caMarcRecord_RootMarcId ON caMarcRecord(RootMarcId);
CREATE INDEX caMarcRecords_MarcRecordId ON caMarcRecords(MarcRecordId);
CREATE INDEX caMarcRecords_Mainfield ON caMarcRecords(Mainfield);
CREATE INDEX ciILL_Id ON ciILL(Id);
CREATE INDEX ciILL_StatusId ON ciILL(ILLStatusId);
CREATE INDEX ciILL_ItemId ON ciILL(ItemId);
CREATE INDEX ciILL_BorrowerId ON ciILL(BorrowerId);
CREATE INDEX ciILL_LibraryId ON ciILL(LibraryId);
CREATE INDEX ciILLStatusHistory_Id ON ciILLStatusHistory(Id);
CREATE INDEX ciILLStatusHistory_ILLId ON ciILLStatusHistory(ILLId);
CREATE INDEX aqOrderLine_Id ON aqOrderLine(Id);
CREATE INDEX aqOrderLine_ItemId ON aqOrderLine(ItemId);
CREATE INDEX ciLoanType_Id ON ciLoanType(Id);
EOF
