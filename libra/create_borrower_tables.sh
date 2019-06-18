create_tables.pl  --format="$SOURCE_FORMAT" --quote='"' --headerrows=$HEADER_ROWS --encoding=utf8 --ext=$TABLEEXT  --spec "$SPECDIR" --specencoding=utf16 --columndelimiter="$COLUMN_DELIMITER" --rowdelimiter="$ROW_DELIMITER" --dir "$tabledir" --table "Borrowers" --table "BorrowerPhoneNumbers" --table "BorrowerAddresses" --table "BorrowerRegId" --table ILL --table ILL_Libraries --table BorrowerDebts --table BorrowerDebtsRows --table FeeTypes  --table "BorrowerBlocked" | eval $MYSQL_LOAD
if [[ -n "$PINCODE_TABLE" && -e "$TABLEDIR/$PINCODE_TABLE" ]]; then
    create_tables.pl --format="$SOURCE_FORMAT" --columndelimiter="!*!" --rowdelimiter="$ROW_DELIMITER" --dir "$tabledir" --table "$PINCODE_TABLE" --spec "$tabledir" --headerrows=0
fi
eval $MYSQL_LOAD <<EOF 

CREATE INDEX Borrowers_IdBranchCode ON Borrowers(IdBranchCode);
CREATE INDEX BorrowerDebts_IdBorrower ON BorrowerDebts(IdBorrower);
CREATE INDEX BorrowerDebts_IdDebt ON BorrowerDebts(IdDebt);
CREATE INDEX BorrowerAddresses_IdBorrower ON BorrowerAddresses(IdBorrower);
CREATE INDEX BorrowerDebtsRows_IdDebt ON BorrowerDebtsRows(IdDebt);
CREATE INDEX BorrowerDebtsRows_IdBranchCode ON BorrowerDebtsRows(IdBranchCode);
CREATE INDEX BorrowerPhoneNumbers_IdBorrower ON BorrowerPhoneNumbers(IdBorrower);
CREATE INDEX BorrowerPhoneNumbers_Type ON BorrowerPhoneNumbers(Type);
CREATE INDEX BorrowerBlocked_IdBorrower ON BorrowerBlocked(IdBorrower);
CREATE INDEX BorrowerBlocked_Type ON BorrowerBlocked(Type);
CREATE INDEX BorrowerRegId_IdBorrower ON BorrowerRegId(IdBorrower);
CREATE INDEX FeeTypes_IdFeeType ON FeeTypes(IdFeeType);
EOF

