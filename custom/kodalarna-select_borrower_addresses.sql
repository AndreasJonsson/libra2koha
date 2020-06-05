
SELECT
IFNULL(Recipient, Address1) AS Address1,
IF(Recipient IS NULL, CONCAT(Postal, ' ', City), Address1) AS Address2,
IF(Recipient IS NULL, NULL, CONCAT(Postal, ' ', City)) AS Address3,
Postal AS ZipCode,
City AS City,
CO AS CO,
Country AS Country
FROM BorrowerAddresses JOIN Patrons ON (IdBorrower = `RECORD #(PATRON)`) WHERE `IdBorrower` = ?
ORDER BY Batch ASC 

