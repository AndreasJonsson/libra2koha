SELECT TransactionsSaved.*, BorrowerBarCodes.BarCode, Borrowers.RegDate AS DateEnrolled, Borrowers.FirstName, Borrowers.LastName, Borrowers.IdBranchCode, CA_CATALOG.TITLE_NO FROM TransactionsSaved JOIN CA_CATALOG ON IdCat = CA_CATALOG_ID LEFT OUTER JOIN Borrowers USING (IdBorrower) LEFT OUTER JOIN BorrowerBarCodes USING (IdBorrower) 