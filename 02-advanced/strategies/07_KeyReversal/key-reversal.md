# Key Reversal — v1.0 & v2.0

## Strategy Description

Key Reversal is a mean-reversion strategy that identifies and trades the classic key reversal pattern — a structural low followed by a bullish close that confirms a potential directional change. The strategy enters long on the first confirmed pattern and can add a second position if the trade moves against it while the pattern remains structurally valid. Each entry operates on its own independent time-based exit clock, preventing correlated liquidation between the base and scale-in positions.

A companion indicator — **Key Reversal Detector** — visualizes the pattern detection logic directly on the chart, plotting structural lows, bullish closes, and confirmed key reversals as separate signals for visual validation and strategy review.

---

## Core Mechanics

### 1. Structural Low Detection — MRO and the Donchian Channel

The strategy identifies structural lows using `MRO` (Most Recent Occurrence), one of EasyLanguage's most powerful scanning functions:

```pascal
LowerLowOffset =
    MRO(Low < Lowest(Low, DonchianLen)[1], CarryForwardBars + 1, 1);
```

`MRO` scans backwards through the bars and returns the offset of the most recent bar where the condition was true. Breaking down the arguments:

- **Condition:** `Low < Lowest(Low, DonchianLen)[1]` — the bar's low is below the lowest low of the previous `DonchianLen` bars. The `[1]` offset ensures the channel is calculated on completed bars, eliminating lookahead bias.
- **Lookback:** `CarryForwardBars + 1` — how many bars back to search. At its minimum (`CarryForwardBars = 0`), this searches only the current bar. Increasing `CarryForwardBars` extends the search window, allowing the strategy to find a structural low that occurred a few bars ago and still consider it valid.
- **Occurrence:** `1` — find the most recent occurrence.

`LowerLowOffset` returns the number of bars ago the structural low occurred, or `-1` if no qualifying low was found in the search window. `HasStructuralLow = LowerLowOffset >= 0` converts this to a clean boolean.

Think of `MRO` as a backwards spotlight: it sweeps back through recent bars and returns the distance to the first bar where the condition lit up.

### 2. Reversal Confirmation — Bullish Close

Once a structural low is identified, the strategy checks whether a bullish close has followed it:

```pascal
If HasStructuralLow Then
Begin
    ReferenceClose = Close[LowerLowOffset + 1];
    HasBullishClose =
        Close > ReferenceClose * (1 - ConfirmationTolerancePct * .01);
End;
```

`Close[LowerLowOffset + 1]` retrieves the close of the bar *after* the structural low bar — this is the potential reversal bar's close, which serves as the reference. The current bar's close must exceed this reference (adjusted downward by the tolerance percentage) to confirm the reversal.

**Why `LowerLowOffset + 1`?** `LowerLowOffset` points to the bar that made the new low. The bar immediately following it (`+ 1` in historical offset terms, meaning one bar after the low bar) is the first bar where a higher close could confirm the reversal. Checking the close of that specific bar anchors the pattern to its structural origin.

`ConfirmationTolerancePct` allows a small downward adjustment to the threshold, accommodating minor gaps or slippage without rejecting otherwise valid patterns. At the default of `0%`, the current close must strictly exceed the reference close.

### 3. Base Entry (LE1)

```pascal
If TradeState = 0 and HasStructuralLow and HasBullishClose Then
Begin
    Buy ("LE1") Next Bar at Market;
    TradeState = 1;
    ScaleBarsCounter = 0;
End;
```

When the strategy is flat (`TradeState = 0`) and both pattern conditions are confirmed, it enters a long position on the next bar at market. `TradeState` advances to `1` and the bars counter resets to `0`.

### 4. Scale-In Entry (LE2)

```pascal
If TradeState = 1 and HasStructuralLow and HasBullishClose
    and OpenPositionProfit < 0 Then
Begin
    Buy ("LE2") Next Bar at Market;
    TradeState = 2;
    ScaleBarsCounter = 0;
End;
```

While holding the base position (`TradeState = 1`), if the pattern is still structurally valid — the structural low still qualifies and the bullish close is still confirmed — **and** the current trade is at a loss (`OpenPositionProfit < 0`), the strategy adds a second 100-share position. `TradeState` advances to `2` and `ScaleBarsCounter` resets to `0` to start the independent exit clock for LE2.

