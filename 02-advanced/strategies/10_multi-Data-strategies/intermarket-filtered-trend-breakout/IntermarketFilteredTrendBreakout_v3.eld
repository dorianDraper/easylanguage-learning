{-------------------------------------------------------------------
 Intermarket Filtered Trend Breakout Strategy v3

 Description:
 Strategy logic is identical to v1/v2, but extends v2 with:
   - Parametrized skip logic (MaxConsecutiveLosses, SignalsToSkip)
   - Independent ATR period (ATRLength), fixed at Wilder standard (14)
   - Independent filter MA period (FilterMALength)
   - Pyramid level cap (MaxPyramidLevels)
   - ATR trailing stop encapsulated within open position block
   - Regime exit moved inside position management block

 Parameter guidance:
   - ATRLength: fix at 14 (Wilder standard) — do not optimize
   - MaxConsecutiveLosses: fix at 3 (risk management decision) — do not optimize
   - SignalsToSkip: fix at 1 (risk management decision) — do not optimize
   - MaxPyramidLevels: fix at 1 or 2 (risk decision) — do not optimize
   - FilterMALength: optimizable with caution — use walk-forward validation

 Data Assumptions:
    Data1 = Primary Market (e.g. DAX / NQ)
    Data2 = Currency Filter (e.g. EURUSD)
    Data3 = Bond Filter (e.g. Bund / US20Y)
-------------------------------------------------------------------}

Inputs:
    {--- Signal Engine ---}
    ChannelLength(20),
    FastMALength(10),
    SlowMALength(50),

    {--- Intermarket Filter Engine ---}
    BondCorrelation(-1),
    CurrencyCorrelation(-1),
    FilterMALength(20),         // Independent MA period for secondary markets

    {--- ATR Trailing Stop ---}
    ATRLength(14),              // Wilder standard — fix, do not optimize
    ATRStopMultiplier(2),

    {--- Skip Logic ---}
    MaxConsecutiveLosses(3),    // Losses before pause — fix, do not optimize
    SignalsToSkip(1),           // Signals to skip after pause — fix, do not optimize

    {--- Pyramiding ---}
    ProfitReentryThreshold(500),
    MaxPyramidLevels(1);        // Max re-entries allowed — fix at 1 or 2


Vars:
    {--- Signal Engine ---}
    LongTrendSignal(false),
    ShortTrendSignal(false),
    LongBreakoutLevel(0),
    ShortBreakoutLevel(0),

    {--- Intermarket Filter Engine ---}
    CurrencyLongFilter(false),
    CurrencyShortFilter(false),
    BondLongFilter(false),
    BondShortFilter(false),
    LongFilterPassed(false),
    ShortFilterPassed(false),

    {--- Performance Tracking ---}
    ConsecutiveLosses(0),
    PreviousTotalTrades(0),
    SkippedSignals(0),

    {--- Position Management ---}
    PyramidCount(0),
    CurrentATR(0),
    StopDistance(0),
    TrailingStopPrice(0);


{===================================================================
 PERFORMANCE TRACKING
===================================================================}
If TotalTrades > PreviousTotalTrades Then
Begin
    If PositionProfit(1) < 0 Then
        ConsecutiveLosses = ConsecutiveLosses + 1
    Else
    Begin
        ConsecutiveLosses = 0;
        SkippedSignals    = 0;
    End;
End;

PreviousTotalTrades = TotalTrades;


{===================================================================
 SIGNAL ENGINE
===================================================================}
LongTrendSignal  = Average(Close, FastMALength) > Average(Close, SlowMALength);
ShortTrendSignal = Average(Close, FastMALength) < Average(Close, SlowMALength);

LongBreakoutLevel  = Highest(High, ChannelLength);
ShortBreakoutLevel = Lowest(Low, ChannelLength);


{===================================================================
 INTERMARKET FILTER ENGINE
===================================================================}

{--- Currency Filter ---}
CurrencyLongFilter =
       (CurrencyCorrelation = 0)
    or (CurrencyCorrelation =  1 and Close of Data2 > Average(Close of Data2, FilterMALength))
    or (CurrencyCorrelation = -1 and Close of Data2 < Average(Close of Data2, FilterMALength));

