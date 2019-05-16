SELECT CA_COPY.CA_COPY_ID AS IdItem,
       GE_ORG_ID_UNIT AS IdBranchCode,
       CA_LOC_ID AS IdLocalShelf,
       NOTE AS Info,
       LATEST_LOAN_DATETIME AS LatestLoanDate,
       DEVIATING_LOCATION_MARC AS Location_Marc,
       OLD_NO_OF_LOAN AS NoOfLoansTotal,
       PURCHASE_PRICE AS Price,
       CA_COPY.CREATE_DATETIME AS RegDate,
       CA_NOT_AVAILABLE_CAUSE.DESCR AS StatusName,
       CI_CAT.DESCR AS LoanPeriodName,
       GE_PREMISES_ID AS IdDepartment,
       LATEST_CAUGHT_DATETIME AS LastSeen,
       LABEL AS BarCode,
       labels.row_number,
       IL_LOAN.IL_LOAN_ID IS NOT NULL AS IsRemote
FROM CA_COPY JOIN CA_CATALOG ON `ca_catalog.ca_catalog_id` = CA_COPY.CA_CATALOG_ID AND NOT CA_COPY.done
  LEFT OUTER JOIN CI_CAT USING(CI_CAT_ID)
  LEFT OUTER JOIN CA_NOT_AVAILABLE_CAUSE USING (CA_NOT_AVAILABLE_CAUSE_ID)
  LEFT OUTER JOIN labels
    ON labels.CA_COPY_ID = CA_COPY.CA_COPY_ID AND labels.row_number = 0
  LEFT OUTER JOIN IL_LOAN ON CA_COPY.CA_COPY_ID = IL_LOAN.CA_COPY_ID
WHERE `ca_catalog.title_no` = ?
UNION
SELECT CA_COPY.CA_COPY_ID AS IdItem,
       GE_ORG_ID_UNIT AS IdBranchCode,
       CA_LOC_ID AS IdLocalShelf,
       NOTE AS Info,
       LATEST_LOAN_DATETIME AS LatestLoanDate,
       DEVIATING_LOCATION_MARC AS Location_Marc,
       OLD_NO_OF_LOAN AS NoOfLoansTotal,
       PURCHASE_PRICE AS Price,
       CA_COPY.CREATE_DATETIME AS RegDate,
       CA_NOT_AVAILABLE_CAUSE.DESCR AS StatusName,
       CI_CAT.DESCR AS LoanPeriodName,
       GE_PREMISES_ID AS IdDepartment,
       LATEST_CAUGHT_DATETIME AS LastSeen,
       LABEL AS BarCode,
       labels.row_number,
       IL_LOAN.IL_LOAN_ID IS NOT NULL AS IsRemote
FROM CA_COPY JOIN CA_CATALOG ON `ca_catalog.ca_catalog_id` = CA_COPY.CA_CATALOG_ID AND NOT CA_COPY.done
  LEFT OUTER JOIN CI_CAT USING(CI_CAT_ID)
  LEFT OUTER JOIN CA_NOT_AVAILABLE_CAUSE USING (CA_NOT_AVAILABLE_CAUSE_ID)
  LEFT OUTER JOIN labels
    ON labels.CA_COPY_ID = CA_COPY.CA_COPY_ID AND labels.row_number = 0
  LEFT OUTER JOIN IL_LOAN ON CA_COPY.CA_COPY_ID = IL_LOAN.CA_COPY_ID
WHERE CA_COPY.CA_CATALOG_ID = ?;
