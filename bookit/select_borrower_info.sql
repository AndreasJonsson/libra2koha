SELECT DISTINCT IFNULL(CI_ACCOUNT.DEF_PICKUP_PLACE, CI_BORR.CI_UNIT_ID) AS IdBranchCode,
       CI_BORR.CI_BORR_ID AS IdBorrower,
       barcodes.barcodes AS BarCode,
       CI_BORR.NOTE AS Comment,
       IF(valid_personnummer(SO_SEC_NO) OR valid_samordningsnummer(SO_SEC_NO), SO_SEC_NO, persnr.CI_BORR_CARD_ID) AS RegId,
       CI_BORR.DATE_OF_BIRTH AS BirthDate,
       CI_BORR.CREATE_DATETIME AS RegDate,
       CI_ACCOUNT.CI_BORR_CAT_ID AS IdBorrowerCategory,
       CONCAT(FIRST_NAME_1,
            IF(FIRST_NAME_2 != '', CONCAT(' ', FIRST_NAME_2), ''),
            IF(FIRST_NAME_3 != '', CONCAT(' ', FIRST_NAME_3), ''),
            IF(FIRST_NAME_4 != '', CONCAT(' ', FIRST_NAME_4), ''),
            IF(FIRST_NAME_5 != '', CONCAT(' ', FIRST_NAME_5), '')) AS FirstName,
       SURNAME AS LastName,
       IF(LENGTH(CI_BORR.PIN_CODE) >= 4, CI_BORR.PIN_CODE, NULL) AS Password,
       IF(SY_SEX_ID = 1, 'M', IF(SY_SEX_ID = 2, 'F', NULL)) AS Sex,
       CI_BORR_EXTRA_1.DESCR AS `BorrExtra1`,
       CI_ACCOUNT.EXTRA_ELIGIBILITY AS BorrExtraEligibility,
       CI_BORR_GRP.DESCR AS BorrGrpDescr,
       grptxt.TXT AS BorrGrpTxt
FROM CI_BORR
  LEFT OUTER JOIN CI_ACCOUNT USING(CI_BORR_ID)
  LEFT OUTER JOIN CI_BORR_GRP USING(CI_BORR_GRP_ID)
  LEFT OUTER JOIN GE_LA_TXT AS grptxt ON CI_BORR_GRP.GE_LA_KEY_ID=grptxt.GE_LA_KEY_ID AND grptxt.LA_LANGUAGE_ID='sv_SE'
  LEFT OUTER JOIN CI_BORR_EXTRA_1 USING (CI_BORR_EXTRA_1_ID)
  LEFT OUTER JOIN CI_BORR_CAT USING(CI_BORR_CAT_ID)
  LEFT OUTER JOIN CI_BORR_CARD AS persnr ON persnr.CI_BORR_ID=CI_BORR.CI_BORR_ID AND
                 (valid_personnummer(CI_BORR_CARD_ID) OR valid_samordningsnummer(CI_BORR_CARD_ID))
  LEFT OUTER JOIN (SELECT CI_BORR_ID, GROUP_CONCAT(DISTINCT CI_BORR_CARD_ID ORDER BY LENGTH(CI_BORR_CARD_ID) DESC SEPARATOR ';') as barcodes FROM CI_BORR_CARD WHERE
                   NOT (valid_personnummer(CI_BORR_CARD_ID) OR valid_samordningsnummer(CI_BORR_CARD_ID))
                   GROUP BY CI_BORR_ID) AS barcodes
       ON (barcodes.CI_BORR_ID = CI_BORR.CI_BORR_ID)
      
