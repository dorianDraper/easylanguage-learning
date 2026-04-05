# Trend Reentry — v1.0 & v2.0

🇺🇸 English | 🇪🇸 [Español](README.es.md)

## Strategy Description

Trend Reentry is a long-only trend-following strategy that uses a moving average crossover to identify the start of an uptrend and then manages the position through a two-exit, multi-reentry architecture. Rather than holding a single position through an entire move, the strategy takes a tactical profit when price reaches a significant new high, then re-enters if the trend resumes — potentially multiple times within the same uptrend. The final exit is always driven by trend failure, not by a price target, ensuring the strategy stays in strong trends for as long as they last.

---

## Core Mechanics

### 1. Trend Detection

Two simple moving averages define the trend state:

```pascal
FastMA = Average(Close, FastLen);   // Default: 13-period
SlowMA = Average(Close, SlowLen);   // Default: 21-period

BullCross = FastMA Crosses Over SlowMA;   // Trend begins
BearCross = FastMA Crosses Under SlowMA;  // Trend ends
```

`BullCross` and `BearCross` are discrete events — they are `True` only on the exact bar where the crossing occurs. This means the strategy enters and exits trend-based positions at the moment of confirmation, not on a continuous state condition.

### 2. Initial Entry

```pascal
If IsFlat and BullCross Then
Begin
    Buy ("InitLE") Next Bar at Market;
    MoveHigh   = High;
    CanReEnter = False;
End;
```

On a bullish MA cross, the strategy opens a long position on the next bar at market. `MoveHigh` is initialized to the current bar's high — this becomes the running peak that the strategy tracks throughout the trade. `CanReEnter` is explicitly set to `False` at entry, ensuring the re-entry logic cannot fire before a technical exit has occurred.

### 3. MoveHigh — Running Peak Tracker

While long, the strategy maintains a running maximum of the price move:

```pascal
If High > MoveHigh Then
    MoveHigh = High;
```

`MoveHigh` records the highest intrabar high reached since the position was opened (or re-entered). It serves as the reference level for the re-entry condition: after a technical exit, the strategy only re-enters if price surpasses `MoveHigh` by the re-entry buffer, confirming that the uptrend has resumed rather than simply consolidated.

### 4. Technical Exit — Extension Profit Taking

```pascal
If not CanReEnter and High > Highest(High, ExtensionLen)[1] Then
Begin
    Sell ("ExtLX") Next Bar at Market;
    CanReEnter = True;
End;
```

While long and before any re-entry has occurred (`not CanReEnter`), the strategy monitors for a new highest high over the lookback period. `Highest(High, ExtensionLen)[1]` returns the highest high of the previous `ExtensionLen` bars, shifted one bar back to avoid lookahead bias. When the current bar's high exceeds this level, price has reached a new significant extreme — the strategy takes profit and sets `CanReEnter = True`.

This exit is deliberately named `ExtLX` (extension exit) rather than a profit target, because it fires on a structural market signal (new relative high) rather than at a fixed price level. The position is not exited because the trade is failing — it is exited because price has extended significantly and a pullback is structurally expected.

### 5. Final Exit — Trend Failure

```pascal
If BearCross Then
Begin
    Sell ("TrendLX") Next Bar at Market;
    CanReEnter = False;
    MoveHigh   = 0;
End;
```

When the fast MA crosses below the slow MA, the trend is considered broken regardless of position status. The strategy sells immediately, resets `CanReEnter` to `False` (preventing any re-entry after a trend failure), and resets `MoveHigh` to zero in preparation for the next trend cycle.

The `Begin`/`End` block enclosing all three instructions is critical — see the bug note in the v1 vs v2 section below.

### 6. Re-Entry Logic

```pascal
If MarketPosition = 0 and CanReEnter
    and High > MoveHigh + ReEntryBuffer Then
    Buy ("ReEntryLE") Next Bar at Market;
```

