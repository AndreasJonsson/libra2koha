
SELECT TELEPHONE AS PhoneNumber, 'T' AS Type
  FROM Patrons WHERE `id` = @BORR_ID := ?
UNION
SELECT TELEPHONE2 AS PhoneNumber, 'T' AS Type
  FROM Patrons WHERE `id` = @BORR_ID
UNION
SELECT `EMAIL ADDR` AS PhoneNumber, 'E' AS Type
  FROM Patrons WHERE `id` = @BORR_ID
