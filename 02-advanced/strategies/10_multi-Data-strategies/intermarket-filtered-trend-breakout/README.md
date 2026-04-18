# Intermarket Filtered Trend Breakout — v1.0, v2.0 & v3.0

🇺🇸 English | 🇪🇸 [Español](README.es.md)

## Strategy Description

Intermarket Filtered Trend Breakout is a multi-data trend-following strategy that trades a primary market only when correlated secondary markets confirm the expected directional regime. The strategy combines three independent engines — a moving average trend filter, a Donchian-style channel breakout entry, and an intermarket confirmation filter — with position management features including an ATR trailing stop, profit-based pyramiding, regime-driven forced exits, and a skip-next-signal mechanism that pauses trading after consecutive losses.

The strategy requires three data feeds:

- **Data1** — Primary market (the instrument being traded, e.g. DAX futures, NQ)
- **Data2** — Currency filter market (e.g. EURUSD)
- **Data3** — Bond filter market (e.g. Bund futures, US 20Y)

The intermarket filters can be configured for positive correlation, negative correlation, or disabled entirely via the `CurrencyCorrelation` and `BondCorrelation` inputs. This makes the strategy adaptable to different intermarket relationships without code changes.

---

## Core Mechanics

### 1. Signal Engine — Trend and Breakout

The signal engine evaluates two conditions on Data1 on every bar:

```pascal
LongTrendSignal  = Average(Close, FastMALength) > Average(Close, SlowMALength);
ShortTrendSignal = Average(Close, FastMALength) < Average(Close, SlowMALength);

LongBreakoutLevel  = Highest(High, ChannelLength);
ShortBreakoutLevel = Lowest(Low, ChannelLength);
```

`LongTrendSignal` and `ShortTrendSignal` define the trend state using a fast/slow moving average crossover. They are continuous boolean states — not discrete crossing events — meaning they remain `True` for as long as the MA relationship holds, not just on the bar where the cross occurs.

`LongBreakoutLevel` and `ShortBreakoutLevel` are the Donchian channel boundaries: the highest high and lowest low over the last `ChannelLength` bars. Entry orders are placed as stop orders at these levels, so a trade only opens if price actually breaks out of the channel — the trend filter confirms the direction, the breakout confirms the momentum.

This two-layer entry logic — trend state plus price breakout — means the strategy does not enter simply because the MAs are aligned. It waits for the market to prove directional momentum by exceeding the channel boundary.

### 2. Intermarket Filter Engine

The filter engine evaluates Data2 (currency) and Data3 (bond) independently, then combines them:

```pascal
CurrencyLongFilter =
       (CurrencyCorrelation = 0)
    or (CurrencyCorrelation =  1 and Close of Data2 > Average(Close of Data2, FilterMALength))
    or (CurrencyCorrelation = -1 and Close of Data2 < Average(Close of Data2, FilterMALength));
```

Each filter has three possible states determined by its correlation input:

- **Correlation = 0:** Filter is disabled. Always passes. The secondary market is ignored for this direction.
- **Correlation = 1 (positive):** The filter passes for long entries when Data2 is above its MA — both markets trending in the same direction.
- **Correlation = -1 (negative):** The filter passes for long entries when Data2 is below its MA — the secondary market trending opposite to the primary, which in an inverse-correlation relationship is the confirming condition.

The short filter is the logical mirror of the long filter — where the long filter checks Data2 above its MA for positive correlation, the short filter checks Data2 below its MA. This symmetry means that if intermarket conditions favor longs, they automatically block shorts, and vice versa.

The two filters are combined with a logical `and`:

```pascal
LongFilterPassed  = CurrencyLongFilter  and BondLongFilter;
ShortFilterPassed = CurrencyShortFilter and BondShortFilter;
```

Both secondary markets must confirm for a trade to proceed. Either filter failing is sufficient to block entry.

### 3. Performance Tracking — Consecutive Loss Counter

```pascal
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
```

`TotalTrades > PreviousTotalTrades` detects that a new trade has just closed. `PositionProfit(1)` returns the profit of the most recently closed trade. On a loss, `ConsecutiveLosses` increments. On a win, both `ConsecutiveLosses` and `SkippedSignals` reset to zero — a winning trade clears the full state of any active pause period.

