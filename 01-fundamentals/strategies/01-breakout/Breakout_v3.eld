{-------------------------------------------------------------------	
 Breakout v3

 Description:
 - Adds risk management (stop loss, profit target, break even) to Breakout v2
 - Maintains legibility and semantic intention
-------------------------------------------------------------------}

Input:
	BuyLen(8),
	SellLen(8),
	StopPoints(.02),
	StopAmt(.2),
	TargetAmt(.3),
	BEAmt(.15);

Vars:
	BuyBrk(0),
	SellBrk(0);

BuyBrk = Highest(High, BuyLen) + StopPoints;
SellBrk = Lowest(Low, SellLen) - StopPoints;

{Setup de entrada}
Buy ("BrkLE") Next Bar at BuyBrk Stop;
SellShort ("BrkSE") Next Bar at SellBrk Stop;

{Setup de salida}
SetStopShare;

SetStopLoss(StopAmt);
SetProfitTarget(TargetAmt);
SetBreakeven(BEAmt);