create_tables.pl --format="$SOURCE_FORMAT" --quote='"' --headerrows=$HEADER_ROWS --encoding=utf8 --ext=$TABLEEXT --spec "$SPECDIR" --columndelimiter="$COLUMN_DELIMITER" --rowdelimiter='
' --dir="$tabledir" --table=ciService --table=ciServiceCode --table=ciServiceSource --table=shString --table=ciServiceHistory | eval $MYSQL_LOAD
$MYSQL <<EOF
CREATE INDEX ciService_Id ON ciService(Id);
CREATE INDEX ciService_ServiceCode ON ciService(ServiceCode);
CREATE INDEX ciService_ResType ON ciService(ResType);
CREATE INDEX ciServiceCode_Code ON ciServiceCode(Code);
CREATE INDEX ciServiceSource_Id ON ciServiceSource(Id);
CREATE INDEX ciServiceCode_DescriptionId ON ciServiceCode(DescriptionId);
CREATE INDEX shString_Id ON shString(Id);
CREATE INDEX shString_Swe ON shString(Swe);
CREATE INDEX ciServiceHistory_Id ON ciServiceHistory(Id);
CREATE INDEX ciServiceHistory_ServiceId ON ciServiceHistory(ServiceId);
CREATE INDEX ciServiceHistory_ItemId ON ciServiceHistory(ItemId);
CREATE INDEX ciServiceHistory_MarcRecordId ON ciServiceHistory(MarcRecordId);
CREATE INDEX ciServiceHistory_BorrowerId ON ciServiceHistory(BorrowerId);
CREATE INDEX ciServiceHistory_ServiceCode ON ciServiceHistory(ServiceCode);

EOF
