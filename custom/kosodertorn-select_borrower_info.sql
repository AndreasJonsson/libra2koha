SELECT DISTINCT `RECORD #(PATRON)` AS IdBorrower,
       `UNIQUE ID` AS `BorrowerAttribute:PNR`,
       CASE `PCODE2`
          WHEN '0' THEN 'Importerad'
	  WHEN '-' THEN 'Manuell'
	  WHEN 's' THEN 'Självregistrering'
	  ELSE ''
	  END AS `BorrowerAttribute:PCODE2`,
       IF(`P TYPE` IN (101, 102, 106, 108, 109),
          IF(`DEPT` !=  '', CONCAT(`DEPT`, '@suni.se'), NULL),
	  IF(`P TYPE` IN (121, 122, 128),
	     IF(`DEPT` != '', CONCAT(`DEPT`, '@rkh.se'), NULL),
	     `EMAIL ADDR`)) AS RegId,
       CURRENT_DATE() AS RegDate,
       `P BARCODE` AS BarCode,
       `P TYPE` AS IdBorrowerCategory,
       TRIM(IF(SUBSTRING(`PATRN NAME`, 1, LOCATE(', ', `PATRN NAME`) - 1) = '', `PATRN NAME`, SUBSTRING(`PATRN NAME`, 1, LOCATE(', ', `PATRN NAME`) - 1))) AS LastName,
       TRIM(SUBSTRING(IF(SUBSTRING(`PATRN NAME`, 1, LOCATE(', ', `PATRN NAME`) - 1) = '', '', `PATRN NAME`), LOCATE(', ', `PATRN NAME`) + 1)) AS FirstName,
       `EXP DATE` AS Expires,
       `NOTE` AS borrowernotes,
       `MESSAGE(Patron)` AS `Message`
FROM Borrowers
