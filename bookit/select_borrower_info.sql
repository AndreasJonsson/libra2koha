SELECT CI_ACCOUNT.GE_ORG_ID AS IdBranchCode,
       barcodes.barcodes AS BarCode,
       MESSAGE AS Message,
       CI_BORR.NOTE AS Comment,
       persnr.CI_BORR_CARD_ID AS RegId,
       CI_BORR.DATE_OF_BIRTH AS BirthDate,
       CI_BORR.CREATE_DATETIME AS RegDate,
       CI_ACCOUNT.CI_BORR_CAT_ID AS IdBorrowerCategory,
       CONCAT(FIRST_NAME_1,
            IF(FIRST_NAME_2 != '', CONCAT(' ', FIRST_NAME_2), ''),
            IF(FIRST_NAME_3 != '', CONCAT(' ', FIRST_NAME_3), ''),
            IF(FIRST_NAME_4 != '', CONCAT(' ', FIRST_NAME_4), ''),
            IF(FIRST_NAME_5 != '', CONCAT(' ', FIRST_NAME_5), '')) as FirstName,
       SURNAME AS LastName,
       CI_BORR.CI_BORR_ID AS IdBorrower
FROM CI_BORR
  LEFT OUTER JOIN CI_ACCOUNT USING(CI_BORR_ID)
  LEFT OUTER JOIN CI_BORR_CAT USING(CI_BORR_CAT_ID)
  LEFT OUTER JOIN CI_BORR_EVENT USING(CI_BORR_ID)
  LEFT OUTER JOIN CI_BORR_MESSAGE USING(CI_BORR_ID)
  LEFT OUTER JOIN CI_BORR_CARD AS persnr ON persnr.CI_BORR_ID=CI_BORR.CI_BORR_ID AND
                 (valid_personnummer(CI_BORR_CARD_ID) OR valid_samordningsnummer(CI_BORR_CARD_ID))
  LEFT OUTER JOIN (SELECT CI_BORR_ID, GROUP_CONCAT(DISTINCT CI_BORR_CARD_ID ORDER BY LENGTH(CI_BORR_CARD_ID) DESC SEPARATOR ';') as barcodes FROM CI_BORR_CARD WHERE
                   NOT (valid_personnummer(CI_BORR_CARD_ID) OR valid_samordningsnummer(CI_BORR_CARD_ID))
                   GROUP BY CI_BORR_ID) AS barcodes
       ON (barcodes.CI_BORR_ID = CI_BORR.CI_BORR_ID);