This is not blind averaging — it is a conviction-based scale-in conditioned on the original setup remaining intact. The distinction matters: if the structural low no longer qualifies or the bullish close fails, `HasStructuralLow` or `HasBullishClose` will be `False`, and the scale-in will not trigger regardless of how unprofitable the base trade is.

### 5. Independent Exit Clocks

Each entry has its own time-based exit, preventing simultaneous liquidation:

```pascal
// LE1 exit — based on BarsSinceEntry from the base entry
If TradeState >= 1 and BarsSinceEntry >= ExitAfterBars Then
Begin
    Sell ("ExitLE1") Next Bar 100 Shares from Entry ("LE1") at Market;
    If TradeState = 1 Then
        TradeState = 0;
    // If TradeState = 2, remains at 2 until ExitLE2 resolves it
End;

// LE2 exit — based on ScaleBarsCounter from the scale entry
If TradeState = 2 and ScaleBarsCounter >= ExitAfterBars Then
Begin
    Sell ("ExitLE2") Next Bar 100 Shares from Entry ("LE2") at Market;
    TradeState = 1;
End;
```

`BarsSinceEntry` is an EasyLanguage built-in that counts bars since the most recent entry — in this case LE1. `ScaleBarsCounter` is a manually incremented variable that tracks bars elapsed since LE2 specifically, since `BarsSinceEntry` would be reset by LE2's entry and could not independently track LE1's clock.

The `from Entry ("LE1")` and `from Entry ("LE2")` syntax tells EasyLanguage to close only the shares associated with the named entry, rather than closing the entire position.

### 6. State Machine

```
┌──────────────┐
│  State 0     │  Flat — waiting for Key Reversal signal
└──────┬───────┘
       │ HasStructuralLow and HasBullishClose
       ▼
┌──────────────┐
│  State 1     │  Long Base — 100 shares (LE1 active)
│  (LE1 open) │  monitoring for scale-in opportunity
└──────┬───────┘
       │ Pattern still valid + OpenPositionProfit < 0
       ▼
┌──────────────┐
│  State 2     │  Long Scaled — 200 shares (LE1 + LE2 active)
│ (LE1 + LE2) │  independent exit clocks running
└──────┬───────┘
       │ BarsSinceEntry >= ExitAfterBars → ExitLE1
       ▼
┌──────────────┐
│  State 2→1   │  LE1 exits; LE2 still open
│  (LE2 open) │  ScaleBarsCounter continues
└──────┬───────┘
       │ ScaleBarsCounter >= ExitAfterBars → ExitLE2
       ▼
┌──────────────┐
│  State 0     │  Flat — cycle complete
└──────────────┘
```

---

## v1 vs v2: The Difference

### v1 — `ScaleCount` Initialized at `-2`

v1 manages the scale-in exit timer with a raw counter initialized to `-2`:

```pascal
ScaleCount = -2;   // at scale-in entry

If ScaleFlag Then
    ScaleCount = ScaleCount + 1;

If ScaleCount = ExitBars Then
    Sell ("Ex2") ...
```

The `-2` offset compensates for the two-bar delay between when the scale-in order is placed and when the counter would naturally align with `BarsSinceEntry`. It is functionally correct but requires knowing *why* the counter starts at a negative value — without that context, the initialization looks like an error. v2 replaces this with `ScaleBarsCounter` initialized to `0` at the moment of scale-in entry, making the intent self-evident.

### v2 — Explicit State Machine and Bug Fix

v2 introduces `TradeState` (0, 1, 2) as the central state variable, replacing the combination of `MarketPosition` checks and `ScaleFlag` boolean used in v1. Each state maps directly to a position configuration, making the execution flow readable as a sequence of transitions rather than a set of nested conditions.

v2 also corrects a scoping bug in the LE1 exit block. In v1, exiting LE1 unconditionally resets the state to flat — even when LE2 is still open. v2 makes the state reset conditional:

```pascal
// v1 — always resets to flat on LE1 exit
Sell ("Ex1") Next Bar 100 Shares from Entry ("LE1") at Market;
// (implicit: MarketPosition check carries state)

// v2 — corrected: only resets to flat if LE2 was never entered
If TradeState = 1 Then
    TradeState = 0;
// If TradeState = 2, remains at 2 until ExitLE2 resolves it
```

Without this fix, when `TradeState = 2` and LE1 exits, `TradeState` would drop to `0`, causing the LE2 exit block (`If TradeState = 2`) to never evaluate — leaving 100 shares of LE2 open with no exit mechanism.

**Summary:**

