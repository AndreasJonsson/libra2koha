bib_tables="$(mktemp)"

#create_tables.pl --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}" --table 'Items' --table 'BarCodes' --table 'StatusCodes' --table 'CA_CATALOG' --table 'LoanPeriods' --table 'Orders' --table 'Departments' --table 'ItemsStat' --table 'ItemsInTransfer' --table "ILL" --table "ILL_Libraries"  > "$bib_tables"

create_tables.pl --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}" --table 'Items' --table 'BarCodes' --table 'CA_CATALOG' --table 'Orders'  > "$bib_tables"

cat $bib_tables

eval $MYSQL_LOAD < "$bib_tables"
eval $MYSQL_LOAD <<EOF 
ALTER TABLE Items ADD COLUMN done INT(1) DEFAULT 0;
CREATE UNIQUE INDEX ca_catalog_title_no_index  ON CA_CATALOG (TITLE_NO);
CREATE UNIQUE INDEX items_itemid_index ON Items (IdItem);
CREATE INDEX barcode_iditem_index ON BarCodes (IdItem);
CREATE UNIQUE INDEX barcode_idborrower_index ON BarCodes (IdBorrower);
CREATE UNIQUE INDEX barcode_barcode_index ON BarCodes (BarCode);
CREATE INDEX items_catid_index ON Items (IdCat);
CREATE UNIQUE INDEX CA_CATALOG_ID_index ON CA_CATALOG (CA_CATALOG_ID);
--CREATE UNIQUE INDEX StatusCodes_IdStatusCode ON StatusCodes(IdStatusCode);
--CREATE UNIQUE INDEX LoanPeriods_IdLoanInfo ON LoanPeriods(IdLoanInfo);
CREATE UNIQUE INDEX Orders_IdOrder ON Orders(IdOrder);
CREATE INDEX Orders_TitleNo ON Orders(Title_No);
--CREATE UNIQUE INDEX Departments_Id ON  Departments(IdDepartment);
CREATE TABLE CatJoin (IdItem INT PRIMARY KEY, IdCat INT);
CREATE INDEX CatJoin_IdCat ON CatJoin(IdCat);
INSERT INTO CatJoin
SELECT IdItem, IF(Items.Location_Marc != 'TEMP' AND Items.Location_Marc != 'FJÄRRLÅN', Items.IdCat, Orders.IdCat)
FROM Items LEFT OUTER JOIN Orders ON Orders.IdOrder = Items.IdCat;
--CREATE INDEX ILL_ActiveLibrary ON ILL(ActiveLibrary);
--CREATE INDEX ILL_Id ON ILL(IdILL);
--CREATE INDEX ILL_IdItem ON ILL(IdItem);
--CREATE INDEX ILL_Library_Id ON ILL_Libraries(IdLibrary);
EOF
