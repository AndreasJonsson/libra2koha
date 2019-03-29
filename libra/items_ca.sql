SELECT Items.*, BarCodes.BarCode, StatusCodes.Name AS StatusName, LoanPeriods.Name AS LoanPeriodName
FROM Items JOIN CA_CATALOG ON Items.IdCat = CA_CATALOG_ID
  LEFT OUTER JOIN StatusCodes USING(IdStatusCode)
  LEFT OUTER JOIN LoanPeriods USING(IdLoanInfo)
  LEFT OUTER JOIN BarCodes USING (IdItem)
WHERE TITLE_NO = ?
UNION
SELECT Items.*, BarCodes.BarCode, StatusCodes.Name AS StatusName, LoanPeriods.Name AS LoanPeriodName
FROM Items JOIN CA_CATALOG ON Items.IdCat = CA_CATALOG_ID
  LEFT OUTER JOIN StatusCodes USING(IdStatusCode)
  LEFT OUTER JOIN LoanPeriods USING(IdLoanInfo)
  LEFT OUTER JOIN BarCodes USING (IdItem)
WHERE IdCat = ?
