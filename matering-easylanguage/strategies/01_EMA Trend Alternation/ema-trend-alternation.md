# EMA Trend Alternation Strategy — v1.0, v2.0 & v3.0

## Strategy Description

The EMA Trend Alternation Strategy is a trend-following system built around a single structural constraint: **directional alternation is mandatory**. After closing a long trade, the strategy cannot open another long until a short has been taken first — and vice versa. This enforced rotation is not a side effect of the logic; it is the defining architectural feature. Trend direction is determined by the relationship between a fast and a slow exponential moving average, and a configurable cooldown period prevents re-entry immediately after an exit. All positions are managed with fixed profit targets and stop losses.

---

## Core Mechanics

### 1. Trend Detection

Two exponential moving averages define the market's directional bias:

```pascal
FastEMA = XAverage(FastEMAPrice, FastEMALength);
SlowEMA = XAverage(SlowEMAPrice, SlowEMALength);

BullTrend = FastEMA > SlowEMA;
BearTrend = FastEMA < SlowEMA;
```

`XAverage` is EasyLanguage's native exponential moving average function. The relationship between the two EMAs acts as a simple trend filter: when the fast EMA is above the slow EMA, the strategy considers the market bullish; when below, bearish. Note that `BullTrend` and `BearTrend` are not mutually exclusive only if the two EMAs are exactly equal — in practice, one is always active.

### 2. Position State Machine

The strategy tracks current and previous position state explicitly:

```pascal
IsFlat  = MarketPosition =  0;
IsLong  = MarketPosition =  1;
IsShort = MarketPosition = -1;

PreviousPosition = MarketPosition(1);  // v2+ only
```

`MarketPosition(1)` returns the market position as of one trade ago — not one bar ago. This is the key function that enables the alternation logic: it tells the strategy what the *last closed trade* was, regardless of how many bars have elapsed since.

> **v1 note:** In v1, `MarketPosition(1)` is used inline within the entry conditions rather than stored in a named variable. v2 introduces `PreviousPosition` as a dedicated variable, which improves readability without changing behavior.

### 3. Cooldown and First Trade Conditions

```pascal
CooldownPassed = BarsSinceExit(1) >= CooldownBars;
FirstTrade     = TotalTrades = 0;
```

`BarsSinceExit(1)` returns the number of bars since the last exit from a long position. `TotalTrades = 0` identifies the very first trade of the strategy's life, when no previous position exists to alternate from. These two conditions together handle both the edge case (first ever trade) and the steady state (all subsequent trades).

### 4. Alternation Engine — Entry Logic

The entry conditions encode the alternation constraint directly:

```pascal
// Long entry: uptrend + (first trade OR previous was short + cooldown passed)
If (FirstTrade or (CooldownPassed and PreviousPosition = -1))
    and BullTrend Then
    Buy ("EMA_Trend_LE") Next Bar at Market;

// Short entry: downtrend + (first trade OR previous was long + cooldown passed)
If (FirstTrade or (CooldownPassed and PreviousPosition = 1))
    and BearTrend Then
    SellShort ("EMA_Trend_SE") Next Bar at Market;
```

The logic reads as: *"I can go long if this is my first trade ever, or if my last trade was short, the cooldown has passed, and the trend is currently bullish."* Three gates must open simultaneously: trend alignment, directional alternation, and time since last exit.

**Why this combination?** Each gate addresses a distinct failure mode:
- Without the **trend gate**, the strategy enters against the prevailing EMA direction.
- Without the **alternation gate**, consecutive longs or shorts are possible, defeating the core design principle.
- Without the **cooldown gate**, the strategy re-enters immediately after exit, increasing exposure to whipsaws.

### 5. Exit Framework

Both exit orders are placed simultaneously on every bar the strategy holds a position:

```pascal
// Long exits
Sell ("TP_LX") Next Bar at EntryPrice + ProfitTargetPoints Limit;
Sell ("SL_LX") Next Bar at EntryPrice - StopLossPoints Stop;

// Short exits
BuyToCover ("TP_SX") Next Bar at EntryPrice - ProfitTargetPoints Limit;
BuyToCover ("SL_SX") Next Bar at EntryPrice + StopLossPoints Stop;
```

EasyLanguage's order management ensures only one fills — whichever level is reached first. Once filled, the other order is automatically cancelled. This creates a fixed risk/reward structure on every trade without requiring any additional exit logic.

---

## v1 → v2 → v3: Code Architecture Evolution

