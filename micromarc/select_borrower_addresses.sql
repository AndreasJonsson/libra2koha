SELECT
   NULL AS Id,
   NULL AS Address1,
   NULL AS Address2,
   NULL AS ZipCode,
   NULL AS City,
   NULL AS Country
FROM DUAL WHERE (@BORROWERID := ?) AND FALSE
UNION
SELECT
   Id,
   MainAddrLine1 AS Address1,
   MainAddrLine2 AS Address2,
   MainZip AS ZipCode,
   MainPlace AS City,
   MainCountry AS Country
FROM shContact WHERE Id = @BORROWERID
UNION
SELECT
   Id,
   SecondAddrLine1 AS Address1,
   SecondAddrLine2 AS Address2,
   SecondZip AS ZipCode,
   SecondPlace AS City,
   SecondCountry AS Country
FROM shContact WHERE Id = @BORROWERID;