| | v1.0 | v2.0 (corrected) |
|---|---|---|
| **Pattern detection logic** | ✓ | ✓ |
| **Scale-in on valid pattern + loss** | ✓ | ✓ |
| **Explicit state machine** | — | ✓ (`TradeState` 0/1/2) |
| **`ScaleBarsCounter` from 0** | — | ✓ (vs `-2` in v1) |
| **LE1 exit state fix** | ✗ bug | ✓ corrected |
| **Descriptive variable names** | `FudgeFactor`, `ScaleFlag` | `ConfirmationTolerancePct`, `HasBullishClose` |
| **Parameter names** | `LLChannelLookupBars`, `ExitBars` | `DonchianLen`, `ExitAfterBars` |

---

## Key Reversal Detector — Indicator

The Key Reversal Detector is a ShowMe indicator that runs the same pattern detection logic as the strategy and plots three independent signals on the chart:

```pascal
If HasStructuralLow Then
    Plot1(Low - Range * .33, "StrucLow");       // Structural low detected

If HasBullishClose Then
    Plot2(Low - Range * .66, "BullClose");      // Bullish close confirmed

If HasStructuralLow and HasBullishClose Then
    Plot3(Low - Range * .99, "KeyReversal");    // Full pattern confirmed
```

Each plot is placed below the bar's low at a fixed fraction of the bar's range, creating a stacked visual hierarchy: structural low at one third below, bullish close at two thirds, full pattern at the bottom. This separation allows each condition to be tracked independently — a bar can show a structural low without a bullish close, making it easy to see where the pattern is forming but not yet confirmed.

**Parameters** (identical to the strategy):

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DonchianLen` | 21 | Lookback for structural low detection. |
| `CarryForwardBars` | 0 | How many bars after the low to keep considering it valid. |
| `ConfirmationTolerancePct` | 0 | Tolerance % for the bullish close threshold. |

> **Usage note:** The indicator shares the same inputs as the strategy. Keeping both configured identically ensures the visual signals match the strategy's actual entry conditions exactly.

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DonchianLen` | 21 | Lookback period for the structural low channel. Larger values require more significant lows before the pattern qualifies. |
| `CarryForwardBars` | 0 | Number of bars after the structural low to continue searching. `0` means only the current bar is checked; higher values extend the pattern validity window. |
| `ConfirmationTolerancePct` | 0% | Downward tolerance on the bullish close threshold. `0` requires strict confirmation; small positive values accept minor slippage or gaps. |
| `ExitAfterBars` | 5 | Number of bars each entry holds before automatic time-based exit. Applied independently to LE1 (via `BarsSinceEntry`) and LE2 (via `ScaleBarsCounter`). |

**On `CarryForwardBars`:** Setting this to `0` means the strategy only recognizes a pattern on the exact bar where both the structural low condition and the bullish close align. Increasing it to `1` or `2` allows the strategy to recognize the pattern one or two bars after the structural low formed, capturing setups where the reversal close develops slightly later.

---

## Trade Scenarios

### Scenario A — V-Shaped Recovery (No Scale-In)

- `DonchianLen = 21`. A new lowest low forms. The following bar closes above the reference close. `HasStructuralLow = True`, `HasBullishClose = True`.
- **LE1 entry:** Buy 100 shares at $45.20. `TradeState = 1`.
- Trade moves immediately to profit. `OpenPositionProfit > 0` on every bar — scale-in condition never met.
- Bar 5: `BarsSinceEntry = 5 >= ExitAfterBars (5)`. **ExitLE1** fires. 100 shares sold. `TradeState = 0`. `TradeState = 1 → 0`.
- Cycle complete. No LE2 was ever entered.

### Scenario B — Scale-In During Drawdown, Staggered Exit

- **LE1 entry** at $45.20. Trade moves against position. `OpenPositionProfit < 0`.
- Pattern still valid: `HasStructuralLow = True`, `HasBullishClose = True`.
- **LE2 scale-in:** Buy 100 additional shares at $44.80. `TradeState = 2`. `ScaleBarsCounter = 0`.
- Position now 200 shares. Average entry: ~$45.00.
- Bar 5 from LE1: `BarsSinceEntry = 5`. **ExitLE1** fires. 100 shares sold at $45.40. `TradeState` remains `2` (LE2 still open).
- `ScaleBarsCounter` reaches `5`: **ExitLE2** fires. 100 shares sold at $45.60. `TradeState = 1 → 0` after ExitLE2.

