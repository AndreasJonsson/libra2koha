SELECT CI_LOAN.GE_ORG_ID_UNIT AS IdBranchCode,
       CI_ACCOUNT.GE_ORG_ID AS BorrowerIdBranchCode,
       LABEL AS ItemBarcode,
       barcodes.barcodes AS BorrowerBarcode,
       LOAN_DATETIME AS RegDate,
       DUE_DATETIME AS EstReturnDate
FROM
  CI_LOAN
  LEFT OUTER JOIN CI_ACCOUNT USING(CI_BORR_ID)
  LEFT OUTER JOIN CA_COPY USING(CA_COPY_ID)
  LEFT OUTER JOIN labels  ON labels.CA_COPY_ID = CA_COPY.CA_COPY_ID AND labels.row_number = 1
  LEFT OUTER JOIN (SELECT CI_BORR_ID, GROUP_CONCAT(DISTINCT CI_BORR_CARD_ID ORDER BY LENGTH(CI_BORR_CARD_ID) DESC SEPARATOR ';') as barcodes FROM CI_BORR_CARD WHERE
                   NOT (valid_personnummer(CI_BORR_CARD_ID) OR valid_samordningsnummer(CI_BORR_CARD_ID))
                   GROUP BY CI_BORR_ID) AS barcodes
  ON (barcodes.CI_BORR_ID = CI_LOAN.CI_BORR_ID);

