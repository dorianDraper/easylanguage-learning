# Consecutive Highs Short Fade — v1.0

🇺🇸 English | 🇪🇸 [Español](README.es.md)

## Strategy Description

Consecutive Highs Short Fade is a short-only mean-reversion strategy that enters a short position after a configurable number of consecutive bars each making a higher high than the previous bar. It is the directional inverse of TradeStation's built-in `ConsecutiveUps LE` strategy — where the original enters long on consecutive strength, this version fades that strength with a short entry. The strategy introduces ECN pegging orders for live execution, using `InsideAsk` and `SetPeg(pegbest)` to target the best available price in the order book rather than a fixed limit price. In backtesting, a close-based limit order approximates the live behavior.

The strategy has no exit rules by design — it is a focused entry mechanism intended to be paired with external stop loss, profit target, or trailing stop components.

---

## Core Mechanics

### 1. Consecutive Highs Counter

```pascal
If Price > Price[1] Then
    UpCount = UpCount + 1
Else
    UpCount = 0;
```

`Price` defaults to `High` — the strategy tracks whether each bar's high exceeds the previous bar's high. `UpCount` increments by one on every qualifying bar and resets to zero the moment any bar fails to make a new high. This is identical in structure to the `HighsCount` counter in Consecutive Extremes Fade, but applied only to the long side as a setup for a short fade entry.

With `ConsecutiveBarsUp = 3`, the entry condition `UpCount >= 3` requires three consecutive bars each making a higher high. The counter does not require the highs to exceed a longer-term level — only that each bar's high exceeds the immediately preceding bar's high. This detects short-term directional momentum streaks, not channel breakouts.

### 2. Tick Size Calculation

```pascal
MinMvs = Minmove / PriceScale * MinMoves;
```

`Minmove` and `PriceScale` are EasyLanguage reserved constants that together define the minimum price movement (one tick) for the current instrument:

- `Minmove`: the numerator of the tick size expression (e.g. 25 for ES futures, where ticks are 0.25 points).
- `PriceScale`: the denominator (e.g. 100 for ES, giving `25/100 = 0.25` points per tick).
- `Minmove / PriceScale`: the value of one tick in price terms.

Multiplying by `MinMoves` (default: 5) gives a distance of 5 ticks. This calculation makes the offset instrument-agnostic — the same `MinMoves = 5` parameter produces the correct 5-tick distance for ES futures, NQ futures, or any other instrument without hardcoding a dollar or point amount.

**Example for ES futures:**
- `Minmove = 25`, `PriceScale = 100` → one tick = 0.25 points.
- `MinMvs = 0.25 × 5 = 1.25 points` below `InsideAsk`.

### 3. Dual Execution Path — Live vs Historical

The strategy uses different execution logic depending on whether the bar is live or historical:

```pascal
If UpCount >= ConsecutiveBarsUp Then
Begin
    If LastBarOnChart Then
    Begin
        SetPeg(pegbest);
        SellShort ("ConsUpSE") Next Bar at InsideAsk - MinMvs Limit;
        SetPeg(pegdisable);
    End Else
    Begin
        SellShort ("ConsUpSEh") Next Bar at Close Limit;
    End;
End;
```

**Live bar (`LastBarOnChart = True`):**

`SetPeg(pegbest)` activates ECN pegging before placing the order. With pegging active, the limit price is anchored dynamically to the best available price in the order book rather than a fixed price calculated at bar close. `InsideAsk - MinMvs` places the short limit `MinMvs` ticks below the current inside ask — the lowest sell price currently available in the market. The order is submitted as a peg-best limit, then `SetPeg(pegdisable)` turns off pegging for subsequent orders in the same bar evaluation.

**Why `InsideAsk - MinMvs` for a short?** For a short entry, selling at the inside ask means entering at the best available price a seller can receive. Subtracting `MinMvs` ticks places the limit slightly below the current ask — the order will only fill if the price dips to that level, providing a marginally better entry than hitting the current ask directly. This is an aggressive but controlled short entry: not chasing the market, but also not requiring a significant pullback.

**Historical bar (`LastBarOnChart = False`):**

`InsideAsk` does not exist on historical bars — it is a real-time order book value. The strategy falls back to `Close` as the limit price for backtesting. The order label `"ConsUpSEh"` (the trailing `h` indicating historical) distinguishes backtesting fills from live fills in TradeStation's reports, allowing separate analysis of historical versus live execution quality.

### 4. ECN Pegging — `SetPeg`

`SetPeg` is an EasyLanguage function that controls order routing behavior for ECN-compatible brokers:

- `SetPeg(pegbest)`: instructs the broker to peg the order to the best bid or ask in the order book. As the inside price moves, the peg order adjusts dynamically — this is different from a standard limit order, which stays fixed at the submitted price.
- `SetPeg(pegdisable)`: disables pegging, restoring standard order behavior for subsequent orders.

