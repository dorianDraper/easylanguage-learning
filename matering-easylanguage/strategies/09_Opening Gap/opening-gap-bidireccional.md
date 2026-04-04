# Opening Gap Bidireccional — v1.0

## Strategy Description

Opening Gap Bidireccional consolidates the logic of Opening Gap Down v2 and Opening Gap Up v1 into a single unified strategy. Rather than maintaining two separate files — one for each direction — the bidirectional version uses conditional logic to detect whichever gap type forms at the session open and enter the appropriate trade. All the core mechanics are preserved: the volatility-adaptive threshold, the gap-fill profit target, and the threshold-based stop loss. What changes is the architecture: one code base, one parameter set, one file to maintain.

The strategy takes at most one trade per session, in whichever direction the gap occurs. If both a gap up and a gap down were theoretically present (which cannot happen simultaneously), the first condition evaluated would win — in practice, this is never an issue since price cannot open both above the prior high and below the prior low.

---

## Core Mechanics

### 1. Session and Gap Detection

```pascal
IsNewSession = Date of Next Bar <> Date;

IsGapDown = IsNewSession and Open of Next Bar < Low  - GapTest;
IsGapUp   = IsNewSession and Open of Next Bar > High + GapTest;
```

Both gap conditions are evaluated simultaneously on every bar. `IsNewSession` is computed once and reused in both gap checks — a clean factoring that avoids repeating the date comparison. Note that in the bidirectional version, `Low` and `High` are used directly (the previous bar's low and high) rather than through a `GapPrice` input parameter — the reference prices are implied by the direction.

This is a subtle but meaningful simplification: the directional strategies expose `GapPrice` as a configurable input (defaulting to `Low` or `High`), allowing users to switch to gap-from-close detection by changing one parameter. The bidirectional version hardcodes `Low` and `High` as the reference prices, trading that flexibility for a simpler, single-parameter interface.

### 2. Unified Entry Block

```pascal
If MarketPosition = 0 Then
Begin
    If IsGapDown Then
    Begin
        Gap = Low - Open of Next Bar;
        Buy ("GAP_LE") Next Bar at Market;
    End;

    If IsGapUp Then
    Begin
        Gap = Open of Next Bar - High;
        SellShort ("GAP_SE") Next Bar at Market;
    End;
End;
```

The `MarketPosition = 0` guard ensures only one position is ever open. Both gap conditions are evaluated inside the same block — whichever fires first (or only one fires at all) determines the trade direction for that session. `Gap` is assigned inside each branch with the correct sign convention for that direction.

### 3. Symmetric Dual Exit

```pascal
// Long exit (Gap Down trade)
If IsLong Then
Begin
    GapExitPxPT = EntryPrice + Gap;      // Returns to prior low — gap filled
    GapExitPxSL = EntryPrice - GapTest;  // Gap widens — trade invalidated

    Sell ("GapFill_LX") Next Bar at GapExitPxPT Limit;
    Sell ("GapStop_LX") Next Bar at GapExitPxSL Stop;
    SetExitOnClose;
End;

// Short exit (Gap Up trade)
If IsShort Then
Begin
    GapExitPxPT = EntryPrice - Gap;      // Returns to prior high — gap filled
    GapExitPxSL = EntryPrice + GapTest;  // Gap widens — trade invalidated

    BuyToCover ("GapFill_SX") Next Bar at GapExitPxPT Limit;
    BuyToCover ("GapStop_SX") Next Bar at GapExitPxSL Stop;
    SetExitOnClose;
End;
```

The exit logic is structurally identical to the directional strategies. `GapExitPxPT` targets the full gap fill; `GapExitPxSL` invalidates the trade if the gap extends by `GapTest`. The named order labels (`GapFill_LX`, `GapStop_LX`, `GapFill_SX`, `GapStop_SX`) allow trade-level performance breakdown by exit type in TradeStation's reports.

---

## Bidireccional vs Directional — Architecture Comparison

| | Gap Down v2 | Gap Up v1 | Bidireccional v1 |
|---|---|---|---|
| **Directions traded** | Long only | Short only | Both |
| **`GapPrice` configurable** | ✓ (`Low` default) | ✓ (`High` default) | — (hardcoded `Low` / `High`) |
| **Parameters** | 2 (`GapTest`, `GapPrice`) | 2 (`GapTest`, `GapPrice`) | 1 (`GapTest`) |
| **Code files to maintain** | 1 | 1 | 1 (replaces both) |
| **Trades per session** | 0 or 1 (if gap down) | 0 or 1 (if gap up) | 0 or 1 (either direction) |
| **Named order labels** | `GAP LE`, `Filled LX` | `GAP SE`, `Filled SX` | `GAP_LE`, `GapFill_LX`, `GAP_SE`, `GapFill_SX` |

The key trade-off is `GapPrice` configurability. The directional strategies allow the reference price to be changed from `Low`/`High` to `Close` via a single parameter, enabling gap-from-close detection without code changes. The bidirectional version hardcodes the reference prices, so changing to gap-from-close would require modifying the code directly. For most use cases this is acceptable — the bidirectional version is designed for simplicity and maintenance reduction, not maximum flexibility.

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `GapTest` | `Median(Range, 50)[1]` | Volatility threshold for gap significance. Gaps must exceed this value to trigger entry. Adapts automatically to recent market conditions. |

The reduction to a single parameter (from two in each directional strategy) is intentional. `GapPrice` is no longer needed because the reference prices are implied by the trade direction: long trades always reference `Low`, short trades always reference `High`.

---

## Trade Scenarios

### Scenario A — Gap Down Session: Long Trade

- Previous session: Low at 3,975, High at 3,995. `GapTest = 10 pts`.
- Next session opens at 3,960.
- `IsGapDown`: `3,960 < 3,975 − 10 = 3,965` → `True`.
- `IsGapUp`: `3,960 > 3,995 + 10 = 4,005` → `False`.
- `Gap = 3,975 − 3,960 = 15 pts`. Entry: Buy at 3,960.
- `GapExitPxPT = 3,975`. `GapExitPxSL = 3,950`.
- Price rallies. Profit target fills at 3,975. Trade exits +15 pts.

### Scenario B — Gap Up Session: Short Trade

- Previous session: High at 3,995, Low at 3,975. `GapTest = 10 pts`.
- Next session opens at 4,012.
- `IsGapDown`: `4,012 < 3,975 − 10 = 3,965` → `False`.
- `IsGapUp`: `4,012 > 3,995 + 10 = 4,005` → `True`.
- `Gap = 4,012 − 3,995 = 17 pts`. Entry: SellShort at 4,012.
- `GapExitPxPT = 3,995`. `GapExitPxSL = 4,022`.
- Price fades. Profit target fills at 3,995. Trade exits +17 pts.

### Scenario C — No Qualifying Gap

- Next session opens at 3,980. Previous Low: 3,975. Previous High: 3,995. `GapTest = 10 pts`.
- `IsGapDown`: `3,980 < 3,965` → `False`.
- `IsGapUp`: `3,980 > 4,005` → `False`.
- No entry. Strategy waits for next session.

### Scenario D — Stop Loss Triggered (Gap Extends)

- Gap Down session. Entry: Buy at 3,960. `GapExitPxSL = 3,950`.
- Price continues lower through 3,950. Stop fills. Trade exits −10 pts.
- No further entries that session (`MarketPosition` was non-zero when the stop filled; `IsNewSession` will only be true again at the next session open).

---

## Key Features

- **Single code base:** One file replaces two, eliminating the maintenance overhead of keeping two strategies synchronized when parameters or logic change.
- **Dynamic directionality:** No pre-commitment to long or short — the strategy reacts to whichever gap actually forms each session.
- **`MarketPosition = 0` gate:** Ensures at most one trade per session regardless of direction. If a gap down triggers a long, a simultaneous gap up signal (impossible in practice but handled in code) would be ignored.
- **Hardcoded reference prices:** `Low` and `High` as references simplifies the parameter surface to a single input while preserving the correct gap measurement for each direction.
- **Symmetric exit architecture:** Long and short exits share the same structure, making the code easy to audit — the only differences are the sign conventions in the exit price calculations and the order types (`Sell` vs `BuyToCover`).
- **Named order labels:** `GapFill_LX`, `GapStop_LX`, `GapFill_SX`, `GapStop_SX` enable per-exit-type performance analysis in TradeStation reports.
- **`SetExitOnClose` fallback:** Positions open at session end close at the closing price in backtesting.

---

## Trade Psychology

The bidirectional version embodies a *"I'll trade whichever gap appears"* stance. The directional strategies require a pre-decision: run Gap Down, Gap Up, or both? The bidirectional version removes that decision entirely — it simply observes the open and responds to whatever the market offers.

This is not just a code convenience — it reflects a genuine philosophical position. A trader who runs only Gap Down is making an implicit bet that gap-down fill rates are better than gap-up fill rates, or that they are more comfortable with long positions. A trader who runs the bidirectional version is saying: *"I trust the gap-fill edge in both directions and I don't want directional bias in my exposure."*

The one-trade-per-session constraint enforces discipline: once the session's gap type is determined and the trade is taken, the system is done for the day. There is no second-guessing, no adding to the position, and no switching directions if the first trade stops out. The gap either fills or it doesn't, and the result is accepted.

---

## When to Use Bidireccional vs Directional Strategies

**Use Bidireccional when:**
- You want symmetric exposure to gap-fade in both directions from a single file.
- You prefer a simpler parameter surface (one input vs two).
- You are comfortable with `Low` and `High` as fixed reference prices.
- You are building a portfolio and want one gap-fade component that handles all gap types.

**Use directional strategies when:**
- You want to test gap-up and gap-down edge independently before combining.
- You want the flexibility to change `GapPrice` to `Close` for gap-from-close detection.
- You want to run only one direction (e.g. long-only account with only Gap Down).
- You need separate performance attribution for each gap direction.

Both approaches implement the same trading logic. The choice is architectural — it depends on how you want to manage, monitor, and evolve the strategy in your portfolio.
