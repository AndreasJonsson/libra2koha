SELECT DISTINCT `HOME LIBR` AS IdBranchCode,
       `id` AS IdBorrower,
       `UNIQUE ID` AS `BorrowerAttribute:pnr`,
       `P BARCODE` AS BarCode,
       `P TYPE` AS IdBorrowerCategory,
       TRIM(SUBSTRING(`PATRN NAME`, 1, LOCATE(' ', `PATRN NAME`) - 1)) AS LastName,
       TRIM(SUBSTRING(`PATRN NAME`, LOCATE(' ', `PATRN NAME`) + 1)) AS FirstName,
       `EXP DATE` AS Expires,
       `USER ID` AS RegId
FROM Patrons
