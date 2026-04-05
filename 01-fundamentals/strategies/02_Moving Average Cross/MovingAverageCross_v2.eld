{-------------------------------------------------------------------	
 Mov Avg Cross v2

 Description:
 - Improved version of v1 with added volume filter and configurable stop loss
 - Uses AverageFC for faster calculations and adapts volume measurement based on bar type

-------------------------------------------------------------------}

Input:
	FastPrice(Close), SlowPrice(Close),
	FastLen(9), SlowLen(18),
	VolLen(20),	MinHold(8),	MinProfit(100),
	SLAmt(500),	PositionBasis(true);

Vars:
	FastMA(0),
	SlowMA(0),
	AnyVol(0),
	AvgAnyVol(0);

// Normalización volumen
If BarType >= 2 and BarType < 5 Then	
	AnyVol = Volume
Else
	AnyVol = Ticks;

// Cálculo medias y volumen medio
AvgAnyVol = AverageFC(AnyVol, VolLen);
FastMA = AverageFC(FastPrice, FastLen);
SlowMA = AverageFC(SlowPrice, SlowLen);

// Setup de entrada: filtro volumen y eventos
Condition1 = AnyVol > AvgAnyVol;
If Condition1 Then
Begin
	If FastMA Crosses Over SlowMA Then
		Buy Next Bar at Market;
	
	If FastMA Crosses Under SlowMA Then
		SellShort Next Bar at Market; 
End;

{Setup de salida}
If BarsSinceEntry > MinHold and OpenPositionProfit < MinProfit Then
Begin
	Sell Next Bar at Market;
	BuyToCover Next Bar at Market;
End;

// SL flexible
If PositionBasis Then
	SetStopPosition
Else
	SetStopShare;

SetStopLoss(SLAmt);