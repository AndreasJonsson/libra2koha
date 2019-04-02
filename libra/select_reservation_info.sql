SELECT
  ISBN_ISSN,
  TITLE_NO,
  Reservations.*,
  bbc.BarCode as BarCode,
  ibc.BarCode AS ItemBarCode,
  FirstName,
  LastName,
  Title,
  Author
FROM Reservations JOIN BarCodes as bbc USING (IdBorrower)
                  JOIN Borrowers USING(IdBorrower)
		  JOIN CA_CATALOG ON CA_CATALOG_ID=Reservations.IdCat
		  LEFT OUTER JOIN Items ON (Items.IdItem = Reservations.IdItem)
		  LEFT OUTER JOIN BarCodes as ibc ON (ibc.IdItem = Items.IdItem)
ORDER BY IdCat, RegDate ASC, RegTime ASC
