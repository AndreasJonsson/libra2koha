SELECT
  item.id AS IdItem,
  item.barcode AS BarCode,
  item.reference AS IdStatusCode,
  item.local_shelf AS IdLocalShelf,
  local_shelf.name AS Location_Marc,
  lending_time.label AS LoanPeriodName,
  branch.id AS IdBranchCode
FROM item
LEFT OUTER JOIN shelf ON shelf.id=item.shelf
LEFT OUTER JOIN local_shelf ON local_shelf.id=item.local_shelf
LEFT OUTER JOIN lending_time ON lending_time.id=item.lending_time
LEFT OUTER JOIN branch ON shelf.branch=branch.id
WHERE record_id = ?
