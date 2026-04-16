{-------------------------------------------------------------------
 Intermarket Filtered Trend Breakout Strategy v2

 Description:
 Strategy logic is identical to v1, but code has been refactored for improved readability and maintainability.
 
 Data Assumptions:
    Data1 = Primary Market (e.g. DAX / NQ)
    Data2 = Currency Filter (e.g. EURUSD)
    Data3 = Bond Filter (e.g. Bund / US20Y)

 Possible timeframes: 
 	> DAX --> 15MIN
 	> EURUSD --> 4H 
 	> BUND --> 1D  
-------------------------------------------------------------------}

Inputs:
    ChannelLength(20),
    ATRStopMultiplier(2),

    FastMALength(10),
    SlowMALength(50),

    BondCorrelation(-1),
    CurrencyCorrelation(-1),

    ProfitReentryThreshold(500);

Vars:
    {--------------------------------------------------
     Signal Engine
    --------------------------------------------------}
    LongTrendSignal(false),
    ShortTrendSignal(false),

    LongBreakoutLevel(0),
    ShortBreakoutLevel(0),

    {--------------------------------------------------
     Intermarket Filter Engine
    --------------------------------------------------}
    CurrencyLongFilter(false),
    CurrencyShortFilter(false),

    BondLongFilter(false),
    BondShortFilter(false),

    LongFilterPassed(false),
    ShortFilterPassed(false),

    {--------------------------------------------------
     Performance Tracking / Skip Logic
    --------------------------------------------------}
    ConsecutiveLosses(0),
    PreviousTotalTrades(0),
    SkipNextSignal(false),

    {--------------------------------------------------
     Position Management
    --------------------------------------------------}
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
        ConsecutiveLosses = 0;

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

{------------------------------
 Currency Filter
------------------------------}
CurrencyLongFilter =
       (CurrencyCorrelation = 0)
    or (CurrencyCorrelation = 1  and Close of Data2 > Average(Close of Data2, SlowMALength))
    or (CurrencyCorrelation = -1 and Close of Data2 < Average(Close of Data2, SlowMALength));

CurrencyShortFilter =
       (CurrencyCorrelation = 0)
    or (CurrencyCorrelation = 1  and Close of Data2 < Average(Close of Data2, SlowMALength))
    or (CurrencyCorrelation = -1 and Close of Data2 > Average(Close of Data2, SlowMALength));


{------------------------------
 Bond Filter
------------------------------}
BondLongFilter =
       (BondCorrelation = 0)
    or (BondCorrelation = 1  and Close of Data3 > Average(Close of Data3, SlowMALength))
    or (BondCorrelation = -1 and Close of Data3 < Average(Close of Data3, SlowMALength));

BondShortFilter =
       (BondCorrelation = 0)
    or (BondCorrelation = 1  and Close of Data3 < Average(Close of Data3, SlowMALength))
    or (BondCorrelation = -1 and Close of Data3 > Average(Close of Data3, SlowMALength));


LongFilterPassed  = CurrencyLongFilter  and BondLongFilter;
ShortFilterPassed = CurrencyShortFilter and BondShortFilter;


{===================================================================
 ENTRY ENGINE
===================================================================}
If MarketPosition = 0 Then
Begin

    {--------------------------------------------------
     Skip next signal after 3 consecutive losses
    --------------------------------------------------}
    SkipNextSignal = ConsecutiveLosses >= 3;


    {--------------------------------------------------
     Long Entry
    --------------------------------------------------}
    If LongTrendSignal and LongFilterPassed Then
    Begin

        If SkipNextSignal Then
            ConsecutiveLosses = 0
        Else
            Buy ("Breakout_LE") Next Bar LongBreakoutLevel Stop;

    End;


    {--------------------------------------------------
     Short Entry
    --------------------------------------------------}
    If ShortTrendSignal and ShortFilterPassed Then
    Begin

        If SkipNextSignal Then
            ConsecutiveLosses = 0
        Else
            SellShort ("Breakout_SE") Next Bar ShortBreakoutLevel Stop;

    End;

End;


{===================================================================
 POSITION MANAGEMENT / RE-ENTRY
===================================================================}
If MarketPosition <> 0 Then
Begin

    {--------------------------------------------------
     Pyramiding / Re-Entry
    --------------------------------------------------}
    If OpenPositionProfit > ProfitReentryThreshold Then
    Begin

        If MarketPosition = 1 Then
            Buy ("ReEntry_LE") Next Bar at Market;

        If MarketPosition = -1 Then
            SellShort ("ReEntry_SE") Next Bar at Market;

    End;

End;


{===================================================================
 REGIME EXIT ENGINE
===================================================================}
If MarketPosition = 1 and ShortFilterPassed Then
    Sell ("FilterExit_LX") Next Bar at Market;

If MarketPosition = -1 and LongFilterPassed Then
    BuyToCover ("FilterExit_SX") Next Bar at Market;


{===================================================================
 ATR TRAILING STOP ENGINE
===================================================================}
CurrentATR   = AvgTrueRange(SlowMALength);
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