The three versions implement identical trading logic. The evolution is entirely about code structure and readability.

### v1 — Functional but Compact

All logic is inline. `MarketPosition(1)` is called directly within the entry condition, and there is no separation between signal evaluation and order execution:

```pascal
If IsFlat Then
Begin
    If (FirstTrade or (CooldownPassed and MarketPosition(1) = -1))
        and BullTrend Then
        Buy ("EMA_Trend_LE") Next Bar at Market;
End;
```

This works, but mixing position state queries, timing conditions, and execution in a single block makes the logic harder to audit, especially as complexity grows.

### v2 — Named Variables and Structured Blocks

v2 introduces `PreviousPosition` as a dedicated variable and separates the code into clearly labelled blocks using EasyLanguage's `{-- comment --}` delimiters:

```pascal
PreviousPosition = MarketPosition(1);

{ Long entry: uptrend confirmed, previous was short, cooldown satisfied }
If (FirstTrade or (CooldownPassed and PreviousPosition = -1))
    and BullTrend Then
    Buy ("EMA_Trend_LE") Next Bar at Market;
```

The entry condition is now identical in structure but reads more clearly: `PreviousPosition = -1` is immediately understood as "last trade was short", whereas `MarketPosition(1) = -1` requires the reader to know what the `(1)` argument means.

### v3 — Signal/Execution Separation

v3 is the architectural endpoint. It introduces `LongSignal` and `ShortSignal` as explicit boolean variables, fully separating signal evaluation from order execution:

```pascal
{ SIGNAL ENGINE }
LongSignal =
    IsFlat and
    BullTrend and
    (FirstTrade or (CooldownPassed and PreviousPosition = -1));

ShortSignal =
    IsFlat and
    BearTrend and
    (FirstTrade or (CooldownPassed and PreviousPosition = 1));

{ EXECUTION ENGINE }
If LongSignal  Then Buy       ("EMA_Trend_LE") Next Bar at Market;
If ShortSignal Then SellShort ("EMA_Trend_SE") Next Bar at Market;
```

This pattern — compute the signal, then act on it — is the same architectural principle applied in Multi-Data Strategy v3/v4. The benefit is that each engine can be read, modified, and debugged independently. Adding a new filter to the signal is a one-line change to the signal block; changing the execution type (limit vs. market) only touches the execution block.

### Summary

| | v1.0 | v2.0 | v3.0 |
|---|---|---|---|
| **Trading logic** | ✓ | ✓ | ✓ |
| **Named `PreviousPosition`** | — | ✓ | ✓ |
| **Structured code blocks** | — | ✓ | ✓ |
| **Signal/Execution separation** | — | — | ✓ |
| **Parameters** | 7 | 7 | 7 |

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `FastEMAPrice` | Close | Price field used to calculate the fast EMA. |
| `FastEMALength` | 9 | Period for the fast EMA. Shorter = more responsive to recent price. |
| `SlowEMAPrice` | Close | Price field used to calculate the slow EMA. |
| `SlowEMALength` | 18 | Period for the slow EMA. Longer = smoother, slower trend representation. |
| `CooldownBars` | 3 | Minimum bars between exit and the next entry. Filters whipsaws. |
| `ProfitTargetPoints` | 1 | Points above (long) or below (short) entry for the profit target. |
| `StopLossPoints` | 0.5 | Points below (long) or above (short) entry for the stop loss. |

**On default risk parameters:** The default 1-point target and 0.5-point stop imply a 2:1 reward-to-risk ratio, but the absolute values are tight and primarily suited to high-liquidity intraday markets. These defaults should be treated as a starting point for backtesting, not production values.

---

## Trade Scenarios

### Scenario A — First Trade (Long)

- No prior trades: `TotalTrades = 0` → `FirstTrade = True`
- ES 15-min: FastEMA at 4,992, SlowEMA at 4,988 → `BullTrend = True`
- Alternation condition bypassed (first trade) → `LongSignal = True`
- **Buy next bar at market.** Entry fills at 4,993.
- Profit target placed at 4,994 (entry + 1 pt); stop loss at 4,992.5 (entry − 0.5 pt)
- Profit target fills. Trade closes at 4,994.

### Scenario B — Mandatory Short After Long

