# Trendline Entry Strategy — v1.0 & v2.0

🇺🇸 English | 🇪🇸 [Español](README.es.md)

## Strategy Description

Trendline Entry Strategy bridges discretionary and systematic trading by executing mechanical entries against a trendline drawn manually on the chart. The strategy reads the trendline's position in real time using TradeStation's trendline API, projects its value one bar forward, and places either a limit order (when price is already on the favorable side of the line, seeking a pullback to it) or a stop order (when price is on the unfavorable side, seeking a breakout through it). The direction of trading — long or short — is controlled by the sign of the `TradeSize` input rather than by a separate direction parameter.

The strategy operates only on the last visible bar of the chart (`LastBarOnChart`), making it a real-time execution tool rather than a backtesting system. It is designed for traders who draw trendlines as part of their discretionary analysis and want systematic, rule-based entry execution at those levels.

---

## Core Mechanics

### 1. TradeStation Trendline API

The strategy interacts with manually drawn chart objects using three EasyLanguage trendline functions:

```pascal
TL_Exist(TLID)                          // Returns True if the trendline exists
TL_GetValue(TLID, Date, Time)           // Returns the trendline's price at a given bar
```

`TLID` is the internal identifier that TradeStation assigns to each drawing object on the chart. To use this strategy, the trader must:

1. Draw a trendline on the chart manually.
2. Right-click the trendline and note its object ID (visible in the trendline properties or via the Drawing Tools panel).
3. Enter that ID as the `TLID` input.

This is not a computed value — it is a reference to a specific drawn object. If the trendline is deleted and redrawn, TradeStation assigns a new ID and `TLID` must be updated. `TL_Exist(TLID)` provides a safety check: the strategy only activates if the referenced trendline actually exists on the chart.

### 2. Trendline Reading and Slope Calculation

```pascal
TLCurrent  = TL_GetValue(TLID, Date,    Time);      // Value at current bar
TLPrevious = TL_GetValue(TLID, Date[1], Time[1]);   // Value at previous bar
```

`TL_GetValue` returns the price level of the trendline at any given date and time. Reading it at the current bar and the previous bar gives two points on the line — enough to determine its slope direction (ascending or descending) and to project its value forward.

The slope is not stored as an explicit variable but is embedded in the projection formula.

### 3. Linear Projection — Where the Line Will Be Next Bar

```pascal
TLProjected = TLCurrent + (TLCurrent - TLPrevious);
```

This extrapolates the trendline one bar into the future assuming constant slope. The reasoning:

- `TLCurrent - TLPrevious` = the price change of the line per bar (its slope).
- Adding this slope to `TLCurrent` estimates the line's value at the next bar.

For a straight trendline this is exact by definition — a straight line has constant slope, so the projection is always correct. The projected value is where the limit or stop orders are placed, ensuring entries target the line's future position rather than its current position. This matters in trending situations where a single-bar difference can be significant.

### 4. `TradeSize` as Direction Selector

```pascal
If TradeSize > 0 Then
    Buy (...)  ...     // Long mode
If TradeSize < 0 Then
    SellShort (...) ... // Short mode
```

The sign of `TradeSize` controls direction:
- Positive `TradeSize` → long trades only.
- Negative `TradeSize` → short trades only.

For short entries, the order quantity uses `-TradeSize` to convert the negative input into a positive share count:

```pascal
SellShort ("TL_SE_Limit") Next Bar -TradeSize Shares at TLProjected Limit;
```

This is a compact design: one parameter encodes both the position size and the directional intent. The trade-off is that the parameter's sign has semantic meaning that must be understood before use.

### 5. Dual Entry Type — Limit or Stop Based on Price Position

The strategy uses two different order types depending on where price is relative to the projected trendline:

**For long trades:**
```pascal
If CrossUp Then
    Buy (...) Next Bar TradeSize Shares at TLProjected Limit   // Price above line → limit order
Else
    Buy (...) Next Bar TradeSize Shares at TLProjected Stop;   // Price below line → stop order
```

- `CrossUp = Close > TLProjected` (v2): price is currently above the trendline.
  - A **limit order** is placed at `TLProjected` — the strategy waits for price to pull back to the line. This is the typical trendline support entry: buy when price returns to the ascending trendline from above.
- Price is below the trendline:
  - A **stop order** is placed at `TLProjected` — the strategy waits for price to break up through the line. This captures a bullish breakout above a descending resistance line.

**For short trades:** the logic is mirrored — limit orders when price is below the line (waiting for a bounce to the line), stop orders when price is above the line (waiting for a bearish breakdown).

