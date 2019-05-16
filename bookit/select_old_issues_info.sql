SELECT
     CI_BORR_EVENT.CI_BORR_EVENT_ID AS IdTransactionsSaved,
     GE_ORG_ID_OWNER AS IdBranchCode,
     `ca_catalog.title_no` AS TITLE_NO,
     barcodes.barcodes AS BarCode,
     EVENT_DATETIME AS RegDate
FROM CI_BORR_EVENT
     JOIN SY_CI_EVENT_TYPE USING(SY_CI_EVENT_TYPE_ID)
     LEFT OUTER JOIN CA_CATALOG ON CA_CATALOG.`ca_catalog.ca_catalog_id`=CA_CATALOG_ID
     LEFT OUTER JOIN (
       SELECT CI_BORR_ID, GROUP_CONCAT(DISTINCT CI_BORR_CARD_ID ORDER BY LENGTH(CI_BORR_CARD_ID) DESC SEPARATOR ';') as barcodes
       FROM CI_BORR_CARD
       WHERE
          NOT (valid_personnummer(CI_BORR_CARD_ID) OR valid_samordningsnummer(CI_BORR_CARD_ID))
       GROUP BY CI_BORR_ID
     ) AS barcodes

       ON (barcodes.CI_BORR_ID = CI_BORR_EVENT.CI_BORR_ID)
WHERE
  SY_CI_EVENT_TYPE.DESCR REGEXP '^L.n$'
;
