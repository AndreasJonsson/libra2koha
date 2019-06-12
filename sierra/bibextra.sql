SELECT
  CASE `Bib kod 3`
    WHEN 'k' THEN 'Klav'
    WHEN 'p' THEN 'Part'
    WHEN 's' THEN 'Skill'
    ELSE NULL
  END AS `collection_code`,
  CASE `Bib kod 3`
    WHEN 't' THEN 'PJ'
    ELSE NULL
  END AS `local_shelf`
FROM `Bibliographic` WHERE `Systemnummer` = REGEXP_REPLACE(?, '^\\.', '');
