SELECT Items.*, NoOfLoansTot AS LoanCount, BarCodes.BarCode
FROM Items
  LEFT OUTER JOIN CatJoin USING(IdItem)
  JOIN CA_CATALOG ON CatJoin.IdCat = CA_CATALOG_ID
  LEFT OUTER JOIN BarCodes USING (IdItem)
WHERE CA_CATALOG.TITLE_NO = ?
UNION
SELECT Items.*, NoOfLoansTot AS LoanCount, BarCodes.BarCode
FROM Items
  LEFT OUTER JOIN CatJoin USING(IdItem)
  JOIN CA_CATALOG ON CatJoin.IdCat = CA_CATALOG_ID
  LEFT OUTER JOIN BarCodes USING (IdItem)
WHERE CatJoin.IdCat = ?
