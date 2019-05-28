
SELECT
EPOSTADR AS PhoneNumber,
'E' AS Type
FROM Patrons WHERE `Systemnr(Patron)` = @BORR_ID := ?
UNION
SELECT
TELEFON AS PhoneNumber,
'T' AS Type FROM Patrons WHERE `Systemnr(Patron)` = @BORR_ID
UNION
TELEFON2 AS PhoneNumber,
'T' AS Type FROM Patrons WHERE `Systemnr(Patron)` = @BORR_ID;
