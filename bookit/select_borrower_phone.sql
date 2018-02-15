
SELECT IF(CI_COUNTRY.ABBR != 'SE', CONCAT('+', REGEXP_REPLACE(LOCAL_CODE, PHONE_AREA_CODE_FORMAT, PHONE_COUNTRY_CODE)), LOCAL_CODE) AS PhoneNumber, 'T' AS Type FROM CI_BORR_PHONE LEFT OUTER JOIN CI_COUNTRY USING(CI_COUNTRY_ID) WHERE CI_BORR_ID = @BORR_ID := ?
UNION
SELECT EMAIL_ADDR AS PhoneNumber, 'E' AS Type FROM CI_BORR_EMAIL WHERE CI_BORR_ID = @BORR_ID;