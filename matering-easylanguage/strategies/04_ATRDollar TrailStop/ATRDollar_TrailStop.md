# ATRDollar TrailStop — v1.0 & v2.0

## Strategy Description

ATRDollar TrailStop is a dynamic exit management component that replaces fixed-point or fixed-dollar stop losses with a volatility-adaptive trailing mechanism. Rather than setting a stop at a predetermined distance from entry, the component continuously recalculates the stop distance based on Average True Range (ATR), so that the stop naturally widens during volatile periods and tightens during quiet ones. The stop is expressed in dollar terms using `BigPointValue`, making it instrument-agnostic and directly comparable across different futures contracts.

The component operates in two sequential phases: an initial fixed stop that protects the position immediately after entry, followed by a dynamic trailing stop that only activates once the trade has advanced far enough to justify it. This two-phase design prevents the trailing mechanism from closing a position prematurely before it has established a meaningful profit cushion.

---

## Core Mechanics

### 1. ATR Calculation

All distances in the component are derived from a single ATR value, recalculated on every bar:

```pascal
ATRValue = AvgTrueRange(ATRLen);
```

From this, three distances are computed in points:

```pascal
FloorDistance    = ATRValue * ATRFloor;     // Distance required to activate trailing
TrailDistance    = ATRValue * ATRTrail;     // Trailing stop distance once active
StopLossDistance = ATRValue * ATRStopLoss; // Initial stop loss distance
```

Each is then converted to dollars when passed to the exit functions:

```pascal
StopLossDistance * BigPointValue   // Points → dollars
TrailDistance    * BigPointValue   // Points → dollars
```

`BigPointValue` is an EasyLanguage reserved word that returns the dollar value of one full point for the current instrument. For ES futures, `BigPointValue = 50`, so a 1.25-point ATR translates to $62.50 of risk per unit. This conversion makes the component work correctly across any instrument without hardcoding dollar amounts.

### 2. State Machine

The component tracks position state explicitly and resets the trailing flag on every flat bar:

```pascal
IsFlat  = MarketPosition =  0;
IsLong  = MarketPosition =  1;
IsShort = MarketPosition = -1;

If IsFlat Then
    TrailingActive = False;   // Reset for next trade
```

The reset on `IsFlat` is essential: it ensures that `TrailingActive` starts as `False` at the beginning of every new trade, regardless of how the previous trade ended.

### 3. SetStopShare

```pascal
SetStopShare;
```

This EasyLanguage built-in instruction tells the platform to manage stops on a per-share or per-contract basis rather than per-position. It must be called before any `SetStopLoss` or `SetDollarTrailing` calls to ensure stop calculations are applied correctly when trading multiple contracts.

### 4. Phase 1 — Initial Stop Loss

Immediately after entry, while `TrailingActive = False`, only the initial stop loss is active:

```pascal
If not TrailingActive Then
Begin
    SetStopLoss(StopLossDistance * BigPointValue);

    // Check whether the floor has been reached
    If (IsLong  and High >= EntryPrice + FloorDistance) or
       (IsShort and Low  <= EntryPrice - FloorDistance) Then
        TrailingActive = True;
End;
```

The floor check uses `High` for longs and `Low` for shorts — the most favorable intrabar price — to determine whether the trade has advanced far enough. Using `High`/`Low` rather than `Close` means the floor can be reached on any bar where the price briefly touches the threshold, even if it does not close there.

### 5. Phase 2 — Dynamic Trailing Stop

Once `TrailingActive = True`, `SetDollarTrailing` takes over:

```pascal
If TrailingActive Then
    SetDollarTrailing(TrailDistance * BigPointValue);
```

`SetDollarTrailing` is an EasyLanguage built-in that places a trailing stop at a fixed dollar distance below the highest high (for longs) or above the lowest low (for shorts) reached since the stop was activated. As ATR changes bar by bar, `TrailDistance * BigPointValue` recalculates automatically, so the trailing stop distance adapts to current volatility.

**The two-phase sequence visualized:**

```
Entry                Floor reached           Trail active
  │                       │                      │
  ▼                       ▼                      ▼
──┼───────────────────────┼──────────────────────┼────────►
  │← StopLoss (1×ATR) ──► │← TrailStop (1×ATR) ──┤
  │                       │
  │← Floor (2×ATR) ──────►│ (activates trailing)
```

