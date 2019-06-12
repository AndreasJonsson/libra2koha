SELECT
IFNULL(Recipient, Address1) AS Address1,
IF(Recipient IS NULL, CONCAT(Postal, ' ', City), Address1) AS Address2,
IF(Recipient IS NULL, NULL, CONCAT(Postal, ' ', City)) AS Address3,
Postal AS ZipCode,
City AS City,
CO AS CO,
Country AS Country,
`LÅNT.KOD2` AS `State`
FROM BorrowerAddresses JOIN Patrons ON (IdBorrower = `Systemnr(Patron)`) WHERE `IdBorrower` = ?
ORDER BY Batch ASC 