The two exits are staggered — LE1 exits first, LE2 exits later, each at potentially different prices.

### Scenario C — Scale-In Blocked (Pattern Invalidated)

- **LE1 entry** at $45.20. Trade moves to loss.
- A new lower low forms that no longer qualifies within the `DonchianLen` window — `HasStructuralLow = False`.
- Scale-in condition: `TradeState = 1 and HasStructuralLow and HasBullishClose and OpenPositionProfit < 0`.
- `HasStructuralLow = False` → **scale-in blocked**.
- LE1 exits at bar 5 without any scale-in having occurred.

---

## Key Features

- **`MRO`-based structural low detection:** Scans backward through recent bars to find the most recent qualifying low, enabling pattern recognition across a configurable lookback window without bar-by-bar looping.
- **Conviction-based scale-in:** The second entry only triggers when the original setup is still structurally valid. Losses alone do not trigger averaging — the pattern must still hold.
- **Independent exit clocks:** `BarsSinceEntry` tracks LE1's timer; `ScaleBarsCounter` tracks LE2's timer independently. Each entry gets its own exit window without interfering with the other.
- **`from Entry` syntax:** EasyLanguage's named-entry exit syntax (`100 Shares from Entry ("LE1")`) ensures each exit order closes only the intended shares, preventing full-position liquidation when partial exits are intended.
- **Three-state machine (v2):** `TradeState` 0/1/2 maps directly to the position configuration at each moment, making execution flow transparent and auditable.
- **`HasBullishClose` reset per bar:** `HasBullishClose = False` at the start of each bar ensures the condition is re-evaluated fresh, preventing stale pattern signals from persisting across bars.
- **Companion indicator:** The Key Reversal Detector provides visual validation of the same detection logic, allowing manual review of pattern frequency, quality, and alignment with strategy entries.

---

## Trade Psychology

Key Reversal embodies a specific stance on drawdown management: **a losing trade in a valid setup is a cheaper entry, not a reason to exit.** Most mean-reversion approaches either hold through losses passively or cut them at a fixed stop. Key Reversal takes a third path — it actively adds to the position when the price is lower, but only when the structural justification for the trade remains intact.

This distinction is critical. The scale-in is not triggered by the loss itself. It is triggered by the combination of loss *and* continued pattern validity. If the structural low no longer qualifies — because a deeper low has broken the channel — `HasStructuralLow` becomes `False` and the scale-in is blocked. The strategy only adds when it has structural reason to believe the setup is still alive.

The time-based exit removes the open-ended holding risk that often accompanies mean-reversion strategies. Rather than waiting for a specific profit target or a stop level, each entry exits after a fixed number of bars — accepting whatever the market has returned during that window. This keeps the average holding period predictable and prevents the strategy from becoming a passive holder through multi-day moves it was not designed to capture.

The independent exit clocks reflect a respect for the asymmetry between the two entries: LE1 entered at a higher price with a cleaner signal; LE2 entered later at a lower price with additional conviction but also additional risk. Giving each its own exit window acknowledges that they are different trades sharing a common thesis, not a single averaged position.

---

## Use Cases

**Instruments:** Best suited to instruments that exhibit mean-reverting behavior at structural lows — individual stocks with identifiable support levels, equity index futures (ES, NQ) during pullback sessions, or commodity futures where key reversal patterns form at established ranges. Avoid strongly trending instruments where new lows consistently lead to further lows rather than reversals.

**Timeframes:** The 21-bar Donchian channel on daily bars identifies monthly structural lows; on 60-min bars it identifies session lows. The `ExitAfterBars = 5` default should be interpreted relative to the timeframe — five daily bars is one trading week; five 60-min bars is a half-session.

**Parameter guidance:**
- **Wider `DonchianLen`:** Fewer, more significant structural lows. Better signal quality, fewer trades.
- **Larger `CarryForwardBars`:** More flexible pattern recognition, capturing reversals that develop over multiple bars. Risk of entering on stale lows.
- **Non-zero `ConfirmationTolerancePct`:** Useful in gapping instruments where the close after a structural low may be fractionally below the reference close due to overnight gaps.
- **Longer `ExitAfterBars`:** Gives the reversal more time to develop but increases exposure duration.

**Combining with risk components:** Key Reversal has no stop loss — exits are time-based only. In production, pairing it with ATRDollar TrailStop as an additional exit layer provides downside protection if the reversal fails to materialize within the holding window. AccountRiskCore handles account-level daily limits independently of the strategy's own exit logic.
