{-------------------------------------------------------------------
    Multi-Data Strategy v1.0
    Description:
    Simple multi-data strategy using moving averages from two different data series.
    Additional controls:
    - Entry based on the relationship between the two moving averages and price
    - Exit based on price crossing the moving average of the first data series
    
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
If MAValData2 > MAValData2[1] and Close > MAValData1 Then
	Buy Next Bar at Market;
	
If MAValData2 < MAValData2[1] and Close < MAValData1 Then
	SellShort Next Bar at Market;

// Setup de salida
If MarketPosition = 1 Then
	If High < MAValData1 Then
		Sell Next Bar at Market;

If MarketPosition = -1 Then 
	If Low > MAValData1 Then
		BuyToCover Next Bar at Market;