`PreviousTotalTrades` is updated every bar to track when new trades close, not just when they open.

### 4. Entry Engine — Skip Logic

```pascal
If MarketPosition = 0 Then
Begin
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
        If LongTrendSignal and LongFilterPassed Then
            Buy ("Breakout_LE") Next Bar LongBreakoutLevel Stop;

        If ShortTrendSignal and ShortFilterPassed Then
            SellShort ("Breakout_SE") Next Bar ShortBreakoutLevel Stop;
    End;
End;
```

When `ConsecutiveLosses` reaches `MaxConsecutiveLosses`, the entry block is bypassed and `SkippedSignals` increments instead. Once `SkippedSignals` reaches `SignalsToSkip`, both counters reset and normal entry resumes. Entry signals only fire in the `Else` branch — they are structurally blocked while the skip condition is active.

With `MaxConsecutiveLosses = 3` and `SignalsToSkip = 1`, the strategy skips exactly one qualifying signal after three consecutive losses, then resumes. Increasing `SignalsToSkip` extends the pause without changing the loss threshold.

### 5. Position Management — Pyramiding

```pascal
If OpenPositionProfit > ProfitReentryThreshold
    and PyramidCount < MaxPyramidLevels Then
Begin
    If MarketPosition = 1 Then
    Begin
        Buy ("ReEntry_LE") Next Bar at Market;
        PyramidCount = PyramidCount + 1;
    End;
    ...
End;
```

While in a position, if open profit exceeds `ProfitReentryThreshold` and the pyramid count has not reached `MaxPyramidLevels`, a second position is added at market. `PyramidCount` tracks how many re-entries have occurred and enforces the cap. Each re-entry adds a full position unit — the strategy can hold multiple simultaneous positions in the same direction.

`PyramidCount` resets to zero in two places: on a Regime Exit (explicit forced close) and when `MarketPosition` returns to flat (ATR stop or any other exit). This dual reset ensures no residual pyramid state carries into the next trade cycle.

### 6. Regime Exit Engine

```pascal
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
```

If the intermarket filters shift to favor the opposite direction while a position is open, the strategy exits immediately at market. This is not a stop loss — it is a regime change signal. The market context that justified the entry no longer holds.

The Regime Exit closes the **entire position**, including any pyramided units. A single market order liquidates all open contracts regardless of how many re-entries have occurred. This is the intended behavior — if the regime has shifted, all exposure in that direction should be removed.

### 7. ATR Trailing Stop Engine

```pascal
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
```

On entry (`BarsSinceEntry = 0`), the initial stop is placed `StopDistance` below the entry price for longs and above for shorts. On every subsequent bar, the stop ratchets in the direction of the trade: for longs, `MaxList` ensures the stop only moves up, never down; for shorts, `MinList` ensures the stop only moves down, never up. The stop locks in profit as the trade moves favorably while limiting downside if the trend reverses.

`StopDistance = ATRStopMultiplier * AvgTrueRange(ATRLength)` makes the stop proportional to recent volatility — wider in volatile periods, tighter in quiet ones.

---

## State Machine

```
┌─────────────┐
│    FLAT     │  Monitoring for entry conditions
└──────┬──────┘
       │ ConsecutiveLosses >= MaxConsecutiveLosses?
       ├── YES → Skip signal, increment SkippedSignals
       │         If SkippedSignals >= SignalsToSkip → reset both counters
       │
       │ TrendSignal and FilterPassed and not in skip mode
       ▼
┌─────────────────────────────────┐
│  BREAKOUT ORDER PLACED          │  Stop order at channel boundary
│  (Next Bar LongBreakoutLevel    │
│   / ShortBreakoutLevel Stop)    │
└──────┬──────────────────────────┘
       │ Price breaks channel boundary → order fills
       ▼
┌─────────────┐
│  LONG /     │  ATR trailing stop active
│  SHORT      │  Monitoring for pyramid and exit conditions
└──────┬──────┘
       │
       ├── OpenPositionProfit > ProfitReentryThreshold
       │   and PyramidCount < MaxPyramidLevels
       │         → Add position at market, PyramidCount++
       │
       ├── Regime shift (FilterPassed opposite direction)
       │         → FilterExit at market, PyramidCount = 0
       │
       └── ATRStop hit
                 → Exit at stop, PyramidCount = 0
┌─────────────┐
│    FLAT     │  Cycle complete
└─────────────┘
```

