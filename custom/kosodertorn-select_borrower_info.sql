SELECT DISTINCT `DEPT` AS IdBranchCode,
       `id` AS IdBorrower,
       `UNIQUE ID` AS RegId,
       `P BARCODE` AS BarCode,
       `P TYPE` AS BorrowerCategory,
       TRIM(SUBSTRING(`PATRN NAME`, 1, LOCATE(' ', `PATRN NAME`) - 1)) AS LastName,
       TRIM(SUBSTRING(`PATRN NAME`, LOCATE(' ', `PATRN NAME`) + 1)) AS FirstName,
       `EXP DATE` AS Expires,
       `NOTE` AS Note,
       `MESSAGE(Patron)` AS `Message`
FROM Borrowers
