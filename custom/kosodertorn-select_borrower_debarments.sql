SELECT
	NULL AS BlockedUntil,
	CASE MBLOCK
	     WHEN 'f' THEN 'Fakturerad'
	     WHEN 'k' THEN 'Kammarkollegiet'
	     WHEN 's' THEN 'Spärrad'
	     ELSE '' END AS Reason,
	current_date() AS RegDate,
	current_time() AS RegTime,
	current_date() AS UpdatedDate
FROM Borrowers WHERE `RECORD #(PATRON)` = ? AND MBLOCK IN ('f', 'k', 's');
