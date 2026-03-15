{-------------------------------------------------------------------
 Donchian Mean Reversion Strategy
 with Adaptive Position Sizing

 Description:
 Contrarian strategy that trades reversions after price reaches
 extremes defined by a Donchian channel.

 Position size dynamically adjusts based on strategy performance
 (NetProfit), increasing exposure during profitable periods and
 reducing risk during drawdowns.

-------------------------------------------------------------------}

Inputs:
	BaseTradeSize(1000),
	SizeStep(100),
	MaxTradeSize(2000),
	MinTradeSize(100),
	RiskUnit(500),
	DonchianLength(21);

Vars:

	{ Position sizing }

	TradeSize(0),
	TradeSizeAdjust(0),

	{ Channel levels }

	DonchianLow(0),
	DonchianHigh(0),

	{ Signals }

	LongSignal(false),
	ShortSignal(false),

	{ State }

	IsFlat(false);



{--------------------------------------------------
 Determine system state
--------------------------------------------------}

IsFlat = MarketPosition = 0;



{--------------------------------------------------
 Calculate Donchian channel levels
--------------------------------------------------}

DonchianLow  = Lowest(Low, DonchianLength)[1];
DonchianHigh = Highest(High, DonchianLength)[1];



{--------------------------------------------------
 Generate trading signals (mean reversion logic)
--------------------------------------------------}

LongSignal  = Low  < DonchianLow;
ShortSignal = High > DonchianHigh;



{--------------------------------------------------
 Adaptive position sizing based on strategy equity
--------------------------------------------------}

If AbsValue(NetProfit) >= RiskUnit Then
	TradeSizeAdjust = Round(NetProfit / RiskUnit, 0) * SizeStep
Else
	TradeSizeAdjust = 0;

TradeSize = BaseTradeSize + TradeSizeAdjust;



{--------------------------------------------------
 Enforce position size limits
--------------------------------------------------}

If TradeSize > MaxTradeSize Then
	TradeSize = MaxTradeSize
Else If TradeSize < MinTradeSize Then
	TradeSize = MinTradeSize;



{--------------------------------------------------
 Entry execution
--------------------------------------------------}

If IsFlat and LongSignal Then
	Buy ("Donchian_MR_LE") Next Bar TradeSize Shares at Market;

If IsFlat and ShortSignal Then
	SellShort ("Donchian_MR_SE") Next Bar TradeSize Shares at Market;



{--------------------------------------------------
 Risk management
--------------------------------------------------}

SetStopLoss(RiskUnit);
SetProfitTarget(RiskUnit);