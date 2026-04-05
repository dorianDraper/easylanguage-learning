{-------------------------------------------------------------------	
 Multi-Data v1

 Description:
 - Implements a long-only strategy that uses two different data series (timeframes) to confirm trade
   entries.
 - The strategy buys when the price on the primary timeframe (Data1) is above its moving average and 
 the price on the secondary timeframe (Data2) is also above its moving average, indicating a strong bullish trend across multiple timeframes.

 -------------------------------------------------------------------}

Input:
	MALenD1(20),
	MALenD2(50);

Vars:
	MAD1(0),
	MAD2(0);

MAD1 = Average(Close Data1, MALenD1);
MAD2 = Average(Close Data2, MALenD2);

{Setup de entrada}
If Close > MAD1 and Close Data2 > MAD2 Then
	Buy Next Bar at Market
Else
	Sell Next Bar at Market;