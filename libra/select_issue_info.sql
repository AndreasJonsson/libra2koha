    SELECT t.*, bbc.BarCode AS BorrowerBarcode, ibc.BarCode as ItemBarcode, b.FirstName, b.LastName, b.IdBorrower, b.IdBranchCode as BorrowerIdBranchCode, b.RegDate as dateenrolled
    FROM Transactions as t JOIN Borrowers AS b USING (IdBorrower) LEFT OUTER JOIN BorrowerBarCodes as bbc USING (IdBorrower) LEFT OUTER JOIN ItemBarCodes as ibc USING (IdItem)
