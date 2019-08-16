SELECT
  ciService.Id AS IdReservation,
  ciService.MarcRecordId AS IdCat,
  ciService.ItemId AS IdItem,
  IF(Swe != "Aviserad" OR ciService.ItemId IS NULL, 'R', 'A') AS Status,
  IFNULL(caMarcRecord.ISBN, caMarcRecord.ISSN) AS ISBN_ISSN,
  caMarcRecord.Id AS TITLE_NO,
  caItem.Barcode AS ItemBarCode,
  ciService.BorrowerId AS IdBorrower,
  ciService.ResTime AS ResDate,
  ReserveAtLocalUnitId AS FromIdBranchCode,
  DeliverAtLocalUnitId AS GetIdBranchCode,
  ResActivationTime AS SendDate,
  ResValidUntil AS NotificationDate,
  ciService.Notes AS Info,
  ServiceTime AS RegDate,
  ResValidUntil AS StopDate,
  caMarcRecord.WorkTitle AS Title,
  caMarcRecord.WorkAuthor AS Author,
  GROUP_CONCAT(shBorrowerBarcode.Barcode ORDER BY LENGTH(shBorrowerBarcode.Barcode) DESC SEPARATOR ';') AS BarCode  
FROM ciService
  LEFT OUTER JOIN caMarcRecord ON (ciService.MarcRecordId = caMarcRecord.Id)
  LEFT OUTER JOIN ciServiceCode ON (ciServiceCode.Code = ciService.ServiceCode)
  LEFT OUTER JOIN shString ON (shString.Id = ciServiceCode.DescriptionId)
  LEFT OUTER JOIN caItem ON (caItem.Id = ciService.ItemId)
  LEFT OUTER JOIN shBorrower ON (shBorrower.Id = ciService.BorrowerId)
  LEFT OUTER JOIN shBorrowerBarcode ON (shBorrowerBarcode.BorrowerId = shBorrower.Id AND NOT shBorrowerBarcode.IsSSN)
WHERE NOT OnLoan
GROUP BY IdReservation, IdCat, IdItem, Status, ISBN_ISSN, TITLE_NO, ItemBarCode, IdBorrower, ResDate, FromIdBranchCode, GetIdBranchCode, SendDate, NotificationDate, Info, RegDate, StopDate, Title, Author
ORDER BY ciService.MarcRecordId, ciService.ServiceTime ASC;