---

## v1 vs v2 vs v3: The Differences

### v1 — Functional but with structural issues

v1 implements the complete trading logic but with several readability and behavioral issues. Variable names mix Spanish and English (`sgLong`, `sgShort`, `flagSaltar`, `continuousLosses`). The skip logic uses `flagSaltar` — a flag initialized to `True` that toggles between skip states — which is harder to reason about than a counter. The ATR trailing stop and regime exits execute on every bar including when flat. No pyramid cap exists.

The `flagSaltar` bug: on a win, `continuousLosses` resets to `0` but `flagSaltar` is not explicitly reset in the `Else` branch — it retains whatever value it had from the previous state, potentially causing incorrect skip behavior after a loss-then-win sequence.

### v2 — Clean refactor, same logic

v2 renames all variables to descriptive English, separates logic into clearly labeled engine blocks, and replaces `flagSaltar` with `SkipNextSignal = ConsecutiveLosses >= 3` evaluated inline. The ATR and regime exit blocks move outside the position management block, which is a structural inconsistency — both execute when flat, wasting computation and creating potential edge cases.

The skip reset in v2 is more aggressive than v1: when a signal is skipped, `ConsecutiveLosses` resets immediately to `0`. This means the very next signal after a skip can enter without restriction, whereas v1 required an actual winning trade before fully clearing the skip state.

### v3 — Parametrized and structurally correct

v3 addresses all remaining issues from v2:

- **Skip logic is parametrized:** `MaxConsecutiveLosses` and `SignalsToSkip` replace the hardcoded `3` and `1`, making the pause behavior configurable and explicit. The skip counter resets only after `SignalsToSkip` signals have been bypassed — not immediately on the first skip.
- **ATR period is independent:** `ATRLength(14)` decouples the stop calculation from `SlowMALength`, using the Wilder standard period by default.
- **Filter MA period is independent:** `FilterMALength(20)` decouples the secondary market MA from the primary market's `SlowMALength`, acknowledging that secondary markets may operate on different timeframes.
- **Pyramid cap enforced:** `MaxPyramidLevels` limits re-entries. `PyramidCount` tracks and enforces the cap with dual reset logic.
- **ATR and regime exits encapsulated:** Both blocks are inside `If MarketPosition <> 0`, eliminating unnecessary computation when flat.
- **`SkippedSignals` resets on win:** A winning trade clears both `ConsecutiveLosses` and `SkippedSignals`, ensuring no stale skip state persists after the losing streak ends.

**Summary:**

| | v1.0 | v2.0 | v3.0 |
|---|---|---|---|
| **Core trading logic** | ✓ | ✓ | ✓ |
| **English variable names** | — | ✓ | ✓ |
| **Named engine blocks** | — | ✓ | ✓ |
| **Skip logic via flag (`flagSaltar`)** | ✓ | — | — |
| **Skip logic via counter** | — | ✓ | ✓ |
| **Parametrized skip (`MaxConsecutiveLosses`, `SignalsToSkip`)** | — | — | ✓ |
| **Independent ATR period (`ATRLength`)** | — | — | ✓ |
| **Independent filter MA period (`FilterMALength`)** | — | — | ✓ |
| **Pyramid cap (`MaxPyramidLevels`)** | — | — | ✓ |
| **ATR/exits encapsulated in position block** | — | — | ✓ |
| **`SkippedSignals` resets on win** | — | — | ✓ |
| **`PyramidCount` dual reset** | — | — | ✓ |

---

## Parameters