After a technical exit (`CanReEnter = True`), the strategy watches for the trend to resume. Re-entry requires three simultaneous conditions:

- `MarketPosition = 0`: The strategy is currently flat.
- `CanReEnter = True`: The previous exit was a technical profit-taking exit, not a trend failure.
- `High > MoveHigh + ReEntryBuffer`: Price has surpassed the previous peak by the buffer amount, confirming new upward momentum rather than a sideways consolidation.

Multiple re-entries are possible within a single trend cycle — each technical exit resets the cycle without resetting `CanReEnter`, allowing the strategy to participate in successive price extensions within the same uptrend.

### 7. State Machine

```
┌─────────┐
│  FLAT   │
└────┬────┘
     │ FastMA crosses over SlowMA
     ▼
┌──────────────┐
│  LONG ACTIVE │  ← tracking MoveHigh, monitoring for extension
└────┬─────────┘
     │ New highest high over ExtensionLen bars
     ▼
┌──────────────┐
│  TECH EXIT   │  ← profit taken, CanReEnter = True
│ CanReEnter=1 │
└────┬─────────┘
     │ High > MoveHigh + ReEntryBuffer
     ▼
┌──────────────┐
│  RE-ENTER    │  ← back long, tracking new MoveHigh
└────┬─────────┘
     │ FastMA crosses under SlowMA
     ▼
┌─────────┐
│  FLAT   │  ← trend invalidated, CanReEnter = False
└─────────┘
```

The state machine can cycle through the LONG ACTIVE → TECH EXIT → RE-ENTER loop multiple times before a BearCross terminates the trend and returns the strategy to FLAT with all flags reset.

---

## v1 vs v2: The Difference

The two versions implement the same trading logic. The evolution is structural and corrects one important bug present in both v1 and v2 as originally written.

### v1 — Functional but With a Scoping Issue

v1 uses `MarketPosition <= 0` as the condition for both initial entry and re-entry, grouping them in the same block:

```pascal
If MarketPosition <= 0 Then
Begin
    If FastAvg Crosses Over SlowAvg Then
        Buy ("InitLE") Next Bar at Market;

    If MarketPosition(1) = 1 and BarsSinceExit(1) >= 1 and ReEnterOK
        and High > MoveHigh + ReEntryPoints Then
        Buy ("ReEnterLE") Next Bar at Market;
End;
```

The re-entry condition in v1 uses `MarketPosition(1) = 1` — the market position of the previous trade — and `BarsSinceExit(1) >= 1` to verify a recent exit from a long. This works, but the re-entry logic is mixed with the initial entry logic in the same block, making the two entry paths harder to read independently.

### v2 — Explicit State Machine and Clean Separation

v2 separates every logical concern into its own named block, making the two entry paths — initial entry and re-entry — clearly distinct. Named booleans (`IsFlat`, `IsLong`, `BullCross`, `BearCross`, `CanReEnter`) replace inline comparisons throughout.

### Bug: Missing `Begin`/`End` in the BearCross Block

Both v1 and v2 as originally written shared a critical scoping bug in the trend failure exit. In EasyLanguage, an `If` statement without `Begin`/`End` only governs the **first instruction** that follows it. Any subsequent lines execute unconditionally on every bar where the outer condition (`IsLong`) is true.

**Buggy code (original v2):**

```pascal
If BearCross Then
    Sell ("TrendLX") Next Bar at Market;
    CanReEnter = False;   // ← executes on EVERY bar while IsLong = True
    MoveHigh   = 0;       // ← executes on EVERY bar while IsLong = True
```

Only `Sell ("TrendLX")` is conditioned on `BearCross`. The two state resets below it execute on every bar while in a long position — resetting `CanReEnter` to `False` and `MoveHigh` to `0` continuously. This destroys the re-entry logic entirely: `CanReEnter` can never stay `True` long enough for a re-entry to fire, and `MoveHigh` resets to zero on every bar, making the re-entry threshold unreachable.

**Corrected code:**

