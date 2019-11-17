DELIMITER //
CREATE OR REPLACE FUNCTION valid_personnummer(s VARCHAR(256))
  RETURNS BOOLEAN
  BEGIN
    IF NOT s REGEXP '^((19)|(20))?[[:digit:]]{6}[\\-\\+]?[[:digit:]]{4}$' THEN
       RETURN FALSE;
    ELSE
       SET @s = REGEXP_REPLACE(s, '[\\-\\+]', '');
       SET @s0 = SUBSTRING(@s, LENGTH(@s) - 9);
       SET @d = SUBSTRING(@s0, 1, 6);
       IF (CAST(@d AS DATE) IS NULL) THEN
          RETURN FALSE;
       END IF;
       SET @i = 1;
       SET @sum = 0;
       WHILE @i <= 9 DO
         SET @t = CAST(SUBSTRING(@s0, @i, 1) AS INT);
	 SET @t0 = @t * (@i MOD 2 + 1);
	 SET @t1 = 0;
	 WHILE @t0 > 0 DO
	    SET @t1 = @t1 + @t0 MOD 10;
	    SET @t0 = FLOOR(@t0 / 10);
	 END WHILE;
	 SET @sum = @sum + @t1;
	 SET @i = @i + 1;
       END WHILE;
       SET @c = (10 - (@sum MOD 10)) MOD 10;
       RETURN CAST(SUBSTRING(@s0, 10) AS INT) = @c;
    END IF;
  END //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE FUNCTION valid_samordningsnummer(s VARCHAR(256))
  RETURNS BOOLEAN
  BEGIN
    IF NOT s REGEXP '^((19)|(20))?[[:digit:]]{6}[\\-\\+]?[[:digit:]]{4}$' THEN
       RETURN FALSE;
    ELSE
       SET @s = REGEXP_REPLACE(s, '[\\-\\+]', '');
       SET @s0 = SUBSTRING(@s, LENGTH(@s) - 9);
       SET @d0 = SUBSTRING(@s0, 1, 6);
       SET @x = CAST(SUBSTRING(@d0, 5) AS INT) - 60;
       IF (@x <= 0) THEN
          RETURN FALSE;
       END IF;
       SET @d = CONCAT(SUBSTRING(@d0, 1, 4), CAST(@x AS CHAR));
       IF (CAST(@d AS DATE) IS NULL) THEN
          RETURN FALSE;
       END IF;
       SET @i = 1;
       SET @sum = 0;
       WHILE @i <= 9 DO
         SET @t = CAST(SUBSTRING(@s0, @i, 1) AS INT);
	 SET @t0 = @t * (@i MOD 2 + 1);
	 SET @t1 = 0;
	 WHILE @t0 > 0 DO
	    SET @t1 = @t1 + @t0 MOD 10;
	    SET @t0 = FLOOR(@t0 / 10);
	 END WHILE;
	 SET @sum = @sum + @t1;
	 SET @i = @i + 1;
       END WHILE;
       SET @c = (10 - (@sum MOD 10)) MOD 10;
       RETURN CAST(SUBSTRING(@s0, 10) AS INT) = @c;
    END IF;
  END //
DELIMITER ;


