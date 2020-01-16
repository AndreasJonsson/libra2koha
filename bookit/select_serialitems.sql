SELECT
  CA_COPY_ID as original_itemid,
  PE_RELEASE_ID as original_serialid
FROM PE_SUBSCR_ARR
JOIN CA_COPY USING(CA_COPY_ID)
JOIN PE_RELEASE USING(PE_RELEASE_ID)
WHERE PE_SUBSCRIPTION_ID=? AND PE_RELEASE_ID=?;
