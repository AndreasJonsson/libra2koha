SELECT
    PE_RELEASE_ID AS original_id,
    RELEASE_NAME AS serialseq,
    PE_SUBSCRIPTION.PE_TITLE_ID AS serialseq_id,
     CA_SUPPLIER.DESCR AS Supplier,
    `ca_catalog.title_no` AS titleno,
     2 AS status -- ARRIVED
FROM PE_SUBSCR_ARR
JOIN PE_RELEASE USING(PE_RELEASE_ID)
JOIN PE_PERIOD USING(PE_PERIOD_ID)
JOIN PE_SUBSCRIPTION USING(PE_SUBSCRIPTION_ID)
JOIN PE_TITLE ON(PE_SUBSCRIPTION.PE_TITLE_ID = PE_TITLE.PE_TITLE_ID)
JOIN CA_CATALOG ON (PE_PERIOD.CA_CATALOG_ID = `ca_catalog.ca_catalog_id`)
LEFT OUTER JOIN CA_SUPPLIER ON CA_SUPPLIER_ID = `ca_catalog.ca_supplier_id`
WHERE PE_SUBSCRIPTION_ID=?;
