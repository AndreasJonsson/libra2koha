SELECT
   CONCAT('.', `RECORD #(BIBLIO)`) AS CatId,
   `NOTE(Order)` AS Note,
   `ODATE` AS OrderDate,
   `COPIES` AS Copies,
   `LOCATION` AS Location,
   `VENDOR` AS Vendor,
   `CODE2` AS Code2,
   `COUNTRY` AS Country
FROM `Orders`;
