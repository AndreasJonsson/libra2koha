SELECT
   CONCAT('.', `RECORD #(BIBLIO)`) AS CatId,
   `NOTE(Order)` AS Note,
   `001` AS marc001,
   `020|a` AS marc020a,
   `245` AS marc245,
   `ODATE` AS OrderDate,
   `COPIES` AS Copies,
   `VENDOR` AS Vendor,
   `FUND` AS Fund,
   `CODE2` AS Code2,
   `COUNTRY` AS Country
FROM `Orders`;
