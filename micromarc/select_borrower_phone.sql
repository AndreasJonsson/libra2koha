SELECT
  Id,
  'T' AS Type,
  MainPhone AS PhoneNumber
FROM  shContact WHERE Id = @BORROWERID := ?
UNION
SELECT
  Id,
  'T' AS Type,
  SecondPhone AS PhoneNumber
FROM  shContact WHERE Id = @BORROWERID
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
FROM  shContact WHERE Id = @BORROWERID

