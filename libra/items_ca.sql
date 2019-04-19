SELECT Items.*, BarCodes.BarCode, StatusCodes.Name AS StatusName, LoanPeriods.Name AS LoanPeriodName, Departments.Name AS DepartmentName
FROM Items
  LEFT OUTER JOIN CatJoin USING(IdItem)
  JOIN CA_CATALOG ON CatJoin.IdCat = CA_CATALOG_ID
  LEFT OUTER JOIN StatusCodes USING(IdStatusCode)
  LEFT OUTER JOIN LoanPeriods ON Items.IdLoanInfo = LoanPeriods.IdLoanInfo
  LEFT OUTER JOIN BarCodes USING (IdItem)
  LEFT OUTER JOIN Departments ON Departments.IdDepartment = Items.IdDepartment
WHERE CA_CATALOG.TITLE_NO = ?
UNION
SELECT Items.*, BarCodes.BarCode, StatusCodes.Name AS StatusName, LoanPeriods.Name AS LoanPeriodName, Departments.Name AS DepartmentName
FROM Items
  LEFT OUTER JOIN CatJoin USING(IdItem)
  JOIN CA_CATALOG ON CatJoin.IdCat = CA_CATALOG_ID
  LEFT OUTER JOIN StatusCodes USING(IdStatusCode)
  LEFT OUTER JOIN LoanPeriods ON Items.IdLoanInfo = LoanPeriods.IdLoanInfo
  LEFT OUTER JOIN BarCodes USING (IdItem)
  LEFT OUTER JOIN Departments ON Departments.IdDepartment = Items.IdDepartment
WHERE CatJoin.IdCat = ?
