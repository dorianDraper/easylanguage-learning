{-------------------------------------------------------------------
 EMA Trend Alternation Strategy v1

 Description:
 Trend-following strategy based on a fast and slow exponential
 moving average. Entries occur only in the direction of the current trend and
 only after the previous trade was in the opposite direction.

 Additional controls:
    - Cooldown period after exiting a trade
    - Symmetric long/short trade management
    - Fixed profit target and stop loss based on EntryPrice

-------------------------------------------------------------------}

Inputs:
	FastEMAPrice(Close), FastEMALen(9),
	SlowEMAPrice(Close), SlowEMALen(18),
	CooldownBars(3), ProfitTargetPoints(1), StopLossPoints(.5);

Vars:
	FastEMA(0),	SlowEMA(0),
	BullTrend(false), BearTrend(false),
	IsFlat(false), IsLong(false), IsShort(false),
	CooldownPassed(false),
	FirstTrade(false);

// Cálculo de EMAs
FastEMA = XAverage(FastEMAPrice, FastEMALen);
SlowEMA = XAverage(SlowEMAPrice, SlowEMALen);

// Estado tendencia
BullTrend = FastEMA > SlowEMA;
BearTrend = FastEMA < SlowEMA;

// State machine básica
IsFlat = MarketPosition = 0;
IsLong = MarketPosition = 1;
IsShort = MarketPosition = -1;

// Cooldown tras salida
CooldownPassed = BarsSinceExit(1) >= CooldownBars;
FirstTrade = TotalTrades = 0;

// Setup de entrada
If IsFlat Then
Begin
	// Largo: tendencia alcista y último trade fue corto 
	If (FirstTrade or (CooldownPassed and MarketPosition(1) = -1))
		and BullTrend Then
		 Buy ("EMA_Trend_LE") Next Bar at Market;
		 	
	// Corto: tendencia bajista y último trade fue larto
	If (FirstTrade or (CooldownPassed and MarketPosition(1) = 1))
		and BearTrend Then
		 SellShort ("EMA_Trend_SE") Next Bar at Market;
End;

// Setup de salida
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