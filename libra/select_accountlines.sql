SELECT
  b.IdBorrower,
  b.IdBranchCode,
  bbc.BarCode,
  Transactions.IdItem IS NOT NULL AS has_transaction,
  Transactions.RegDate AS TransactionDate,
  rbc.BarCode AS ReservationBarCode,
  IFNULL(tbc.BarCode, ibc.BarCode) as ItemBarCode,
  bdr.Amount,
  FeeTypes.Name,
  bd.Text AS Text,
  bd.RegDate AS RegDate,
  bd.RegTime AS RegTime,
  b.FirstName,
  b.LastName,
  b.RegDate AS DateEnrolled,
  IFNULL(bd.IdItem, IFNULL(tbc.IdItem, rbc.IdItem)) AS IdItem
FROM
  BorrowerDebts AS bd
  JOIN Borrowers AS b USING (IdBorrower)
  LEFT OUTER JOIN BarCodes AS bbc USING(IdBorrower)
  LEFT OUTER JOIN BorrowerDebtsRows AS bdr USING(IdDebt)
  LEFT OUTER JOIN FeeTypes USING (IdFeeType)
  LEFT OUTER JOIN BarCodes AS ibc ON (ibc.IdItem=bd.IdItem)
  LEFT OUTER JOIN Transactions USING (IdTransaction)
  LEFT OUTER JOIN Reservations USING (IdReservation)
  LEFT OUTER JOIN BarCodes AS rbc ON Reservations.IdItem = rbc.IdItem
  LEFT OUTER JOIN BarCodes AS tbc ON Transactions.IdItem = tbc.IdItem
WHERE
  b.IdBorrower IS NOT NULL
ORDER BY b.IdBorrower, bdr.RegDate ASC, bdr.RegTime ASC
