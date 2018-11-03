SELECT shBorrower.HomeUnit AS IdBranchCode,
       shBorrowerBarcode.Barcode AS BarCode,
       CONCAT(
          IFNULL(shContact.Notes, ''),
          IF(shContact.Notes IS NOT NULL
	     AND shContact.SecondNotes IS NOT NULL
	     AND shContact.Notes != ''
	     AND shContact.SecondNotes != '', '\n', NULL),
	  IFNULL(shContact.SecondNotes, '')
	) AS Comment,
       shBorrower.BirthDate AS BirthDate,
       shBorrower.RegDate AS RegDate,
       shBorrower.BorrowerGroupId AS IdBorrowerCategory,
       shContact.Name AS FullName,
       shBorrower.Id AS IdBorrower,
       shContact.PinCode AS Password
FROM shBorrower
  LEFT OUTER JOIN shBorrowerBarcode ON (shBorrowerBarcode.BorrowerId = shBorrower.Id AND NOT shBorrowerBarcode.IsSSN)
  LEFT OUTER JOIN shContact ON (shContact.Id = shBorrower.Id);
