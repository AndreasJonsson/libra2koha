SELECT Items.*, BarCodes.BarCode, StatusCodes.Name AS StatusName, LoanPeriods.Name AS LoanPeriodName
FROM Items
  LEFT OUTER JOIN Orders ON Orders.IdOrder = Items.IdCat
  JOIN CA_CATALOG ON IF(Location_Marc != 'TEMP' AND Location_Marc != 'FJÄRRLÅN', Items.IdCat, Orders.IdCat) = CA_CATALOG_ID
  LEFT OUTER JOIN StatusCodes USING(IdStatusCode)
  LEFT OUTER JOIN LoanPeriods ON Items.IdLoanInfo = LoanPeriods.IdLoanInfo
  LEFT OUTER JOIN BarCodes USING (IdItem)
  LEFT OUTER JOIN Departments ON Departments.IdDepartment = Items.IdDepartment
WHERE CA_CATALOG.TITLE_NO = ?
UNION
SELECT Items.*, BarCodes.BarCode, StatusCodes.Name AS StatusName, LoanPeriods.Name AS LoanPeriodName
FROM Items
  LEFT OUTER JOIN Orders ON Orders.IdOrder = Items.IdCat
  JOIN CA_CATALOG ON IF(Location_Marc != 'TEMP' AND Location_Marc != 'FJÄRRLÅN', Items.IdCat, Orders.IdCat) = CA_CATALOG_ID
  LEFT OUTER JOIN StatusCodes USING(IdStatusCode)
  LEFT OUTER JOIN LoanPeriods ON Items.IdLoanInfo = LoanPeriods.IdLoanInfo
  LEFT OUTER JOIN BarCodes USING (IdItem)
  LEFT OUTER JOIN Departments ON Departments.IdDepartment = Items.IdDepartment
WHERE IF(Location_Marc != 'TEMP' AND Location_Marc != 'FJÄRRLÅN', Items.IdCat, Orders.IdCat) = ?
