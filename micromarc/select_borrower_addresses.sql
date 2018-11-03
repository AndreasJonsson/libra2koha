SELECT * FROM (SELECT
   Id,
   MainAddrLine1 AS Address1,
   MainAddrLine2 AS Address2,
   MainZip AS ZipCode,
   MainPlace AS City,
   MainCountry AS Country
FROM shContact
UNION
SELECT
   Id,
   SecondAddrLine1 AS Address1,
   SecondAddrLine2 AS Address2,
   SecondZip AS ZipCode,
   SecondPlace AS City,
   SecondCountry AS Country
FROM shContact) AS T0
 WHERE Id = ?;
