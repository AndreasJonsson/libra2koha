SELECT
  `id` AS IdReservation,
  `Patron  Info2` AS IdBorrower,
  `Date Placed` AS  ResDate,
  `Date Placed` AS  RegDate,
  TRIM(`Bib No.`) AS IdCat,
  `Barcode` AS ItemBarCode,
  IF(`Hold Status` LIKE '%HOLDSHELF%', 'A', 'R') AS Status,
  Title,
  `Pickup Location` AS FromIdBranchCode
FROM Holds ORDER BY IdCat, RegDate ASC;