🚀 Think of it as a two-stage rocket: the initial stop is the booster that keeps the trade alive through early turbulence, and the trailing stop is the cruise engine that takes over once the trade has reached altitude.

---

## v1 vs v2: The Difference

The two versions implement identical logic. The evolution is entirely about variable naming and readability.

### v1 — Functional but Generic

Variable names in v1 are abbreviated and some carry ambiguous meanings at a glance:

```pascal
Vars:
    ATR(0),              // Could be confused with the AvgTrueRange function itself
    FloorAmount(0),      // "Amount" is ambiguous — points or dollars?
    FloorFlag(false),    // "Flag" is a common generic term
    ATRTrailAmount(0),
    ATRStopLossAmount(0);
```

### v2 — Self-Documenting Names

v2 renames every variable to make its role and unit immediately clear:

```pascal
Vars:
    ATRValue(0),           // The computed ATR value (distinguishable from the function name)
    FloorDistance(0),      // "Distance" signals points, not dollars
    TrailDistance(0),      // Consistent with FloorDistance
    StopLossDistance(0),   // Same unit convention
    TrailingActive(false); // States what it means — trailing is active or not
```

The renaming from `FloorFlag` to `TrailingActive` is particularly meaningful: `FloorFlag` describes *what triggered* the state change (the floor was reached), while `TrailingActive` describes *the current state* (trailing is now running). The latter is what the code actually needs to know at each bar.

**Summary:**

