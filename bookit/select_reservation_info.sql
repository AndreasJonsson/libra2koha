SELECT CA_BOOKING.CA_CATALOG_ID AS IdCat,
       IF(CA_COPY_ID_CAUGHT IS NULL OR CA_COPY_ID_CAUGHT = '', CA_BOOKING.CA_COPY_ID, CA_COPY_ID_CAUGHT) AS IdItem,
       IF(CAUGHT_DATETIME IS NULL, 'R', 'A') AS Status,
       IFNULL(isbn, issn) AS ISBN_ISSN,
       `ca_catalog.title_no` AS TITLE_NO,
       labels.LABEL AS ItemBarCode,
       barcodes.barcodes AS BarCode,
       BOOKING_DATETIME AS ResDate,
       IFNULL(ORIG_GE_ORG_ID, GE_ORG_ID) AS FromIdBranchCode,
       GE_ORG_ID AS GetIdBranchCode,
       CAUGHT_DATETIME AS SendDate,
       CAUGHT_EXPIRE_DATE AS NotificationDate,
       REMARK_ON_BOOKING AS Info,
       CA_BOOKING.CREATE_DATETIME	AS RegDate,
       VALID_TO_DATE AS StopDate,
       `ca_catalog.title_lat1` AS Title,
       `ca_catalog.author_lat1` AS Author
FROM CA_BOOKING
     LEFT OUTER JOIN CA_CATALOG ON CA_CATALOG_ID = `ca_catalog.ca_catalog_id`
     LEFT OUTER JOIN catalog_isbn_issn ON `ca_catalog.title_no` = catalog_isbn_issn.CA_CATALOG_ID
     LEFT OUTER JOIN labels ON IFNULL(CA_COPY_ID_CAUGHT, CA_BOOKING.CA_COPY_ID) = labels.CA_COPY_ID and labels.row_number = 0
     JOIN CI_BORR USING(CI_BORR_ID)
     LEFT OUTER JOIN (SELECT CI_BORR_ID, GROUP_CONCAT(DISTINCT CI_BORR_CARD_ID ORDER BY LENGTH(CI_BORR_CARD_ID) DESC SEPARATOR ';') as barcodes FROM CI_BORR_CARD WHERE
     	           NOT (valid_personnummer(CI_BORR_CARD_ID) OR valid_samordningsnummer(CI_BORR_CARD_ID))
                   GROUP BY CI_BORR_ID) AS barcodes
       ON (barcodes.CI_BORR_ID = CI_BORR.CI_BORR_ID)
ORDER BY CA_BOOKING.CREATE_DATETIME ASC;
