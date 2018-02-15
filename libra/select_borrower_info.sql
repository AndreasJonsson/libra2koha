SELECT Borrowers.*, BarCodes.BarCode, BorrowerRegId.RegId
    FROM Borrowers LEFT OUTER JOIN BarCodes USING (IdBorrower) LEFT OUTER JOIN BorrowerRegId USING (IdBorrower)
