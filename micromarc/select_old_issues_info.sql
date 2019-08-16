SELECT
  ciServiceHistory.Id AS IdTransactionsSaved,
  ServiceAtUnitId AS IdBranchCode,
  ciServiceHistory.MarcRecordId AS TITLE_NO,
  ciServiceHistory.BorrowerId AS IdBorrower,
  ItemId AS IdItem,
  ServiceTime AS RegDate,
  caItem.Barcode AS ItemBarCode
FROM ciServiceHistory
  LEFT OUTER JOIN ciServiceCode ON (ciServiceCode.Code = ciServiceHistory.ServiceCode)
  LEFT OUTER JOIN caItem ON (caItem.Id = ciServiceHistory.ItemId)
WHERE OnLoan;
