{-------------------------------------------------------------------	
 Mov Avg Cross v1

 Description:
 - Moving Average Crossover strategy using simple moving averages
 - Enters long when the fast MA crosses above the slow MA, and short when it crosses below
 - Exits positions if they have been held for a minimum time and haven't reached a minimum profit

-------------------------------------------------------------------}

Input:
	ShortPrice(Close),
	LongPrice(Close),
	ShortLen(9),
	LongLen(18),
	MinHold(8),
	MinProfit(100);

Vars:
	ShortMA(0),
	LongMA(0);

ShortMA = Average(ShortPrice, ShortLen);
LongMA = Average(LongPrice, LongLen);

{Setup entrada}
If ShortMA Crosses Over LongMA Then
	Buy Next Bar at Market;
If ShortMA Crosses Under LongMA Then
	SellShort Next Bar at Market;

{Setup salida}
If BarsSinceEntry > MinHold and OpenPositionProfit < MinProfit Then
Begin
	Sell Next Bar at Market;
	BuyToCover Next Bar at Market;
End; 