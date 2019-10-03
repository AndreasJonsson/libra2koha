SELECT caItem.Id AS IdItem,
       caItem.BelongToUnitId AS IdBranchCode,
       caItem.PlacedAtUnitId AS IdPlacedAtBranchCode,
       caItem.Shelf AS LocalShelf,
       caItem.Notes AS Info,
       caItem.LastLentToBorrowerDate AS LatestLoanDate,
       caItem.Location AS Location_Marc,
       caItem.LoanCount AS LoanCount,
       caItem.RenewalCount AS RenewalCount,
       aqOrderLine.Price AS Price,
       caItem.RegTime AS RegDate,
       caItemStatusCode.Code AS IdStatusCode,
       caItemStatusCode.Description AS StatusName,
       ciLoanType.Name AS LoanPeriodName,
       IF(StatusChangedTime > LastLentToBorrowerDate, StatusChangedTime, LastLentToBorrowerDate) AS LastSeen,
       caItem.Barcode AS BarCode,
       NOT ISNULL(ciILL.IsLII) OR ciILL.IsLII AS IsRemote,
       caMaterialType.F500a AS MaterialType,
       caDocumentGroup.Id AS IdDepartment
FROM caItem
   LEFT OUTER JOIN aqOrderLine ON (caItem.Id = aqOrderLine.ItemId)
   LEFT OUTER JOIN caItemStatusCode ON (caItem.ItemStatus = caItemStatusCode.Code)
   LEFT OUTER JOIN ciLoanType ON (ciLoanType.Id = caItem.LoanTypeId)
   LEFT OUTER JOIN ciILL ON (caItem.Id = ciILL.ItemId)
   LEFT OUTER JOIN caMarcRecord ON (caItem.MarcRecordId = caMarcRecord.Id)
   LEFT OUTER JOIN caMaterialType ON (caMarcRecord.MaterialTypeId = caMaterialType.Id)
   LEFT OUTER JOIN caDocumentGroup ON (caMarcRecord.DocumentGroupId = caDocumentGroup.Id)
WHERE MarcRecordId = ?;
