SELECT 'MV' AS IdBranchCode,
       `Systemnr(Patron)` AS IdBorrower,
        `LÅNT.NR` AS BarCode,
        `ANM` AS Comment,
        '-' AS RegId,
        `Föd.datum` AS BirthDate,
        `Skapad(Patron)` AS RegDate,
        `Lånt.typ` AS IdBorrowerCategory,
        `NAMN` AS FullName
FROM Patrons;
