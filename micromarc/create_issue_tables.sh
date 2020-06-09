create_tables.pl --spec "$SPECDIR" --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}"  --table=ciService --table=ciServiceSource --table=ciServiceHistory | eval $MYSQL_LOAD
$MYSQL <<EOF
CREATE INDEX ciService_Id ON ciService(Id);
CREATE INDEX ciService_ServiceCode ON ciService(ServiceCode);
CREATE INDEX ciService_ResType ON ciService(ResType);
CREATE INDEX ciServiceSource_Id ON ciServiceSource(Id);
CREATE INDEX ciServiceHistory_Id ON ciServiceHistory(Id);
CREATE INDEX ciServiceHistory_ServiceId ON ciServiceHistory(ServiceId);
CREATE INDEX ciServiceHistory_ItemId ON ciServiceHistory(ItemId);
CREATE INDEX ciServiceHistory_MarcRecordId ON ciServiceHistory(MarcRecordId);
CREATE INDEX ciServiceHistory_BorrowerId ON ciServiceHistory(BorrowerId);
CREATE INDEX ciServiceHistory_ServiceCode ON ciServiceHistory(ServiceCode);

EOF
