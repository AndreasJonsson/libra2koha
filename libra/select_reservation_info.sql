SELECT
  ISBN_ISSN,
  TITLE_NO,
  Reservations.*,
  BorrowerBarCodes.BarCode as BarCode,
  ItemBarCodes.BarCode AS ItemBarCode,
  FirstName,
  LastName,
  Title,
  Author
FROM Reservations JOIN BorrowerBarCodes USING (IdBorrower)
                  JOIN Borrowers USING(IdBorrower)
		  JOIN CA_CATALOG ON CA_CATALOG_ID=Reservations.IdCat
		  LEFT OUTER JOIN Items ON (Items.IdItem = Reservations.IdItem)
		  LEFT OUTER JOIN ItemBarCodes ON (ItemBarCodes.IdItem = Items.IdItem)
ORDER BY IdCat, RegDate ASC, RegTime ASC
