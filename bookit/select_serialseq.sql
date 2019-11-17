WITH
  idt AS (SELECT ? AS id FROM DUAL),
  level1 AS (SELECT * FROM PE_REL_PATTERN WHERE RULE_LEVEL=1),
  level2 AS (SELECT * FROM PE_REL_PATTERN WHERE RULE_LEVEL=2),
  level3 AS (SELECT * FROM PE_REL_PATTERN WHERE RULE_LEVEL=3)
SELECT level1.`SEQUENCE` AS serialseq_x, level2.`SEQUENCE` AS serialseq_y, level3.`SEQUENCE` AS serialseq_z FROM idt
  LEFT OUTER JOIN level1 ON idt.id = level1.PE_TITLE_ID
  LEFT OUTER JOIN level2 ON idt.id = level2.PE_TITLE_ID
  LEFT OUTER JOIN level3 ON idt.id = level3.PE_TITLE_ID;