CurrencyShortFilter =
       (CurrencyCorrelation = 0)
    or (CurrencyCorrelation =  1 and Close of Data2 < Average(Close of Data2, FilterMALength))
    or (CurrencyCorrelation = -1 and Close of Data2 > Average(Close of Data2, FilterMALength));

{--- Bond Filter ---}
BondLongFilter =
       (BondCorrelation = 0)
    or (BondCorrelation =  1 and Close of Data3 > Average(Close of Data3, FilterMALength))
    or (BondCorrelation = -1 and Close of Data3 < Average(Close of Data3, FilterMALength));

BondShortFilter =
       (BondCorrelation = 0)
    or (BondCorrelation =  1 and Close of Data3 < Average(Close of Data3, FilterMALength))
    or (BondCorrelation = -1 and Close of Data3 > Average(Close of Data3, FilterMALength));

LongFilterPassed  = CurrencyLongFilter  and BondLongFilter;
ShortFilterPassed = CurrencyShortFilter and BondShortFilter;


{===================================================================
 ENTRY ENGINE
===================================================================}
If MarketPosition = 0 Then
Begin

    {--- Skip Logic ---}
    If ConsecutiveLosses >= MaxConsecutiveLosses Then
    Begin
        SkippedSignals = SkippedSignals + 1;

        If SkippedSignals >= SignalsToSkip Then
        Begin
            ConsecutiveLosses = 0;
            SkippedSignals    = 0;
        End;

    End Else
    Begin

        {--- Long Entry ---}
        If LongTrendSignal and LongFilterPassed Then
            Buy ("Breakout_LE") Next Bar LongBreakoutLevel Stop;

        {--- Short Entry ---}
        If ShortTrendSignal and ShortFilterPassed Then
            SellShort ("Breakout_SE") Next Bar ShortBreakoutLevel Stop;

    End;

End;


{===================================================================
 POSITION MANAGEMENT
===================================================================}
If MarketPosition <> 0 Then
Begin

    {--- Pyramiding / Re-Entry ---}
    If OpenPositionProfit > ProfitReentryThreshold
        and PyramidCount < MaxPyramidLevels Then
    Begin
        If MarketPosition = 1 Then
        Begin
            Buy ("ReEntry_LE") Next Bar at Market;
            PyramidCount = PyramidCount + 1;
        End;

        If MarketPosition = -1 Then
        Begin
            SellShort ("ReEntry_SE") Next Bar at Market;
            PyramidCount = PyramidCount + 1;
        End;
    End;

    {--- Regime Exit ---}
    If MarketPosition = 1 and ShortFilterPassed Then
    Begin
        Sell ("FilterExit_LX") Next Bar at Market;
        PyramidCount = 0;
    End;

    If MarketPosition = -1 and LongFilterPassed Then
    Begin
        BuyToCover ("FilterExit_SX") Next Bar at Market;
        PyramidCount = 0;
    End;

    {--- ATR Trailing Stop ---}
    CurrentATR   = AvgTrueRange(ATRLength);
    StopDistance = ATRStopMultiplier * CurrentATR;

    If BarsSinceEntry = 0 Then
        TrailingStopPrice = EntryPrice - MarketPosition * StopDistance;

    If MarketPosition = 1 Then
    Begin
        TrailingStopPrice = MaxList(TrailingStopPrice, Close - StopDistance);
        Sell ("ATRStop_LX") Next Bar TrailingStopPrice Stop;
    End;

    If MarketPosition = -1 Then
    Begin
        TrailingStopPrice = MinList(TrailingStopPrice, Close + StopDistance);
        BuyToCover ("ATRStop_SX") Next Bar TrailingStopPrice Stop;
    End;

End;


{===================================================================
 PYRAMID RESET ON FLAT
===================================================================}
If MarketPosition = 0 and PreviousTotalTrades <> TotalTrades Then
    PyramidCount = 0;