The `SetPeg` call wraps only the specific short entry order. Any other orders placed after `SetPeg(pegdisable)` behave as standard limit or market orders.

**Important:** `SetPeg` has no effect in backtesting — it is a live execution instruction. TradeStation ignores it during historical simulation, which is why the strategy uses the `LastBarOnChart` branch separation.

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Price` | `High` | Price series used to detect consecutive higher bars. |
| `ConsecutiveBarsUp` | 3 | Minimum number of consecutive higher `Price` values required to trigger a short entry. |
| `MinMoves` | 5 | Number of ticks below `InsideAsk` for the live limit order price. |

**On `ConsecutiveBarsUp`:** Three consecutive higher highs is the minimum meaningful streak for a fade entry. At `= 2`, the signal fires very frequently and may catch too much normal intraday oscillation. At `= 4` or `= 5`, the signal becomes rarer but potentially more reliable as it requires a more sustained momentum run before fading.

**On `MinMoves`:** The tick-based offset provides a small price improvement over entering directly at `InsideAsk`. A value of 5 ticks is a practical starting point — small enough to fill with reasonable frequency, large enough to provide a measurable entry improvement. On highly liquid instruments (ES, NQ), 5 ticks is a very small distance and fills quickly. On less liquid instruments, it may require a more significant intrabar move to fill.

---

## Trade Scenarios

### Scenario A — Live Short Entry After Three Consecutive Higher Highs

```
Bar:    1      2      3      4
High:  46.20  46.45  46.68  46.90
UpCount: 1      2      3      4
```

- Bar 4: `UpCount = 4 >= ConsecutiveBarsUp (3)`. Signal fires.
- `LastBarOnChart = True`. Live execution path.
- `InsideAsk = 46.92`. `MinMvs = 0.25 × 5 = 1.25` (ES example).
- `SetPeg(pegbest)` activates.
- Short limit placed at `46.92 − 1.25 = 45.67`. *(Note: in practice MinMvs would be much smaller — this example uses a wide value for illustration.)*
- `SetPeg(pegdisable)`.
- Next bar: price dips to fill level. Short fills.

### Scenario B — Historical Short Entry (Backtesting)

- Same setup. `LastBarOnChart = False`.
- `SetPeg` is not called. No `InsideAsk` access.
- Short limit placed at `Close` of signal bar.
- Order labeled `"ConsUpSEh"` for differentiation from live fills.

### Scenario C — Streak Broken, No Entry

```
Bar:    1      2      3
High:  46.20  46.45  46.38
UpCount: 1      2      0
```

- Bar 3: `High (46.38) < High[1] (46.45)`. `UpCount` resets to 0.
- Streak broken on bar 3. No entry fires despite two consecutive higher highs on bars 1–2.

### Scenario D — Entry Fires, No Exit (Entry-Only Design)

- Short position opens. No stop loss or profit target is defined in this strategy.
- Position remains open until an external exit component closes it, or a manual exit is placed.
- This confirms the entry-only design intent — this strategy must be paired with a risk management component for live use.

---

## Key Features

- **ECN pegging for live execution:** `SetPeg(pegbest)` + `InsideAsk` targets the best available order book price dynamically rather than a fixed close-based level, providing more precise live entry execution.
- **Tick-based distance calculation:** `Minmove / PriceScale * MinMoves` makes the limit offset instrument-agnostic, adapting automatically to the tick structure of any futures contract without hardcoded parameters.
- **Dual execution path:** Separate live and historical order logic allows realistic backtesting (using `Close` as a proxy) while preserving the advanced ECN execution for live trading.
- **Named order labels with suffix:** `"ConsUpSE"` for live fills and `"ConsUpSEh"` for historical fills enables separate performance analysis of each path in TradeStation's trade-by-trade reports.
- **Short-only direction:** The strategy exclusively fades upward streaks with short entries — it is the directional inverse of the `ConsecutiveUps LE` built-in strategy.
- **No exits by design:** The strategy is an entry component only, intended to be paired with stop loss, profit target, or trailing stop logic from other components.

---

## Consecutive Highs Detector — Indicator

The Consecutive Highs Detector is a companion indicator that runs the same `UpCount` logic as the strategy and visualizes the streak count directly on the chart bar by bar. It serves as a real-time monitoring tool: traders can see the current streak building before it reaches the entry threshold, and receive an audible and visual alert the moment the signal fires.

```pascal
Inputs:
    Price(High),
    ConsecutiveBarsUp(3);

Vars:
    PlotTxt(""),
    UpCount(0);

If Price > Price[1] Then
    UpCount = UpCount + 1
Else
    UpCount = 0;

If UpCount >= ConsecutiveBarsUp Then
Begin
    PlotTxt = "Sell";
    SetPlotBGColor(1, Darkred);
    SetPlotColor(1, White);
    Alert;
