create_tables.pl --format="$SOURCE_FORMAT" --quote='"' --headerrows=$HEADER_ROWS --encoding=utf8 --ext=$TABLEEXT --spec "$SPECDIR" --specencoding=utf16 --columndelimiter="$COLUMN_DELIMITER" --rowdelimiter='\r\n' --dir "$tabledir" --table "Transactions" --table "BarCodes" --table "Issues"  --table "ILL" --table "ILL_Libraries" --table "Reservations" --table "ReservationBranches" --table "TransactionsSaved" | eval $MYSQL_LOAD
# Now copy the BarCodes table so we can have one for items and one for borrowers
$MYSQL <<EOF
CREATE TABLE BorrowerBarCodes LIKE BarCodes;
INSERT BorrowerBarCodes SELECT * FROM BarCodes;
RENAME TABLE BarCodes TO ItemBarCodes;
ALTER TABLE BorrowerBarCodes DROP COLUMN IdItem;
DELETE FROM BorrowerBarCodes WHERE IdBorrower IS NULL;
ALTER TABLE ItemBarCodes DROP COLUMN IdBorrower;
DELETE FROM ItemBarCodes WHERE IdItem IS NULL;
ALTER TABLE BorrowerBarCodes ADD PRIMARY KEY (IdBorrower);
ALTER TABLE ItemBarCodes ADD PRIMARY KEY (IdItem);
CREATE INDEX transaction_idborrower_index ON Transactions (IdBorrower);
CREATE INDEX transaction_iditem_index ON Transactions (IdItem);
CREATE INDEX transaction_idtransaction_index ON Transactions (IdTransaction);
CREATE INDEX ILL_ActiveLibrary ON ILL(ActiveLibrary);
CREATE INDEX ILL_Library_Id ON ILL_Libraries(IdLibrary);
CREATE INDEX Issues_Cat_Id ON Issues(IdCat);
CREATE INDEX Item_Issue_Id ON Items(IdIssue);
CREATE INDEX BorrowerDebtsRows_RegDate ON BorrowerDebtsRows(RegDate);
CREATE INDEX BorrowerDebtsRows_RegTime ON BorrowerDebtsRows(RegTime);

EOF
