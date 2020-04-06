SELECT TELEPHONE AS PhoneNumber, 'T' AS Type
  FROM Borrowers WHERE id = @BORROWER_ID := ?
UNION
SELECT TELEPHONE2 AS PhoneNumber, 'T' AS Type
  FROM Borrowers WHERE id = @BORROWER_ID
UNION
SELECT `EMAIL ADDR` AS PhoneNumber, 'E' AS Type
  FROM Borrowers WHERE id = @BORROWER_ID
UNION
SELECT `MOBILE PH` AS PhoneNumber, 'M' AS Type
  FROM Borrowers WHERE id = @BORROWER_ID