| Parameter | Default | Optimize? | Description |
|-----------|---------|-----------|-------------|
| `ChannelLength` | 20 | ✓ | Lookback for Donchian channel breakout levels. Larger values require more significant breakouts. |
| `FastMALength` | 10 | ✓ | Period for the fast moving average. Controls trend signal responsiveness. |
| `SlowMALength` | 50 | ✓ | Period for the slow moving average. Defines the trend reference on the primary market. |
| `FilterMALength` | 20 | Cautiously | MA period for secondary market filters. Independent of primary market MAs. Use walk-forward validation if optimized. |
| `ATRLength` | 14 | ✗ Fix | ATR period for trailing stop calculation. Fixed at Wilder standard — do not optimize. |
| `ATRStopMultiplier` | 2 | ✓ | Multiplier applied to ATR for stop distance. Higher values give the trade more room. |
| `CurrencyCorrelation` | -1 | ✗ Fix | Correlation direction for Data2. `1` = positive, `-1` = inverse, `0` = disabled. Set based on known economic relationship. |
| `BondCorrelation` | -1 | ✗ Fix | Correlation direction for Data3. Same convention as `CurrencyCorrelation`. |
| `ProfitReentryThreshold` | 500 | ✓ | Open profit required before a pyramid re-entry is allowed. |
| `MaxConsecutiveLosses` | 3 | ✗ Fix | Number of consecutive losses before skip logic activates. Risk management decision — do not optimize. |
| `SignalsToSkip` | 1 | ✗ Fix | Number of qualifying signals to bypass after a loss streak. Risk management decision — do not optimize. |
| `MaxPyramidLevels` | 1 | ✗ Fix | Maximum number of re-entries per trade cycle. Fix at 1 or 2. |

**On degrees of freedom:** Each optimizable parameter adds a dimension to the search space. As a rule of thumb, at least 30 trades per optimized parameter are needed for minimal statistical significance. With the three primary optimizable parameters (`ChannelLength`, `FastMALength`, `SlowMALength`) this strategy requires approximately 90 trades in the historical sample before optimization results are meaningful. Parameters marked "Fix" should be set by design logic, not by searching for the best historical value — doing so inflates in-sample performance without improving out-of-sample robustness.

**On `CurrencyCorrelation` and `BondCorrelation`:** These are economic hypotheses, not optimization targets. Setting them based on the known relationship between the primary market and the secondary markets (e.g. DAX tends to weaken when EURUSD strengthens, or equity futures tend to weaken when bond prices rise in risk-off regimes) gives the filters genuine predictive meaning. Flipping their sign until the backtest improves is a form of overfitting.

---

## Trade Scenarios

### Scenario A — Full Cycle: Entry, Pyramid, ATR Exit

- `LongTrendSignal = True`. `LongFilterPassed = True`. `ConsecutiveLosses = 1`. No skip active.
- Price breaks above `LongBreakoutLevel`. **`Breakout_LE` fills.**
- Position profitable. `OpenPositionProfit > 500`. `PyramidCount = 0 < MaxPyramidLevels = 1`.
- **`ReEntry_LE` fills at market.** `PyramidCount = 1`.
- Trend continues. ATR trailing stop ratchets up with each bar.
- Price reverses. `ATRStop_LX` hits. Both positions close. `PyramidCount = 0`. `ConsecutiveLosses = 0`.

### Scenario B — Skip Logic Activation

- Three consecutive losses. `ConsecutiveLosses = 3`.
- Bar with `LongTrendSignal = True` and `LongFilterPassed = True`. Skip active.
- **Signal bypassed.** `SkippedSignals = 1 >= SignalsToSkip = 1`. Both counters reset.
- Next qualifying signal: `ConsecutiveLosses = 0`. **Entry fires normally.**

### Scenario C — Regime Exit Mid-Trade

- Long position open. `PyramidCount = 1` (one re-entry active, two units long).
- Currency and bond filters shift. `ShortFilterPassed = True`.
- **`FilterExit_LX` fires at market.** Entire position (both units) closes. `PyramidCount = 0`.
- If this exit is a loss: `ConsecutiveLosses` increments on the next bar's tracking update.

### Scenario D — Filter Disabled, Trend-Only Operation

- `CurrencyCorrelation = 0`, `BondCorrelation = 0`.
- `LongFilterPassed = True` always (both filters disabled).
- Strategy operates on trend and breakout signals alone, without intermarket confirmation.
- This configuration is useful for baseline testing: comparing performance with and without filters active reveals the incremental value of the intermarket confirmation layer.

