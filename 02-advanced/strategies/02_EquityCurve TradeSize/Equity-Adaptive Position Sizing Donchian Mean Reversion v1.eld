{-------------------------------------------------------------------
Equity-Adaptive Position Sizing Donchian Mean Reversion Strategy v1

Description:
Mean reversion strategy based on Donchian channels. Entries occur when price makes a new high or low, 
with position sizing adjusted based on the strategy's equity performance.

Additional controls:
    - Dynamic position sizing based on NetProfit
    - Fixed profit target and stop loss based on EntryPrice
    
 -------------------------------------------------------------------}

Inputs:
	InitialTradeSize(1000),
	MaxTradeSize(2000),
	MinTradeSize(100),
	ProfitStopLoss(500);

Vars:
	TradeSize(0),
	TradeSizeAdjust(0),
	LongSetup(false),
	ShortSetup(false);

If NetProfit >= ProfitStopLoss or 
	NetProfit <= -ProfitStopLoss Then
		TradeSizeAdjust = Round((NetProfit / ProfitStopLoss), 0) * 100
Else
	TradeSizeAdjust = 0;

TradeSize = InitialTradeSize + TradeSizeAdjust;

If TradeSize > MaxTradeSize Then
	TradeSize = MaxTradeSize
Else If TradeSize < MinTradeSize Then
	TradeSize = MinTradeSize;
	
{Setup de entrada}
If Low < Lowest(Low, 21)[1] Then
	Buy Next Bar TradeSize Shares at Market;

If High > Highest(High, 21)[1] Then
	SellShort Next Bar TradeSize Shares at Market;

{Gestión del riesgo}
SetStopLoss(ProfitStopLoss);
SetProfitTarget(ProfitStopLoss);