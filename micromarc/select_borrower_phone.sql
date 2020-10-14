
SELECT * FROM
(SELECT
  NULL AS Id,
  NULL AS Type,
  NULL AS PhoneNumber
FROM DUAL WHERE (@BORROWERID := ?) AND FALSE
UNION
SELECT
  Id,
  'T' AS Type,
  MainPhone AS PhoneNumber
FROM  shContact WHERE Id = @BORROWERID AND MainPhone IS NOT NULL AND MainPhone != ''
UNION
SELECT
  Id,
  'T' AS Type,
  SecondPhone AS PhoneNumber
FROM  shContact WHERE Id = @BORROWERID AND SecondPhone IS NOT NULL AND SecondPhone != ''
UNION
SELECT
  Id,
  'E' AS Type,
  MainEmail AS PhoneNumber
FROM  shContact WHERE Id = @BORROWERID
UNION
SELECT
  Id,
  'E' AS Type,
  SecondEmail AS PhoneNumber
FROM  shContact WHERE Id = @BORROWERID AND SecondEmail IS NOT NULL AND SecondEmail != ''
UNION
SELECT
  Id,
  'M' AS Type,
  Mobile AS PhoneNumber
FROM shBorrower WHERE Id = @BORROWERID AND Mobile IS NOT NULL AND Mobile != '') AS T
