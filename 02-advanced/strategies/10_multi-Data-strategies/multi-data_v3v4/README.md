# Multi-Data Strategy — v3.0 & v4.0

🇺🇸 English | 🇪🇸 [Español](README.es.md)

## Strategy Description

v3 and v4 represent a conceptual evolution of the Multi-Data Strategy, replacing the continuous state entry condition of v1/v2 (`Close > MA`) with a discrete crossover event (`Close Crosses Over MA`). This shift changes the nature of the entry signal from *"conditions are currently aligned"* to *"alignment has just been established"*, reducing signal frequency and improving signal precision. v4 builds on v3 by adding a re-entry mechanism that recovers missed continuation moves after a technical exit, without waiting for a new crossover event.

---

## Core Mechanics

### 1. Context Confirmation (Data2 — Higher Timeframe)

Identical in concept to v1/v2, but with cleaner variable naming and explicit boolean flags that make the logic more readable and auditable:

```pascal
MAData2 = Average(Close of Data2, MALenData2);

ContextBullish = MAData2 > MAData2[1];   // Higher TF momentum is up
ContextBearish = MAData2 < MAData2[1];   // Higher TF momentum is down
```

The separation into named booleans (`ContextBullish`, `ContextBearish`) is a deliberate readability choice: the entry block reads as a sentence — *"if context is bullish and a long signal fires, buy"* — rather than requiring the reader to parse inline comparisons.

> **Syntax note:** From v3 onwards, Data2 calculations use `Average(Close of Data2, MALenData2)` instead of the `Average(Close, MALenData2) Data2` syntax used in v1/v2. Both are functionally equivalent; the new form is more explicit and consistent with how Data2 is referenced elsewhere in the code.

### 2. Entry Signal — The Key Change: Crossover Events (Data1)

This is the defining architectural change of v3. Instead of checking whether price *is* above or below the MA on every bar, the strategy now checks whether price *has just crossed* the MA:

```pascal
MAData1 = Average(Close, MALenData1);

LongSignal  = Close Crosses Over MAData1;   // Price has just crossed above
ShortSignal = Close Crosses Under MAData1;  // Price has just crossed below
```

`Crosses Over` is a discrete event: it evaluates to `True` on exactly one bar — the bar where the crossing occurs — and `False` on every subsequent bar, regardless of where price is relative to the MA.

**Why does this matter?** Think of it as the difference between a motion sensor and a light switch. In v1/v2, the condition is like a light switch: it stays ON as long as price is above the MA, firing an entry signal every bar. In v3/v4, it is like a motion sensor: it fires only at the moment of movement — the crossing — and then resets. This produces fewer, more precise signals, but also means the strategy may miss the initial move if no crossover has recently occurred.

### 3. Primary Entry Logic

The entry block combines context confirmation with the discrete crossover signal:

```pascal
If MarketPosition = 0 Then
Begin
    If ContextBullish and LongSignal Then
        Buy ("MTF_LE") Next Bar at Market;

    If ContextBearish and ShortSignal Then
        SellShort ("MTF_SE") Next Bar at Market;
End;
```

The strategy is flat (`MarketPosition = 0`), the higher timeframe context is aligned, and a crossover event has just fired — all three conditions must be true simultaneously.

### 4. State Machine

v3 and v4 introduce an explicit state machine using boolean variables:

```pascal
IsLong  = MarketPosition =  1;
IsShort = MarketPosition = -1;
```

While `MarketPosition` is always available in EasyLanguage, assigning it to named booleans makes the exit logic self-documenting: `If IsLong and High < MAData1` reads immediately as a complete logical statement. It also makes future extensions — such as adding position-dependent logic — cleaner to implement.

### 5. Technical Exits

Unchanged from v1/v2 in logic, but now using the state machine variables:

```pascal
// Exit long: entire bar is below the operational MA
If IsLong and High < MAData1 Then
    Sell ("MTF_LX") Next Bar at Market;

// Exit short: entire bar is above the operational MA
If IsShort and Low > MAData1 Then
    BuyToCover ("MTF_SX") Next Bar at Market;
```

### 6. Re-Entry Logic (v4 Only)

