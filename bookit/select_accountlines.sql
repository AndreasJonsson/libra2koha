SELECT
  CI_BORR_ID AS IdBorrower,
  labels.LABEL AS ItemBarCode,
  CI_LOAN.CI_LOAN_ID IS NOT NULL AS has_transaction,
FROM CI_DEBT
LEFT OUTER JOIN CI_DEBT_PAYMENT USING(CA_DEBT_ID)
LEFT OUTER JOIN CA_COPY USING(CA_COPY_ID)
LEFT OUTER JOIN labels USING(CA_COPY_ID)
LEFT OUTER JOIN CI_BORR USING(CI_BORR_ID)
LEFT OUTER JOIN CI_LOAN ON CI_LOAN.CA_COPY_ID = CA_COPY.CA_COPY_ID AND CI_LOAN.CI_BORR_ID = CI_BORR.CI_BORR_ID
LEFT OUTER JOIN (SELECT CI_BORR_ID, GROUP_CONCAT(DISTINCT CI_BORR_CARD_ID ORDER BY LENGTH(CI_BORR_CARD_ID) DESC SEPARATOR ';') as barcodes FROM CI_BORR_CARD WHERE
                 NOT (valid_personnummer(CI_BORR_CARD_ID) OR valid_samordningsnummer(CI_BORR_CARD_ID))
                 GROUP BY CI_BORR_ID) AS barcodes
      ON (barcodes.CI_BORR_ID = CI_BORR.CI_BORR_ID)


$current_line->{IdBorrower}
->{ItemBarCode}

->{has_transaction}
->{Name}
->{ReservationBarCode}
->{Amount}
->{BarCode}
->{LastName}
->{FirstName}
 $row->{DateEnrolled}
  $row->{TransactionDate}
   $row->{RegDate}
    $row->{RegTime}
     $row->{Text}
      $row->{'IdBranchCode'}
       $row->{Name}
