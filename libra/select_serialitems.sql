SELECT IdItem, BarCode  From Items JOIN BarCodes USING(IdItem) WHERE IdIssue = ?
