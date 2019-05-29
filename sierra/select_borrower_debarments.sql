SELECT NULL AS BlockedUntil,
       NULL AS Reason,
       NULL AS RegDate,
       NULL AS RegTime,
       NULL AS UpdatedDate FROM Patrons WHERE `Systemnr(Patron)` = ? AND FALSE