- Previous trade was long: `PreviousPosition = 1`
- `BarsSinceExit(1) = 4` ≥ `CooldownBars (3)` → `CooldownPassed = True`
- ES 15-min: FastEMA at 4,985, SlowEMA at 4,990 → `BearTrend = True`
- All short conditions met → `ShortSignal = True`
- **SellShort next bar at market.** Entry fills at 4,984.
- Profit target at 4,983 (entry − 1 pt); stop loss at 4,984.5 (entry + 0.5 pt)

### Scenario C — Long Blocked by Alternation

- Previous trade was also long: `PreviousPosition = 1`
- `CooldownPassed = True`
- ES 15-min: FastEMA rising above SlowEMA → `BullTrend = True`
- Alternation condition: `PreviousPosition = -1` required, but `PreviousPosition = 1`
- → `LongSignal = False`
- **No entry.** Strategy remains flat and waits for a short to complete the alternation cycle before a long can re-trigger.

### Scenario D — Long Blocked by Cooldown

- Previous trade was short: `PreviousPosition = -1` ✓
- `BarsSinceExit(1) = 2` < `CooldownBars (3)` → `CooldownPassed = False`
- `BullTrend = True` ✓
- Cooldown gate not satisfied → `LongSignal = False`
- **No entry.** Strategy waits one more bar for the cooldown window to clear.

---

## Key Features

- **Enforced directional alternation:** The mandatory long → short → long rotation is the strategy's defining structural constraint, not an incidental filter.
- **Three-gate entry:** Trend alignment, alternation compliance, and cooldown elapsed must all be satisfied simultaneously. Each gate addresses a distinct failure mode.
- **Signal/execution separation (v3):** The split into Signal Engine and Execution Engine makes the logic modular and easier to extend without introducing errors.
- **Fixed risk/reward per trade:** Profit target and stop loss are defined at entry, providing immediate position sizing clarity and eliminating discretionary exit decisions.
- **`FirstTrade` edge case handling:** The strategy correctly handles its first ever trade without requiring a prior position to alternate from.
- **Named order labels:** `TP_LX`, `SL_LX`, `TP_SX`, `SL_SX` enable trade-level performance breakdown by exit type in TradeStation's reports.

---

## Trade Psychology

The EMA Trend Alternation Strategy is built on a deceptively simple premise: **no trader — human or algorithmic — should be allowed to double down on the same directional bet without first testing the other side.**

Most trend-following systems accumulate directional exposure by adding to winners or re-entering the same direction repeatedly. The alternation constraint inverts this: after a long, the system is *required* to participate in a short before it can go long again. This creates a mechanical form of cognitive diversity — the system cannot become "stuck" in a bullish or bearish mode. Think of it as a rule that says: *"before you argue the same point again, you must genuinely argue the opposing one."*

The cooldown period reinforces this by adding a mandatory pause after every exit. Markets frequently whipsaw around moving average levels; the three-bar wait filters out the noisiest re-entries and forces the strategy to wait for conditions to re-establish rather than chasing every crossover.

The fixed profit target and stop loss remove the two most psychologically damaging decisions in discretionary trading — when to take profit and when to cut a loss — by encoding them as rules at the moment of entry. Once in a trade, the strategy has no decisions to make.

> **Open question for investigation:** Does the forced alternation help or hurt performance relative to an unrestricted version of the same system? The hypothesis is that it reduces drawdown by preventing directional overexposure, but this needs to be validated in backtesting across multiple instruments and market regimes.

---

## Use Cases

**Instruments:** Primarily suited to liquid intraday markets where fixed-point profit targets are executable without significant slippage — ES, NQ, and other equity index futures during regular trading hours. The tight default parameters (1 pt target, 0.5 pt stop) require consistent liquidity.

**Timeframes:** Designed for intraday use. The 9/18 EMA combination on 5-min or 15-min bars provides a reasonable trend filter without excessive lag. Wider timeframes will produce fewer trades and may require adjusting target and stop levels proportionally.

**Trader profile:** Well suited to systematic traders who want a fully mechanical strategy with no discretionary exit decisions. The alternation constraint makes it particularly interesting as a **diversification tool within a portfolio**: if running alongside a conventional trend-following strategy, the forced rotation provides a structural hedge against directional overexposure.

**Market conditions:** Performs best in markets with regular directional swings that allow both trend directions to play out within a session. Struggles in strongly one-directional markets where the alternation forces a short during a sustained uptrend — or vice versa. This is the core trade-off of the design and should be quantified in backtesting.

**On the default parameters:** The 1-point profit target and 0.5-point stop are a starting framework, not production-ready values. Both should be optimized per instrument and timeframe before live deployment.
