{-------------------------------------------------------------------
 EMA Trend Alternation Strategy v2

 Structure improvements:
	- Added PreviousPosition variable for cleaner entry logic
	- Separated signal generation from execution
	- Improved code readability and maintainability
-------------------------------------------------------------------}

Inputs:
	FastEMAPrice(Close), FastEMALength(9),
	SlowEMAPrice(Close), SlowEMALength(18),
	CooldownBars(3),
	ProfitTargetPoints(1),
	StopLossPoints(.5);

Vars:
	FastEMA(0),
	SlowEMA(0),

	BullTrend(false),
	BearTrend(false),

	IsFlat(false),
	IsLong(false),
	IsShort(false),

	PreviousPosition(0),

	CooldownPassed(false),
	FirstTrade(false);

{--------------------------------------------------
 Calculate trend indicators
--------------------------------------------------}
FastEMA = XAverage(FastEMAPrice, FastEMALength);
SlowEMA = XAverage(SlowEMAPrice, SlowEMALength);

{--------------------------------------------------
 Determine trend state
--------------------------------------------------}
BullTrend = FastEMA > SlowEMA;
BearTrend = FastEMA < SlowEMA;

{--------------------------------------------------
 Determine current position state
--------------------------------------------------}
IsFlat = MarketPosition = 0;
IsLong = MarketPosition = 1;
IsShort = MarketPosition = -1;

PreviousPosition = MarketPosition(1);

{--------------------------------------------------
 Trade timing conditions
--------------------------------------------------}
CooldownPassed = BarsSinceExit(1) >= CooldownBars;
FirstTrade = TotalTrades = 0;

{--------------------------------------------------
 Entry logic
--------------------------------------------------}
If IsFlat Then
Begin
	{ Long entry:
	  - Uptrend confirmed
	  - Either first trade or previous trade was short
	  - Cooldown period satisfied }
	If (FirstTrade or (CooldownPassed and PreviousPosition = -1))
		and BullTrend Then
		 Buy ("EMA_Trend_LE") Next Bar at Market;

	{ Short entry:
	  - Downtrend confirmed
	  - Either first trade or previous trade was long
	  - Cooldown period satisfied }
	If (FirstTrade or (CooldownPassed and PreviousPosition = 1))
		and BearTrend Then
		 SellShort ("EMA_Trend_SE") Next Bar at Market;
End;

{--------------------------------------------------
 Exit logic
--------------------------------------------------}
If IsLong Then
Begin
	{ Profit target }
	Sell ("TP_LX") Next Bar at EntryPrice + ProfitTargetPoints Limit;

	{ Stop loss }
	Sell ("SL_LX") Next Bar at EntryPrice - StopLossPoints Stop;
End;


If IsShort Then
Begin
	{ Profit target }
	BuyToCover ("TP_SX") Next Bar at EntryPrice - ProfitTargetPoints Limit;

	{ Stop loss } 
	BuyToCover ("SL_SX") Next Bar at EntryPrice + StopLossPoints Stop;
End;