| | v1.0 | v2.0 |
|---|---|---|
| **Trading logic** | ✓ | ✓ |
| **Self-documenting variable names** | — | ✓ |
| **`TrailingActive` (vs `FloorFlag`)** | — | ✓ |
| **Inline parameter comments** | Brief | Descriptive (explain the *why*) |

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ATRLen` | 9 | Lookback period for ATR calculation. Shorter = more responsive to recent volatility; longer = smoother, slower to adapt. |
| `ATRStopLoss` | 1 | Initial stop loss distance as a multiple of ATR. Active immediately after entry, before the floor is reached. |
| `ATRFloor` | 2 | Minimum trade advance (in ATR multiples) required before the trailing stop activates. Protects against premature trailing. |
| `ATRTrail` | 1 | Trailing stop distance as a multiple of ATR once the floor is reached. Controls how closely the stop follows price. |

**On parameter relationships:** `ATRFloor` should always be greater than `ATRStopLoss`. If the floor is set below the initial stop loss, the trailing stop could activate before the trade has even moved to breakeven, which defeats the protective purpose of the floor. A common starting configuration — `ATRStopLoss = 1`, `ATRFloor = 2`, `ATRTrail = 1` — means the initial stop risks 1 ATR, the trailing activates after a 2 ATR advance, and then follows at 1 ATR distance.

---

## Trade Scenarios

### Scenario A — Long Trade, Floor Reached, Trailing Activates

- Entry: ES long at 4,990.
- `ATRValue = 4 points`. `ATRLen = 9` bars.
- `StopLossDistance = 4 × 1 = 4 pts` → $200 (ES: 4 × $50).
- `FloorDistance = 4 × 2 = 8 pts` → price must reach 4,998 to activate trailing.
- `TrailDistance = 4 × 1 = 4 pts` → $200 trailing distance.

**Bar 1–5 (floor not reached):**
- Phase 1 active. `SetStopLoss($200)`. Stop at 4,986.
- Price advances to 4,994. `High (4,994) < EntryPrice + FloorDistance (4,998)`. Floor not reached. Stop remains at 4,986.

**Bar 6 (floor reached):**
- Price advances to 4,999. `High (4,999) >= 4,998`. `TrailingActive = True`.
- Phase 2 activates. `SetDollarTrailing($200)`. Trailing stop now at 4,995 (4,999 − 4 pts).

**Bar 7 (trailing follows):**
- Price advances to 5,005. Trailing stop moves to 5,001 (5,005 − 4 pts).
- ATR recalculates to 3.5 pts. `TrailDistance = $175`. Trailing stop now at 5,001.5.

**Bar 8 (stop triggered):**
- Price pulls back to 5,000. Trailing stop at 5,001.5 → stop triggered. Trade exits.

### Scenario B — Long Trade, Stop Hit Before Floor

- Entry: ES long at 4,990. `ATRValue = 4 pts`. Stop at 4,986 ($200).
- Price moves to 4,992, then reverses to 4,985.
- `Low (4,985) < Stop (4,986)`. Initial stop triggered. Trade exits with −$200 loss.
- `TrailingActive` never became `True`. Floor was never reached.

### Scenario C — Short Trade, Floor Reached

- Entry: ES short at 4,990. `ATRValue = 4 pts`.
- `StopLossDistance = 4 pts` → stop at 4,994 (above entry for shorts).
- `FloorDistance = 8 pts` → trailing activates when price reaches 4,982 or below.

**Floor reached:**
- Price drops to 4,981. `Low (4,981) <= EntryPrice − FloorDistance (4,982)`. `TrailingActive = True`.
- Trailing stop placed $200 above the lowest low reached: 4,981 + 4 = 4,985.
- As price continues lower, trailing stop follows 4 points above each new low.

---

## Key Features

- **Volatility-adaptive stops:** ATR-based distances automatically widen in volatile conditions and tighten in quiet ones, keeping the stop relevant to current market behavior without manual adjustment.
- **Two-phase protection:** The initial stop provides immediate downside protection; the floor prevents premature trailing activation; the dynamic trailing then locks in profits as the trade advances.
- **Instrument-agnostic dollar risk:** `BigPointValue` conversion means the same ATR multipliers produce consistent dollar risk across ES, NQ, CL, or any futures instrument — no parameter changes needed when switching instruments.
- **`SetStopShare` compliance:** Per-contract stop management ensures correct behavior when trading multiple contracts.
- **Floor as earned activation:** The trailing stop is not granted at entry — the trade must "earn" it by advancing `ATRFloor × ATR` points. This design acknowledges that most stop-outs happen in the first few bars after entry, before a trend has established itself.
- **Stateless reset:** `TrailingActive = False` on every flat bar ensures clean initialization for each new trade, with no carry-over state from previous positions.

---

## Trade Psychology

The ATRDollar TrailStop encodes a specific belief about how trends develop: **a trade that hasn't moved yet hasn't proven itself.** Many trailing stop implementations activate immediately after entry, which exposes the position to being stopped out by the normal noise that follows any entry before a directional move materializes. The floor requirement changes this — it says: *"show me 2 ATRs of movement in my direction, and then I'll start protecting your gains."*

This reflects a broader principle in systematic trading: **different rules for different phases of a trade.** The entry phase (initial stop) is about survival — limiting the damage if the trade is simply wrong. The floor phase is about qualification — waiting for the market to confirm the trade premise. The trailing phase is about harvesting — following the move as far as it goes while protecting accumulated profit.

The ATR-based scaling also embodies a respect for market context. A fixed $200 stop means something very different in a low-volatility session versus a high-volatility one. An ATR-based stop says: *"I will risk an amount that is proportional to how much this market is currently moving."* This is not just mathematically more consistent — it is psychologically more sustainable, because the stop feels calibrated to the market rather than arbitrary.

---

## Use Cases

**Instruments:** Designed for futures contracts where `BigPointValue` is defined — ES, NQ, YM, CL, GC, and liquid FX futures. The dollar conversion makes it directly comparable across instruments with very different point values.

**Timeframes:** The `ATRLen = 9` default adapts to the chart timeframe. On 15-min bars, it captures roughly two hours of volatility history; on daily bars, it captures the last 9 trading days. The appropriate length depends on the holding period of the strategy the component is serving.

**As a component:** ATRDollar TrailStop is designed to be attached to any entry strategy as the exit management layer. It does not generate entries — it manages the exit of existing positions. The entry strategy determines when and at what price to enter; this component determines when to exit.

**Parameter tuning guidance:**
- **Tighter trailing** (smaller `ATRTrail`): Locks in profits faster but increases the risk of being stopped out by normal retracements during a strong trend.
- **Wider floor** (larger `ATRFloor`): Allows more room before trailing activates, reducing early stop-outs but delaying profit protection.
- **Shorter ATR period** (`ATRLen`): More reactive to recent volatility spikes; useful in fast-moving markets.
- **Longer ATR period** (`ATRLen`): Smoother, slower-adapting stops; useful in trending markets where volatility expands gradually.
