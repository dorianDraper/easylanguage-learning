{-------------------------------------------------------------------	
 Breakout v1 

 Description:
 - Breakout strategy based on the highest high and lowest low of the last 8 bars
 - Uses stop orders to enter the market on breakouts

-------------------------------------------------------------------}

Input:
        TrlgBars(8);

Vars:
	BuyPx(0),
	SellPx(0);

BuyPx = Highest(High, TrlgBars) + .02;
SellPx = Lowest(Low, TrlgBars) - .02;

{Setup entrada}
Buy ("BrkLE") Next Bar at BuyPx Stop;
SellShort ("BrkSE") Next Bar at SellPx Stop;