{-------------------------------------------------------------------	
 Trade Highs Lows v1

 Description:
 - Buy when price makes a new low for the last X bars
 - Sell when price makes a new high for the last X bars
 - Exit with a profit target and stop loss
 
 -------------------------------------------------------------------}

Input:
	LowsToBuy(2),
	HighsToSell(2),
	LimitPoints(.02),
	ProfTgt(50),
	StopLoss(50);

Vars:
	LowsCount(0),
	HighsCount(0);

If High > High[1] Then
	HighsCount = HighsCount + 1
Else
	HighsCount = 0;

If Low < Low[1] Then
	LowsCount = LowsCount + 1
Else
	LowsCount = 0;
	
{Setup de entrada}
If LowsCount >= LowsToBuy Then
	Buy Next Bar at Close of This Bar - LimitPoints Limit;
	
If HighsCount >= HighsToSell Then
	SellShort Next Bar at Close of This Bar + LimitPoints Limit;

{Setup de salida}
SetStopPosition;
SetProfitTarget(ProfTgt);
SetStopLoss(StopLoss);