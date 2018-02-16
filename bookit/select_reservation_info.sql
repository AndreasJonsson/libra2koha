SELECT CA_CATALOG_ID AS IdCat,
       IFNULL(CA_COPY_ID_CAUGHT, CA_COPY_ID) AS IdItem,
       IF(CAUGHT_DATETIME IS NULL, 'R', 'A') AS Status,
       IFNULL(isbn, issn) AS ISBN_ISSN,
       CA_CATALOG_ID AS TITLE_NO,
       labels.LABEL AS ItemBarCode,
       barcodes.CI_BORR_CARD_ID AS BarCode,
       BOOKING_DATETIME AS ResDate,
       ORIG_GE_ORG_ID AS FromIdBranchCode,
       GE_ORG_ID AS GetIdBranchCode,
       CAUGHT_DATETIME AS SendDate,
       CAUGHT_EXPIRE_DATE AS NotificationDate,
       REMARK_ON_BOOKING AS Info,
       CREATE_DATETIME	AS RegDate,
       VALID_TO_DATE AS StopDate
       `ca_catalog.title_lat1` AS Title,
       `ca_catalog.author_lat1` AS Author
FROM CA_BOOKING
     LEFT OUTER JOIN catalog_isbn_issn USING(CA_CATALOG_ID)
     LEFT OUTER JOIN CA_COPY_LABEL ON IFNULL(CA_COPY_ID_CAUGHT, CA_COPY_ID) = labels.CA_COPY_ID
     JOIN CI_BORR USING(CI_BORR_ID)
     LEFT OUTER JOIN (SELECT CI_BORR_ID, GROUP_CONCAT(DISTINCT CI_BORR_CARD_ID ORDER BY LENGTH(CI_BORR_CARD_ID) DESC SEPARATOR ';') as barcodes FROM CI_BORR_CARD WHERE
     	           NOT (valid_personnummer(CI_BORR_CARD_ID) OR valid_samordningsnummer(CI_BORR_CARD_ID))
                   GROUP BY CI_BORR_ID) AS barcodes
       ON (barcodes.CI_BORR_ID = CI_BORR.CI_BORR_ID);
     LEFT OUTER JOIN CA_CATALOG ON CA_CATALOG_ID=`ca_catalog.ca_catalog_id`;