```pascal
If BearCross Then
Begin
    Sell ("TrendLX") Next Bar at Market;
    CanReEnter = False;
    MoveHigh   = 0;
End;
```

The `Begin`/`End` block correctly scopes all three instructions to the `BearCross` event. This is the version reflected in the current codebase.

**Summary:**

| | v1.0 | v2.0 (corrected) |
|---|---|---|
| **Trading logic** | ✓ | ✓ |
| **Explicit state machine** | — | ✓ (`IsFlat`, `IsLong`, `BullCross`, `BearCross`) |
| **Entry paths separated** | — | ✓ (initial entry / re-entry in own blocks) |
| **`CanReEnter` (vs `ReEnterOK`)** | — | ✓ |
| **BearCross `Begin`/`End` fix** | ✗ bug | ✓ corrected |
| **Descriptive variable names** | `FastAvg`, `ReEnterOK` | `FastMA`, `CanReEnter` |
| **Parameter names** | `HHExitLen`, `ReEntryPoints` | `ExtensionLen`, `ReEntryBuffer` |

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `FastLen` | 13 | Period for the fast moving average. Controls signal responsiveness. |
| `SlowLen` | 21 | Period for the slow moving average. Defines the trend reference. |
| `ExtensionLen` | 50 | Lookback period for detecting a new highest high. Larger values require more significant extensions before triggering the technical exit. |
| `ReEntryBuffer` | $0.10 | Price amount above `MoveHigh` required to trigger a re-entry. Prevents re-entries on marginal new highs. |

**On parameter relationships:** `FastLen` must be smaller than `SlowLen` — if they are equal or inverted, the crossover signal loses meaning. `ExtensionLen` should be meaningfully larger than `FastLen` so the extension exit is measuring a significant new high relative to the trend context, not just noise. The `ReEntryBuffer` should be calibrated to the instrument's typical tick size — $0.10 is appropriate for stocks but may need adjustment for futures.

---

## Trade Scenarios

### Scenario A — Full Cycle: Entry, Technical Exit, Re-Entry, Final Exit

- FastMA(13) crosses above SlowMA(21). `BullCross = True`.
- **Initial entry:** Buy at $45.20. `MoveHigh = 45.15` (bar high at entry signal bar).

**Bars 1–8 (building the move):**
- Price advances to $46.80. `MoveHigh` updates to $46.80.
- `Highest(High, 50)[1] = $46.50`. Current High $46.80 > $46.50. Extension exit triggered.
- **Technical exit:** `Sell ("ExtLX")`. Position exits at $46.82 (next bar open). `CanReEnter = True`.

**Bars 9–12 (consolidation):**
- Price pulls back to $46.20. `MarketPosition = 0`, `CanReEnter = True`.
- `High (46.35) < MoveHigh (46.80) + ReEntryBuffer (0.10) = 46.90`. Re-entry not triggered.

**Bar 13 (re-entry):**
- Price pushes to $46.95. `High (46.95) > 46.90`. `CanReEnter = True`, `MarketPosition = 0`.
- **Re-entry triggered:** Buy at $46.97. `MoveHigh` continues updating from $46.80.

**Bar 20 (trend failure):**
- FastMA(13) crosses below SlowMA(21). `BearCross = True`.
- **Final exit:** `Sell ("TrendLX")`. `CanReEnter = False`. `MoveHigh = 0`. Cycle complete.

### Scenario B — Trend Failure Before Extension Exit

- BullCross entry at $45.20.
- Price moves against the position. FastMA crosses below SlowMA on bar 4.
- `BearCross = True`. `Sell ("TrendLX")`. `CanReEnter = False`. `MoveHigh = 0`.
- Extension exit never fired. No re-entry possible. Strategy waits for a new BullCross.

### Scenario C — Multiple Re-Entries Within One Trend