This is the defining addition of v4. After a technical exit, there is often a scenario where the market pulled back briefly to trigger the exit, but the trend context remains intact and price quickly returns to the correct side of the MA. In v3, the strategy would sit flat and wait for a new crossover event — which may take many bars to materialize, causing it to miss the continuation move.

v4 addresses this with explicit re-entry conditions:

```pascal
CanReEnterLong =
    ContextBullish              // Higher TF context still bullish
    and Close > MAData1         // Price back above operational MA
    and BarsSinceExit(1) <= ReEntryBars  // Exit was recent
    and not LongSignal;         // Avoid duplicating the primary entry signal

CanReEnterShort =
    ContextBearish
    and Close < MAData1
    and BarsSinceExit(1) <= ReEntryBars
    and not ShortSignal;

If MarketPosition = 0 Then
Begin
    If CanReEnterLong  Then Buy      ("MTF_RELE") Next Bar at Market;
    If CanReEnterShort Then SellShort("MTF_RESE") Next Bar at Market;
End;
```

**Breaking down the re-entry conditions:**

- `ContextBullish / ContextBearish`: The macro trend must still be intact — re-entry is only valid if the original trade premise still holds.
- `Close > MAData1 / Close < MAData1`: Price must have returned to the correct side of the MA. This is a continuous state condition (like v1/v2), not a crossover event.
- `BarsSinceExit(1) <= ReEntryBars`: The exit must have been recent. `BarsSinceExit(1)` returns the number of bars since the last exit from a long position (for longs) or short (for shorts). The `ReEntryBars` window prevents the strategy from re-entering a trend that exited long ago and may have fundamentally changed.
- `not LongSignal / not ShortSignal`: If a new crossover has already fired, the primary entry block handles it. This guard prevents the re-entry block from duplicating that signal on the same bar.

> **Analogy:** Think of the re-entry logic as a "second chance window." If you missed your bus but the next one is right behind it, you can still board — but only within a reasonable time window, and only if you are still heading in the same direction.

---

## v3 vs v4: The Key Difference

| | v3.0 | v4.0 |
|---|---|---|
| **Primary entry** | Crossover event | Crossover event |
| **Re-entry after exit** | None — waits for new crossover | Yes — within `ReEntryBars` window |
| **Re-entry condition** | — | Price back on correct MA side + context intact |
| **Parameters** | 2 | 3 (`ReEntryBars` added) |

