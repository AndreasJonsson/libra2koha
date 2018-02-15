SELECT CA_COPY_ID AS IdItem,
       GE_ORG_ID_UNIT AS IdBranchCode,
       CA_LOC_ID AS IdLocalShelf,
       NOTE AS Info,
       LATEST_LOAN_DATETIME AS LatestLoanDate,
       DEVIATING_LOCATION_MARC AS Location_Marc,
       OLD_NO_OF_LOAN AS NoLoansTotal,
       PURCHASE_PRICE AS Price,
       CA_COPY.CREATE_DATETIME AS RegDate,
       CA_NOT_AVAILABLE_CAUSE.DESCR AS StatusName,
       GE_PREMISES_ID AS IdDepartment,
       LATEST_CAUGHT_DATETIME AS LastSeen,
       LABEL AS BarCode
FROM CA_COPY JOIN CA_CATALOG ON `ca_catalog.ca_catalog_id` = CA_CATALOG_ID
  LEFT OUTER JOIN CA_NOT_AVAILABLE_CAUSE USING (CA_NOT_AVAILABLE_CAUSE_ID)
  LEFT OUTER JOIN
    (SELECT CA_COPY_ID, CA_COPY_LABEL_ID, LABEL FROM CA_COPY_LABEL ORDER BY LABEL_TYPE ASC, CREATE_DATETIME DESC LIMIT 1) AS labels
    USING(CA_COPY_ID)
WHERE GE_ORG_ID_UNIT != 10000 AND (`ca_catalog.title_no` = ? OR CA_CATALOG_ID = ?)
