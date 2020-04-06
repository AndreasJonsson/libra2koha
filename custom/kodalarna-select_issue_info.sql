SELECT
       Patrons.id AS IdBorrower,
       `BARCODE` AS BarCode,
       `DUE DATE` AS EstReturnDate,
       Loans.id AS IdTransaction,
       NOW() AS RegDate
FROM
  Loans JOIN Patrons USING (`UNIQUE ID`) WHERE `UNIQUE ID` != '';

