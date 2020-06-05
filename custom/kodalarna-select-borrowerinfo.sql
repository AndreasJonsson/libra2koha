SELECT DISTINCT `HOME LIBR` AS IdBranchCode,
       `RECORD #(PATRON)` AS IdBorrower,
       IF(TRIM(`UNIQUE ID`) != '', CONCAT('normalize_personnummer(', QUOTE(`UNIQUE ID`), ')'), NULL) AS `BorrowerAttribute:pnr:nq`,
       `P BARCODE` AS BarCode,
       `P TYPE` AS IdBorrowerCategory,
       TRIM(SUBSTRING(`PATRN NAME`, 1, LOCATE(' ', `PATRN NAME`) - 1)) AS LastName,
       TRIM(SUBSTRING(`PATRN NAME`, LOCATE(' ', `PATRN NAME`) + 1)) AS FirstName,
       `EXP DATE` AS Expires,
       `USER ID` AS RegId
FROM Patrons