End
Else
    PlotTxt = Numtostr(UpCount, 0);

Plot1(PlotTxt, "Sell");
```

**How it displays:**

- While a streak is building but below the threshold, each bar shows its current `UpCount` value as a number (e.g. `"1"`, `"2"`). This gives real-time visibility into how close the streak is to triggering.
- When `UpCount >= ConsecutiveBarsUp`, the bar displays `"Sell"` with a dark red background and white text — a high-contrast visual signal — and fires TradeStation's `Alert` function for an audible notification.
- When the streak resets, the display returns to `"0"` on the reset bar and increments from there on subsequent higher highs.

**Parameters** (identical to the strategy):

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Price` | `High` | Price series used to detect consecutive higher bars. Must match the strategy setting. |
| `ConsecutiveBarsUp` | 3 | Threshold at which the visual and audible alert fires. Must match the strategy setting. |

> **Usage note:** Keep `Price` and `ConsecutiveBarsUp` identical between the indicator and the strategy to ensure the visual signal fires on exactly the same bar as the strategy's entry order. A mismatch between settings would cause the indicator to alert on a different bar than the strategy actually enters.

**Indicator vs Strategy — when to use each:**

| | Consecutive Highs Detector | Consecutive Highs Short Fade |
|---|---|---|
| Executes trades | No | Yes |
| Shows streak count | Yes | No |
| Fires alert | Yes | No |
| Useful in backtesting | Yes (visual review) | Yes (order generation) |
| Useful in live trading | Yes (monitoring layer) | Yes (execution layer) |

In live trading, both should be active simultaneously: the indicator provides the visual dashboard and early warning as the streak builds, while the strategy handles the actual order submission when the threshold is reached.

---

## Trade Psychology

Consecutive Highs Short Fade encodes a specific market belief: **a streak of consecutive higher highs represents short-term momentum overextension, not the beginning of a sustained trend.** Where a trend-following strategy sees three consecutive higher highs as confirmation of a move worth joining, this strategy sees the same pattern as an opportunity to fade — the move has already happened and is more likely to pause or reverse than to accelerate.

This is a fundamentally contrarian stance. The psychological challenge is entering short precisely when the market is making successive new highs — when every bar seems to confirm that buyers are in control. The strategy's edge, if any, comes from the statistical tendency for short-term momentum streaks to exhaust themselves at the bar level before a mean-reversion occurs.

The ECN pegging mechanism adds a layer of execution sophistication that reflects the strategy's design intent. A market order at the peak of a momentum streak would give up significant edge to adverse selection — entering at the worst possible price in a still-moving market. The peg-best limit order at `InsideAsk - MinMvs` seeks a slightly better price while remaining close enough to the market to fill with high probability. It is an aggressive entry that does not chase, but does not require a significant reversal to fill.

The absence of exits is also a psychological statement: the strategy does not pretend to know how far the reversal will go or when to take profit. It focuses entirely on the entry signal, delegating the exit decision to separate, purpose-built components. This separation of concerns allows each component to be tested and optimized independently.

---

## Use Cases

**Instruments:** Designed for liquid futures contracts where ECN order routing and `InsideAsk` data are available — ES, NQ, and other actively traded equity index futures during regular trading hours. The tick-based `MinMoves` calculation adapts to any instrument's tick structure. On less liquid instruments, the `InsideAsk - MinMvs` limit may not fill reliably during live trading.

**Timeframes:** The consecutive higher highs pattern is timeframe-relative. On 1-min bars, three consecutive higher highs spans three minutes; on 15-min bars it spans 45 minutes. The appropriate timeframe depends on the mean-reversion hypothesis being tested — very short-term momentum exhaustion versus multi-bar trend fades are different trading ideas requiring different timeframe calibration.

**Integration with risk components:** This strategy must be paired with an exit component before live deployment. Natural pairings include ATRDollar TrailStop for a volatility-adaptive trailing exit, or fixed stop loss and profit target via `SetStopLoss` and `SetProfitTarget`. AccountRiskCore provides account-level daily loss protection independent of the per-trade exit logic.

**Relationship to `ConsecutiveUps LE`:** TradeStation's built-in `ConsecutiveUps LE` enters long on consecutive higher closes. This strategy enters short on consecutive higher highs — a directional inversion with a different price series (`High` instead of `Close`). Running both simultaneously on the same instrument creates a symmetric mean-reversion system that fades moves in both directions.

**Backtesting limitations:** Because the live path uses `InsideAsk` (unavailable in history) and ECN pegging (ignored in simulation), backtesting uses `Close` as a proxy. The historical fills provide a rough approximation of live performance but should not be treated as an accurate representation of live execution quality. Live forward testing is recommended before relying on backtesting results for this strategy.
