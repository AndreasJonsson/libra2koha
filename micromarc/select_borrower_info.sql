SELECT shBorrower.HomeUnit AS IdBranchCode,
       shBorrowerBarcode.Barcode AS BarCode,
       '' AS Comment
       shBorrower.BirthDate AS BirthDate,
       shBorrower.RegDate AS RegDate,
       shBorrower.BorrowerGroupId AS IdBorrowerCategory
FROM shBorrower
  LEFT OUTER JOIN shBorrowerBarcode ON (shBorrowerBarcode.BorrowerId = shBorrower.Id)
  LEFT OUTER JOIN shContact ON (shContact.Id = shBorrower.Id);

  


SELECT CI_ACCOUNT.GE_ORG_ID AS IdBranchCode,
       barcodes.barcodes AS BarCode,
       CI_BORR.NOTE AS Comment,
       persnr.CI_BORR_CARD_ID AS RegId,
       CI_BORR.DATE_OF_BIRTH AS BirthDate,
       CI_BORR.CREATE_DATETIME AS RegDate,
       CI_ACCOUNT.CI_BORR_CAT_ID AS IdBorrowerCategory,
       CONCAT(FIRST_NAME_1,
            IF(FIRST_NAME_2 != '', CONCAT(' ', FIRST_NAME_2), ''),
            IF(FIRST_NAME_3 != '', CONCAT(' ', FIRST_NAME_3), ''),
            IF(FIRST_NAME_4 != '', CONCAT(' ', FIRST_NAME_4), ''),
            IF(FIRST_NAME_5 != '', CONCAT(' ', FIRST_NAME_5), '')) AS FirstName,
       SURNAME AS LastName,
       CI_BORR.CI_BORR_ID AS IdBorrower,
       IF(LENGTH(CI_BORR.PIN_CODE) >= 4, CI_BORR.PIN_CODE, NULL) AS Password
FROM CI_BORR
  LEFT OUTER JOIN CI_ACCOUNT USING(CI_BORR_ID)
  LEFT OUTER JOIN CI_BORR_CAT USING(CI_BORR_CAT_ID)
  LEFT OUTER JOIN CI_BORR_CARD AS persnr ON persnr.CI_BORR_ID=CI_BORR.CI_BORR_ID AND
                 (valid_personnummer(CI_BORR_CARD_ID) OR valid_samordningsnummer(CI_BORR_CARD_ID))
  LEFT OUTER JOIN (SELECT CI_BORR_ID, GROUP_CONCAT(DISTINCT CI_BORR_CARD_ID ORDER BY LENGTH(CI_BORR_CARD_ID) DESC SEPARATOR ';') as barcodes FROM CI_BORR_CARD WHERE
                   NOT (valid_personnummer(CI_BORR_CARD_ID) OR valid_samordningsnummer(CI_BORR_CARD_ID))
                   GROUP BY CI_BORR_ID) AS barcodes
       ON (barcodes.CI_BORR_ID = CI_BORR.CI_BORR_ID);
