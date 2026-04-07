{-------------------------------------------------------------------
	Consecutive Highs Short Fade v1

	Description:
	- Short entry strategy based on consecutive highs.
	- Sell short when the stock makes a new high for a specified number of consecutive bars.

-------------------------------------------------------------------}

Inputs:
	Price(High),
	ConsecutiveBarsUp(3),
	MinMoves(5);

Vars:
	MinMvs(0),
	UpCount(0);

MinMvs = Minmove/PriceScale * MinMoves;

If Price > Price[1] Then
	UpCount = UpCount + 1
Else
	UpCount = 0;

If UpCount >= ConsecutiveBarsUp Then 
Begin
	If LastBarOnChart Then
	Begin
		SetPeg(pegbest);
		SellShort ("ConsUpSE") Next Bar at InsideAsk - MinMvs Limit;
		SetPeg(pegdisable);
	End Else
	Begin
		SellShort ("ConsUpSEh") Next Bar at Close Limit;
	End;
End;