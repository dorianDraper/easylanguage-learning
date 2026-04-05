{-------------------------------------------------------------------	
 RSI Overbought/Oversold v1

 Description:
 - Identifies potential reversal points based on the Relative Strength Index (RSI).
 - The strategy looks for situations where the RSI is on one side of the 50 level but has not made a new extreme in the last few bars, indicating a potential loss of momentum and a possible reversal.
-------------------------------------------------------------------}

Input:
	Price(Close),
	Length(14),
	StopAmt(50),
	TrlgAmt(100),
	BEAmt(50);

Vars:
	xRSI(0);

xRSI = RSI(Price, Length);

{Setup de entrada}
If xRSI < 50 and LowestBar(xRSI, 7) >= 3 Then
	Buy Next Bar at Market;
If xRSI > 50 and HighestBar(xRSI, 7) >= 3 Then
	SellShort Next Bar at Market;

{Setup de salida}
SetStopLoss(StopAmt);
SetBreakeven(BEAmt);
SetDollarTrailing(TrlgAmt);