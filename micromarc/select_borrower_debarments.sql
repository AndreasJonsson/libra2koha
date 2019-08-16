SELECT
  CAST('2099-01-01' AS DATE) AS BlockedUntil,
  Swe AS Reason,
  DefaultedDate AS RegDate,
  CAST('0:00' AS TIME) AS RegTime,
  DefaultedDate AS UpdatedDate
FROM
shBorrower
JOIN shBorrowerDefaultCause ON shBorrower.DefaultedCauseId = shBorrowerDefaultCause.Id
JOIN shString ON shBorrowerDefaultCause.StringId = shString.Id
WHERE shBorrower.Id = ? AND shBorrower.Defaulted
