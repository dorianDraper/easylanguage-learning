{-------------------------------------------------------------------
    Multi-Data Strategy v2.0
    Description:
    Updated multi-data strategy with improved entry conditions and added market position check for entries.

    Additional controls:
    - Entry based on the relationship between the two moving averages and price, only when not already in a position
    
-------------------------------------------------------------------}
Inputs:
	MALenData1(12),
	MALenData2(24);

Vars:
	MAValData1(0),
	MAValData2(0, Data2);

MAValData1 = Average(Close, MALenData1);
MAValData2 = Average(Close, MALenData2) Data2;

// Setup de entrada
If MarketPosition = 0 Then
Begin

    If MAValData2 > MAValData2[1] and Close > MAValData1 Then
	Buy Next Bar at Market;
	
    If MAValData2 < MAValData2[1] and Close < MAValData1 Then
	SellShort Next Bar at Market;

End;

// Setup de salida
If MarketPosition = 1 Then
	If High < MAValData1 Then
		Sell Next Bar at Market;

If MarketPosition = -1 Then 
	If Low > MAValData1 Then
		BuyToCover Next Bar at Market;