SELECT
  b.IdBorrower,
  b.IdBranchCode,
  BorrowerBarCodes.BarCode,
  Transactions.IdItem IS NOT NULL AS has_transaction,
  Transactions.RegDate AS TransactionDate,
  rbc.BarCode AS ReservationBarCode,
  IFNULL(ibc.BarCode, ItemBarCodes.BarCode) as ItemBarCode,
  bdr.Amount,
  FeeTypes.Name,
  bd.Text AS Text,
  bd.RegDate AS RegDate,
  bd.RegTime AS RegTime,
  b.FirstName,
  b.LastName,
  b.RegDate AS DateEnrolled
FROM
  BorrowerDebts AS bd
  JOIN Borrowers AS b USING (IdBorrower)
  LEFT OUTER JOIN BorrowerBarCodes USING(IdBorrower)
  LEFT OUTER JOIN BorrowerDebtsRows AS bdr USING(IdDebt)
  LEFT OUTER JOIN FeeTypes USING (IdFeeType)
  LEFT OUTER JOIN ItemBarCodes USING (IdItem)
  LEFT OUTER JOIN Transactions USING (IdTransaction)
  LEFT OUTER JOIN Reservations USING (IdReservation)
  LEFT OUTER JOIN ItemBarCodes AS rbc ON Reservations.IdItem = rbc.IdItem
  LEFT OUTER JOIN ItemBarCodes AS ibc ON Transactions.IdItem = ibc.IdItem
WHERE
  b.IdBorrower IS NOT NULL
ORDER BY b.IdBorrower, bdr.RegDate ASC, bdr.RegTime ASC