### Scenario E — Pyramid Cap Reached

- Long position open. `PyramidCount = 1 = MaxPyramidLevels`.
- `OpenPositionProfit > ProfitReentryThreshold` again on a subsequent bar.
- **Re-entry blocked** (`PyramidCount < MaxPyramidLevels` is False). No additional position added.

---

## Key Features

- **Three-engine architecture:** Signal, filter, and entry logic are separated into independent labeled blocks, making each component auditable and modifiable without touching the others.
- **Intermarket correlation inputs:** `CurrencyCorrelation` and `BondCorrelation` accept `1`, `-1`, or `0`, encoding the economic relationship as a parameter rather than hardcoded logic. Setting either to `0` disables the corresponding filter for baseline testing.
- **Independent MA periods (v3):** `FilterMALength` decouples secondary market filter evaluation from primary market trend detection. `ATRLength` decouples stop sensitivity from trend period.
- **Skip logic with dual counters (v3):** `ConsecutiveLosses` and `SkippedSignals` separate loss detection from pause management, making both thresholds independently configurable.
- **Pyramid cap (v3):** `MaxPyramidLevels` prevents unbounded position accumulation. `PyramidCount` resets on both forced exits and natural exits.
- **Regime exit as total liquidation:** `FilterExit` closes the entire position including all pyramided units. If the regime has shifted, all directional exposure is removed simultaneously.
- **ATR trailing stop encapsulated (v3):** All stop logic executes only when a position is open, eliminating unnecessary computation on flat bars.

---

## Trade Psychology

Intermarket Filtered Trend Breakout embodies a specific conviction: **a trend in isolation is less reliable than a trend confirmed by the broader macro regime.** A breakout on the primary market that occurs while correlated secondary markets are trending against it is a lower-quality signal than one where all markets are aligned. The filters do not generate trades — they gate them.

The skip logic reflects a pragmatic stance on losing streaks: rather than reducing position size or stopping trading entirely, the strategy takes a single breath after three consecutive losses. The assumption is that a short pause — sitting out one signal — may be enough to step over a period of poor market fit without abandoning the system entirely. It is not a risk management substitute; it is a behavioral governor.

The pyramid re-entry encodes conviction in running winners: when an existing position is already profitable, adding to it is rationally justified — the market has already validated the direction. The `MaxPyramidLevels` cap prevents this conviction from becoming recklessness.

The regime exit is the strategy's acknowledgment that no trend lasts forever in the same macro context. When the secondary markets shift, the primary market's trend loses its intermarket support — exiting immediately, rather than waiting for the ATR stop, reflects a structural view rather than a price-based one.

---

## Use Cases

**Instruments and data configurations:** The strategy is designed for instruments with identifiable intermarket relationships — equity index futures (DAX, NQ, ES) filtered by their associated currency and bond markets are the natural fit. The specific correlation directions should be set based on the known macro relationship: equity index / bond (typically inverse in risk-off regimes), equity index / currency (relationship varies by market — DAX/EURUSD is a common pair). Testing with `CurrencyCorrelation = 0` and `BondCorrelation = 0` first establishes the baseline trend-breakout edge before evaluating the incremental contribution of each filter.

**Timeframe considerations:** The strategy uses `SlowMALength` and `FilterMALength` as separate periods applied to their respective data feeds. Since Data1, Data2, and Data3 can operate on different bar intervals, the same numeric period means different things on each feed — 50 bars on a 15-minute chart is roughly 12 hours; 50 bars on a daily chart is ten weeks. Parameter values should be chosen with awareness of what each period represents in calendar time on each feed.

**Walk-forward validation:** Given the number of configurable parameters, walk-forward testing is strongly recommended over simple in-sample optimization. The parameters most sensitive to overfitting are `ChannelLength`, `FastMALength`, and `SlowMALength` on Data1. `FilterMALength` should be tested for robustness across a range of values rather than optimized to a single point.

**Portfolio role:** As a trend-following multi-data strategy, this component is most useful in a portfolio alongside mean-reversion strategies (which perform best in non-trending, range-bound conditions). The intermarket filter layer means it will generate fewer signals than a pure trend-breakout strategy — lower frequency, but higher-conviction entries.