- BullCross entry. Technical exit after first extension. `CanReEnter = True`.
- Re-entry 1 after `MoveHigh + Buffer` exceeded.
- Second extension reached. Technical exit again. `CanReEnter = True` (still).
- Re-entry 2 after new `MoveHigh + Buffer` exceeded.
- BearCross fires. Final exit. `CanReEnter = False`. Cycle complete.

The strategy participated in two separate extensions within the same trend without ever holding more than one position simultaneously.

---

## Key Features

- **Two-exit architecture:** A technical exit captures profits on price extensions without treating them as trend failures; a trend exit closes the position only when the MA structure confirms the uptrend is over.
- **`CanReEnter` flag:** Distinguishes between exits caused by profit-taking (re-entry allowed) and exits caused by trend failure (re-entry blocked). This is the core state variable that enables the multi-reentry design.
- **`MoveHigh` peak tracker:** A running maximum that accumulates the trend's best price, used as the reference for re-entry confirmation. Only resets on trend failure, preserving context across multiple entries within the same trend.
- **No pyramiding:** The strategy holds at most one long position at any time. Re-entries replace existing positions; they do not add to them.
- **Discrete event entries and exits:** Both the initial entry and the trend failure exit are triggered by MA crossover events, not continuous state conditions. This reduces overtrading in stable, non-crossing periods.
- **`[1]` offset on `Highest`:** The lookback for the extension exit uses the previous bar's highest high, eliminating lookahead bias on the current bar.
- **`Begin`/`End` scoping discipline:** The BearCross block requires explicit delimiters to correctly scope all three state resets. Missing them is a silent bug that disables the re-entry mechanism entirely.

---

## Trade Psychology

Trend Reentry embodies a nuanced view of how trends actually move: **not in a straight line, but in a series of impulses and consolidations.** A strategy that holds through every pullback risks giving back significant gains when an extension reverses sharply. A strategy that exits on every pullback misses the larger move. Trend Reentry navigates this by defining a specific structural event — a new significant high — as the trigger to take profits, while keeping the door open to re-enter if the trend proves it still has momentum.

The `CanReEnter` flag encodes a crucial distinction that discretionary traders make intuitively: *"I exited because the position got extended, not because the trade was wrong."* When a position is exited due to profit-taking at an extreme, the original trade thesis (the uptrend is intact) has not been invalidated. Re-entry is rational. When a position is exited due to a bearish MA cross, the thesis has been invalidated. Re-entry is not rational until a new signal appears.

The `MoveHigh + ReEntryBuffer` condition for re-entry is also psychologically meaningful: it requires the market to *prove* the trend is resuming by making a new high, rather than re-entering on hope during a consolidation. The buffer prevents false re-entries on marginal new highs that could simply be noise.

This architecture reflects the way strong trends often behave: a sharp impulse, a shallow consolidation, another impulse. Trend Reentry is designed to participate in each impulse while stepping aside during the consolidations — extracting value from the trend's structure rather than simply holding through all of it.

---

## Use Cases

**Instruments:** Primarily suited to trending instruments with clear impulse-consolidation structure — individual stocks in momentum phases, equity index futures (ES, NQ) during directional sessions, or commodity futures during sustained moves. The strategy is long-only, so it requires instruments where uptrends are a meaningful part of the price action.

**Timeframes:** The 13/21 MA combination works on multiple timeframes. On 15-min charts it captures intraday trend cycles; on daily charts it captures multi-week trends. `ExtensionLen = 50` should be interpreted relative to the timeframe — 50 bars on a 5-min chart is roughly four hours of price history; on a daily chart it is ten weeks.

**Long-only design:** The strategy has no short side. For a symmetric system, a parallel short-only version (entering on BearCross, exiting on BullCross, with extension exits on new lows) could be developed independently and run alongside this component.

**Combining with risk components:** Trend Reentry handles entry and technical exit logic but has no per-trade stop loss. In production, pairing it with ATRDollar TrailStop as an additional exit layer, AccountRiskCore for account-level daily limits, and End-of-Day Exit for overnight risk management creates a complete intraday system with multiple protection layers.
