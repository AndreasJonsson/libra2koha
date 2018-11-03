SELECT
  ServiceAtUnitId AS IdBranchCode,
  ciServiceHistory.MarcRecordId AS TITLE_NO,
  ciServiceHistory.BorrowerId AS IdBorrower,
  ItemId AS IdItem,
  ServiceTime AS RegDate,
  caItem.Barcode AS ItemBarCode,
  shBorrowerBarcode.Barcode AS BarCode
FROM ciServiceHistory
  LEFT OUTER JOIN ciServiceCode ON (ciServiceCode.Code = ciServiceHistory.ServiceCode)
  LEFT OUTER JOIN shBorrowerBarcode ON (shBorrowerBarcode.BorrowerId = ciServiceHistory.BorrowerId AND NOT shBorrowerBarcode.IsSSN)
  LEFT OUTER JOIN caItem ON (caItem.Id = ciServiceHistory.ItemId)
WHERE OnLoan;
