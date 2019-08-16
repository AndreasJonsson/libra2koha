SELECT
  ciService.Id AS IdTransaction,
  ServiceAtLocalUnitId AS IdBranchCode,
  HomeUnit AS BorrowerIdBranchCode,
  caItem.Barcode AS ItemBarcode,
  ciService.ItemId AS IdItem,
  shBorrower.Id AS IdBorrower,
--
-- This clause doesn't seem to make any difference to just using
-- "ServiceTime".  I'm guessing that MicroMarc updates the service
-- record until moving it to the history.
--
--  IFNULL(IF(Swe = "Utlånat",
--     ServiceTime,
--     (SELECT ciServiceHistory.ServiceTime
--      FROM ciServiceHistory JOIN ciServiceCode AS c ON (c.Code = ciServiceHistory.ServiceCode) JOIN shString AS s ON (s.Id = c.DescriptionId)
--      WHERE ciServiceHistory.ItemId = ciService.ItemId AND
--            ciServiceHistory.BorrowerId = ciService.BorrowerId AND
--	    s.Swe = "Utlånat"
--      ORDER BY ciServiceHistory.ServiceTime ASC LIMIT 1)
--      ),
--      ciService.ServiceTime) AS RegDate,
  ciService.ServiceTime AS RegDate,
  ciService.DueTime AS EstReturnDate,
  ciService.Notes AS Note,
  Swe AS TypeNote,
  shContact.Name AS FullName,
  caItem.RenewalCount AS NoOfRenewals
FROM
  ciService
  LEFT OUTER JOIN shBorrower ON (shBorrower.Id = ciService.BorrowerId)
  LEFT OUTER JOIN shContact ON (shBorrower.Id = shContact.Id)
  LEFT OUTER JOIN caItem ON (caItem.Id = ciService.ItemId)
  LEFT OUTER JOIN ciServiceCode ON (ciServiceCode.Code = ciService.ServiceCode)
  LEFT OUTER JOIN shString ON (shString.Id = ciServiceCode.DescriptionId)
WHERE OnLoan;
