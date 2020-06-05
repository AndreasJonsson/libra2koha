SELECT
       `RECORD #(PATRON)` AS IdBorrower,
       Borrowers.`P BARCODE` AS BorrowerBarcode,
       `BARCODE` AS BarCode,
       `DUE DATE` AS EstReturnDate,
       Loans.id AS IdTransaction,
       NOW() AS RegDate
FROM
  Loans JOIN Borrowers USING (`RECORD #(PATRON)`);

