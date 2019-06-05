SELECT
ADRESS AS Address1,
ADRESS2 AS Address2,
`LÅNT.KOD2` AS `State`
FROM Patrons WHERE `Systemnr(Patron)` = ?