This dual-type design handles both common trendline trading scenarios — pullback-to-support entries and breakout entries — within a single unified strategy.

---

## `CrossUp`/`CrossDown` — State, Not Event

A critical design note from the v2 comments applies to both versions:

```pascal
CrossUp   = Close > TLProjected;   // Price IS above the line (state)
CrossDown = Close < TLProjected;   // Price IS below the line (state)
```

These are **positional state conditions**, not crossing events. `CrossUp` is `True` on every bar where price is above the projected trendline — it does not detect the specific bar where price crossed from below to above. This means:

- If price has been above the trendline for 10 bars, `CrossUp` has been `True` for all 10 bars.
- The limit order is re-evaluated and placed on every one of those bars.

This is the correct behavior for a trendline strategy: the limit order should be active as long as price is above the line and waiting to pull back to it. The `IsFlat` guard in v2 prevents re-entry after a position is already open.

Using a discrete `Crosses Over` event instead would place the limit order only on the exact bar of crossing — potentially missing the entry if the pullback occurs several bars later.

---

## v1 vs v2: The Difference

### v1 — No Position Guard

v1 has no `IsFlat` check before placing orders. On every `LastBarOnChart` evaluation where the trendline is valid, it places entry orders regardless of whether a position is already open:

```pascal
// v1 — orders placed unconditionally (no IsFlat check)
If TradeSize > 0 Then
Begin
    If Close > TLV Then
        Buy ("TLBuy LE") Next Bar TradeSize Shares at TLV Limit
    Else
        Buy ("TL Buy LE") Next Bar TradeSize Shares at TLV Stop;
End;
```

EasyLanguage prevents a duplicate long position from opening if already long, but the order is still submitted on every bar — generating unnecessary order activity. In live trading with `LastBarOnChart`, this means a new order is placed on every intrabar tick, which can cause order management issues with some brokers.