v3 is the cleaner, more conservative design. v4 trades some simplicity for better trend capture, at the cost of one additional parameter to optimize and the risk of re-entering a fading move.

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MALenData1` | 12 | MA length for the operational timeframe (Data1). Controls signal sensitivity. |
| `MALenData2` | 24 | MA length for the higher timeframe (Data2). Controls trend context sensitivity. |
| `ReEntryBars` | 5 | *(v4 only)* Maximum number of bars after an exit within which a re-entry is allowed. |

**On `ReEntryBars`:** A value of 5 means the strategy will consider re-entering for up to 5 bars after the last exit. Too small a window misses valid continuations; too large a window risks re-entering a move that has already reversed. This parameter should be optimized per instrument and timeframe combination.

---

## Trade Scenarios

### Scenario A — Long Entry via Crossover (v3 and v4)

- ES 60-min chart: MA rising from 4,980 to 4,985 → **ContextBullish = True**
- ES 15-min chart: Previous bar Close at 4,989 below MAData1 at 4,991; current bar Close at 4,994 above MAData1 at 4,992 → **LongSignal = True** (crossover just occurred)
- Both conditions met → **Buy next bar at market**
- Entry fills at 4,995

**Exit condition:** A 15-min bar prints with High < 4,992 → Sell next bar at market. Exit fills at 4,991.

### Scenario B — Signal Not Generated (No Crossover)

- ES 60-min chart: MA rising → **ContextBullish = True**
- ES 15-min chart: Close at 4,994, above MAData1 at 4,992, *but price has been above the MA for the last 8 bars*
- `LongSignal = False` (no crossing occurred this bar)
- **No entry signal generated**

This is the key behavioral difference from v1/v2: in v1/v2 this bar *would* have generated an entry signal. In v3/v4 it does not — the signal has already been "consumed" at the moment of crossing.

### Scenario C — Re-Entry After Exit (v4 Only)

Following Scenario A, the strategy exited at 4,991. Two bars later:

- ES 60-min chart: MA still rising → **ContextBullish = True**
- ES 15-min chart: Close at 4,993, above MAData1 at 4,991 → **Close > MAData1 = True**
- `BarsSinceExit(1) = 2`, which is ≤ `ReEntryBars (5)` → **Within re-entry window**
- No new crossover has occurred → **not LongSignal = True**
- All re-entry conditions met → **Buy ("MTF_RELE") next bar at market**

In v3, this bar produces no signal. The strategy sits flat until the next crossover event.

### Scenario D — Re-Entry Blocked (Window Expired)

Same conditions as Scenario C, but `BarsSinceExit(1) = 7`, which exceeds `ReEntryBars (5)`:
- **CanReEnterLong = False**
- No re-entry generated. Strategy waits for a fresh crossover signal.

---

## Key Features

- **Discrete crossover signals:** Entries fire only at the moment of crossing, not continuously while conditions hold. This reduces overtrading in sustained trends but requires the strategy to be positioned at the right time.
- **Explicit state machine:** Named boolean variables (`IsLong`, `IsShort`, `ContextBullish`, `ContextBearish`, `LongSignal`, `ShortSignal`) make the logic self-documenting and easier to audit.
- **Re-entry mechanism (v4):** Recovers continuation moves after technical exits without requiring a new crossover, bounded by a configurable time window.
- **Named order labels:** All orders use descriptive labels (`MTF_LE`, `MTF_SE`, `MTF_LX`, `MTF_SX`, `MTF_RELE`, `MTF_RESE`) enabling trade-level performance analysis by entry type in TradeStation's reports.
- **Separation of concerns:** Context confirmation, signal generation, primary entry, re-entry, and exits are each handled in clearly separated code blocks, making the strategy easier to modify and extend.

---

## Trade Psychology

The shift from continuous state to crossover event reflects a deeper philosophical change: **waiting for the moment of commitment, not just the state of alignment.**

In v1/v2, the market being above the MA is sufficient — the strategy acts on the *existence* of a favorable condition. In v3/v4, the strategy waits for the *transition* — the moment price crosses the MA. This mirrors how experienced discretionary traders think about entries: not *"price is above the level, so I should be long"*, but *"price just broke above the level — that's the signal."* The event carries more information than the state.

The re-entry logic in v4 addresses a real psychological challenge in systematic trading: the frustration of being stopped out of a valid trend and then watching the market continue without you. By defining explicit, bounded conditions under which the strategy can re-board a trend, v4 removes the ambiguity of *"should I get back in?"* and replaces it with a rule: *"re-enter if the trend is intact, price has recovered, and the exit was recent."*

The `ReEntryBars` parameter also embodies an important risk management principle: **staleness kills edge.** A re-entry signal that fires 20 bars after an exit is not the same trade as one that fires 2 bars later. The window forces the strategy to acknowledge that time degrades the validity of the original trade premise.

---

## Use Cases

**Instruments:** Same as v1/v2 — equity index futures (ES, NQ, YM) in trending sessions, with potential extension to CL, GC, and liquid FX futures. The crossover-based entry makes v3/v4 particularly suited to instruments with clean, directional moves where price tends to break and continue rather than oscillate around the MA.

**Timeframe combinations:** 15-min (Data1) / 60-min (Data2) remains the natural starting point. Given the crossover requirement, wider timeframe separations between Data1 and Data2 tend to produce cleaner signals with less noise.

**v3 vs v4 — when to prefer each:**
- Use **v3** when you want a simpler, fully event-driven system with no re-entry complexity. Easier to optimize and less prone to overfitting.
- Use **v4** when backtesting shows the strategy frequently exits and then misses a significant continuation move. The re-entry logic adds one parameter but can meaningfully improve trend capture in strongly trending instruments.

**Trader profile:** v3/v4 are better suited to systematic traders comfortable with the concept of signal sparsity — fewer entries, but each with a clearer premise. The crossover requirement means the strategy may sit flat for extended periods in range-bound markets, which requires discipline to hold through without overriding the system.
