{-------------------------------------------------------------------
 EMA Trend Alternation Strategy v3

 Adding Long/Short Signal / Execution Architecture
 Structure improvements:
	- Added LongSignal and ShortSignal variables for clearer logic separation
	- Cleaned up entry conditions for better readability
	- Maintained all previous improvements from v2
-------------------------------------------------------------------}

Inputs:
	FastEMAPrice(Close), FastEMALength(9),
	SlowEMAPrice(Close), SlowEMALength(18),
	CooldownBars(3),
	ProfitTargetPoints(1),
	StopLossPoints(.5);

Vars:
	{ Indicators }
	FastEMA(0),
	SlowEMA(0),

	{ Trend state }
	BullTrend(false),
	BearTrend(false),

	{ Position state }
	IsFlat(false),
	IsLong(false),
	IsShort(false),
	PreviousPosition(0),

	{ Timing }
	CooldownPassed(false),
	FirstTrade(false),

	{ Signals }
	LongSignal(false),
	ShortSignal(false);


{--------------------------------------------------
 Indicator calculation
--------------------------------------------------}
FastEMA = XAverage(FastEMAPrice, FastEMALength);
SlowEMA = XAverage(SlowEMAPrice, SlowEMALength);

{--------------------------------------------------
 Trend detection
--------------------------------------------------}
BullTrend = FastEMA > SlowEMA;
BearTrend = FastEMA < SlowEMA;

{--------------------------------------------------
 Position state
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
 SIGNAL ENGINE
--------------------------------------------------}
LongSignal =
	IsFlat and
	BullTrend and
	(FirstTrade or (CooldownPassed and PreviousPosition = -1));


ShortSignal =
	IsFlat and
	BearTrend and
	(FirstTrade or (CooldownPassed and PreviousPosition = 1));

{--------------------------------------------------
 EXECUTION ENGINE
--------------------------------------------------}
If LongSignal Then
	Buy ("EMA_Trend_LE") Next Bar at Market;


If ShortSignal Then
	SellShort ("EMA_Trend_SE") Next Bar at Market;

{--------------------------------------------------
 EXIT ENGINE
--------------------------------------------------}
If IsLong Then
Begin
	Sell ("TP_LX") Next Bar at EntryPrice + ProfitTargetPoints Limit;
	Sell ("SL_LX") Next Bar at EntryPrice - StopLossPoints Stop;
End;

If IsShort Then
Begin
	BuyToCover ("TP_SX") Next Bar at EntryPrice - ProfitTargetPoints Limit;
	BuyToCover ("SL_SX") Next Bar at EntryPrice + StopLossPoints Stop;
End;