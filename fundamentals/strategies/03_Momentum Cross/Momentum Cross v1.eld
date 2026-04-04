{-------------------------------------------------------------------	
 Momentum Cross v1

 Description:
 - Buy when Momentum crosses above 0, Sell when it crosses below 0
 - Exit when Momentum changes direction (3 consecutive bars)
 - No filters, no limit orders, no stops
 - Very basic, not realistic, but good for learning
 - Next version will add filters and limit orders

-------------------------------------------------------------------}

Input:
	Price(Close),
	Length(10),
	BullLen(4),
	BearLen(4);

Vars:
	Mom(0),
	BullCx(false),
	BearCx(false);

Mom = Momentum(Price, Length);
BullCx = Mom Crosses Over 0;
BearCx = Mom Crosses Under 0;

{Setup de entrada}
If BullCx and MRO(BearCx, BearLen, 1) = -1 Then
	Buy Next Bar at Close of This Bar Limit;
If BearCx and MRO(BullCx, BullLen, 1) = -1 Then
	SellShort Next Bar at Close of This Bar Limit;

{Setup de salida}
If Mom < Mom[1] and Mom[1] < Mom[2] Then
	Sell Next Bar at Market;
If Mom > Mom[1] and Mom[1] > Mom[2] Then
	BuyToCover Next Bar at Market;