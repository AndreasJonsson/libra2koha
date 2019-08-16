SELECT shBorrower.HomeUnit AS IdBranchCode,
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
       shContact.PinCode AS Password,
       shBorrower.Expires AS Expires,
       MAX(SSN.Barcode) AS `BorrowerAttribute:PERSNUMMER`,
       GROUP_CONCAT(Barcode.Barcode ORDER BY LENGTH(Barcode.Barcode) DESC SEPARATOR ';') AS BarCode
FROM shBorrower
  LEFT OUTER JOIN shBorrowerBarcode AS Barcode ON (Barcode.BorrowerId = shBorrower.Id AND NOT Barcode.IsSSN)
  LEFT OUTER JOIN shBorrowerBarcode AS SSN ON (SSN.BorrowerId = shBorrower.Id AND SSN.IsSSN)
  LEFT OUTER JOIN shContact ON (shContact.Id = shBorrower.Id)
GROUP BY IdBranchCode, BirthDate, RegDate, IdBorrowerCategory, FullName, IdBorrower, Password, Expires;