v1 also uses `TLV` (the current bar's value extrapolated by one step) rather than having a separately named projected variable, and mixes the projection calculation with the order logic in the same block.

### v2 — Full State Machine and Separated Blocks

v2 introduces `IsFlat`, `IsLong`, `IsShort` and guards the entry block with `If IsFlat and ValidTL`. Orders are only placed when the strategy is flat, eliminating the continuous order submission of v1.

v2 also separates concerns into clearly labeled blocks: validation, line reading and projection, structural signal computation (`CrossUp`/`CrossDown`), and entry execution. `ValidTL` consolidates all four guard conditions (`TradeSize <> 0`, `TLID >= 0`, `TL_Exist(TLID)`, `LastBarOnChart`) into a single named boolean.

**Summary:**

| | v1.0 | v2.0 |
|---|---|---|
| **Trendline reading and projection** | ✓ | ✓ |
| **Limit / Stop dual entry** | ✓ | ✓ |
| **`IsFlat` position guard** | — | ✓ |
| **`ValidTL` consolidated guard** | — | ✓ |
| **Named `TLProjected` variable** | — | ✓ |
| **`CrossUp` / `CrossDown` named signals** | — | ✓ |
| **Separated labeled blocks** | — | ✓ |

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `TradeSize` | 500 | Position size in shares. Positive = long trades; negative = short trades. Zero disables the strategy. |
| `TLID` | 0 | Internal TradeStation ID of the manually drawn trendline. Must match the object ID assigned by the platform. |

**On `TLID`:** The default value of `0` is not a valid trendline ID in most configurations — it serves as a placeholder. Before using the strategy, the correct ID must be obtained from the chart and entered as the input. An incorrect `TLID` causes `TL_Exist(TLID)` to return `False`, and the strategy will not place any orders.

**On `TradeSize` sign:** Switching from long to short mode requires changing the sign of `TradeSize` (e.g. from `500` to `-500`). The absolute value determines the number of shares in both cases.

---

## Trade Scenarios

### Scenario A — Long Entry: Price Above Ascending Trendline (Limit Order)

- Ascending trendline with `TLCurrent = 4,985`, `TLPrevious = 4,980`.
- `TLProjected = 4,985 + (4,985 − 4,980) = 4,990`.
- Current close: 4,998. `CrossUp = True` (price above projected line).
- `TradeSize = 500` (long mode).
- **Limit order placed at 4,990.** Strategy waits for price to pull back to the trendline.
- Next bar: price dips to 4,989, touching 4,990 on the way. Long fills at 4,990.

### Scenario B — Long Entry: Price Below Ascending Trendline (Stop Order)

- Same trendline. `TLProjected = 4,990`.
- Current close: 4,978. `CrossUp = False` (price below projected line).
- **Stop order placed at 4,990.** Strategy waits for price to break upward through the line.
- Next bar: price rallies through 4,990. Long fills at 4,990.

### Scenario C — Short Entry: Price Below Descending Trendline (Limit Order)

- Descending trendline. `TLCurrent = 5,010`, `TLPrevious = 5,015`.
- `TLProjected = 5,010 + (5,010 − 5,015) = 5,005`.
- Current close: 4,998. `CrossDown = True` (price below projected line).
- `TradeSize = -500` (short mode).
- **Limit order placed at 5,005.** Strategy waits for price to bounce up to the trendline.
- Next bar: price bounces to 5,006. Short fills at 5,005.

### Scenario D — Trendline Not Found, No Orders

- `TLID = 42`. `TL_Exist(42)` returns `False` — trendline was deleted or ID is incorrect.
- `ValidTL = False`. No orders placed.
- Strategy remains inactive until `TLID` is updated to a valid trendline.

---

## Key Features

- **Manual trendline integration:** The strategy reads a trendline drawn by the trader, combining discretionary line drawing with systematic execution at that level.
- **Linear projection:** Orders target the trendline's estimated position at the next bar rather than its current position, accounting for the line's slope in real time.
- **Dual order type:** Limit orders when price is on the favorable side (seeking a return to the line); stop orders when price is on the unfavorable side (seeking a breakout through the line). Both trendline entry scenarios are handled automatically.
- **`TradeSize` as direction selector:** A single parameter controls both position size and directional mode (long/short) via its sign, keeping the parameter surface minimal.
- **`LastBarOnChart` gate:** The strategy only evaluates on the current live bar, making it a real-time execution tool. Historical bars do not trigger orders.
- **`IsFlat` guard (v2):** Orders are only placed when the strategy has no open position, preventing continuous order submission while in a trade.
- **`ValidTL` consolidated check (v2):** All four preconditions — valid size, valid ID, trendline exists, live bar — are combined into a single named boolean for clarity.

---

## Trade Psychology

Trendline Entry Strategy addresses one of the most common challenges in discretionary trading: **drawing the right level is one skill; executing at it without hesitation is another.** Many traders identify trendlines correctly but then second-guess themselves at the moment of execution — entering too early, waiting too long, or adjusting the line after the fact. By encoding the execution rules mechanically, the strategy separates the analytical decision (where to draw the line) from the execution decision (how to enter at it).

The dual order type reflects a nuanced understanding of trendline behavior. An ascending trendline serving as support expects price to pull back to it — a limit order is appropriate. A descending trendline acting as resistance that price is approaching from below may produce a breakout — a stop order captures that scenario. The strategy handles both without the trader needing to pre-decide which scenario will materialize.

The real-time-only design (`LastBarOnChart`) is also a psychological feature: the strategy does not generate hypothetical historical entries that might look better in backtesting than in live trading. It only acts when the market is actually open and the trendline position can be evaluated against current price. This keeps the strategy honest about what it can realistically deliver.

---

## Use Cases

**Instruments:** Applicable to any liquid instrument where trendline analysis is meaningful — equity index futures (ES, NQ), individual stocks in trending phases, commodity futures, and FX futures. The trendline must have enough price touches to be considered structurally significant; a line drawn through only two points is less reliable than one with multiple confirmations.

**Timeframes:** Trendlines on daily and weekly charts carry more structural weight than intraday trendlines. The strategy works on any timeframe, but the quality of the entry depends entirely on the quality of the drawn trendline.

**Workflow:** The intended workflow is:
1. Identify a significant trendline through chart analysis.
2. Draw it on the chart and note the `TLID`.
3. Configure the strategy with the correct `TLID` and desired `TradeSize`.
4. Let the strategy handle execution at the trendline level automatically.

**Limitations:** Because the strategy reads a manually drawn object, it cannot be backtested in the traditional sense — historical trendlines are not preserved between sessions. The strategy is evaluated on its real-time execution quality, not on statistical backtesting results. Any backtesting would require manually reconstructing historical trendlines for each period, which is not practical at scale.

**Relationship to other strategies:** This strategy is architecturally unique in the repository — it is the only one that reads external chart objects rather than computing all inputs from price data alone. It represents a specific design philosophy: keep the discretionary insight (the trendline) and systematize only the execution mechanics around it.
