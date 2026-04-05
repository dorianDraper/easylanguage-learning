# Opening Gap — Directional Strategies

🇺🇸 English | 🇪🇸 [Español](README.es.md)

## Strategy Description

The Opening Gap directional strategies exploit a well-documented market tendency: gaps between the previous session's closing range and the current session's open tend to fill intraday. The system is split into two independent strategies — **Opening Gap Down** (long trades) and **Opening Gap Up** (short trades) — each fading the gap in one direction. Both share the same core mechanics: a volatility-adaptive threshold to filter significant gaps, a gap-size-based profit target targeting full gap fill, and a threshold-based stop loss that invalidates the trade if the gap widens further.

Gap Down exists in two versions (v1 and v2). Gap Up v1 was built with the same architecture as Gap Down v2, so the two directional strategies are structurally symmetric. Both can be run independently or together as a pair.

---

## Core Mechanics

### 1. `Open of Next Bar` — Lookahead by Design

```pascal
IsNewSession = Date of Next Bar <> Date;
IsGapDown    = Open of Next Bar < GapPrice - GapTest;
```

`Open of Next Bar` accesses the opening price of the following bar before it has closed. In backtesting this is technically lookahead — the system reads tomorrow's open before that bar begins. However, this is an intentional and correct EasyLanguage pattern for opening-bar strategies: the entry order is `Next Bar at Market`, which executes at exactly that same open price. The system reads the open to decide whether to enter, then enters at that open. There is no information advantage — the fill price and the detection price are the same bar's open.

`Date of Next Bar <> Date` identifies the last bar of the current session — the bar whose "next bar" is the first bar of the following session. This is where gap detection fires.

### 2. Gap Detection and Threshold

```pascal
GapTest = Median(Range, 50)[1]
```

`GapTest` is the default input value — the median bar range over the last 50 bars, shifted one bar back to avoid lookahead. Using the median rather than the average makes the threshold robust to outlier sessions (e.g. earnings days, macro events) that could inflate an average. The `[1]` offset ensures the threshold is calculated on completed bars only.

A gap is considered significant only when its size exceeds this threshold:

```pascal
// Gap Down: open is below previous low by more than GapTest
IsGapDown = Open of Next Bar < GapPrice - GapTest;

// Gap Up: open is above previous high by more than GapTest
IsGapUp = Open of Next Bar > GapPrice + GapTest;
```

`GapPrice` defaults to `Low` for Gap Down and `High` for Gap Up — the previous session's boundary on the relevant side. This makes the threshold relative: only gaps that break the prior session's range by more than the median range qualify.

### 3. Gap Size Calculation

```pascal
// Gap Down (v2):
Gap = GapPrice - Open of Next Bar;   // How far below the previous low the open is

// Gap Up (v1):
Gap = Open of Next Bar - GapPrice;   // How far above the previous high the open is
```

`Gap` captures the magnitude of the overnight move beyond the prior session's boundary. It is used directly to set the profit target at the exact level where the gap would be fully filled.

### 4. Entry

```pascal
// Gap Down — long entry
If IsNewSession and IsGapDown Then
Begin
    Gap = GapPrice - Open of Next Bar;
    Buy ("GAP LE") Next Bar at Market;
End;

// Gap Up — short entry
If IsNewSession and IsGapUp Then
Begin
    Gap = Open of Next Bar - GapPrice;
    SellShort ("GAP SE") Next Bar at Market;
End;
```

Entry is at market on the opening bar of the new session. No limit or stop entry — the strategy accepts the open price as the entry, trusting that a gap of sufficient magnitude is the signal itself.

### 5. Dual Exit Framework

Both strategies use simultaneous limit and stop exits placed on every bar while in a position:

```pascal
// Gap Down exits (long position)
GapExitPxPT = EntryPrice + Gap;      // Gap fully filled → profit target
GapExitPxSL = EntryPrice - GapTest;  // Gap widens further → stop loss

Sell ("Filled LX") Next Bar at GapExitPxPT Limit;
Sell ("Stop LX")   Next Bar at GapExitPxSL Stop;

// Gap Up exits (short position)
GapExitPxPT = EntryPrice - Gap;      // Gap fully filled → profit target
GapExitPxSL = EntryPrice + GapTest;  // Gap widens further → stop loss

BuyToCover ("Filled SX") Next Bar at GapExitPxPT Limit;
BuyToCover ("Stop SX")   Next Bar at GapExitPxSL Stop;
```

The profit target is set exactly at the gap-fill level — the previous session's boundary price (`EntryPrice + Gap` returns price to `GapPrice`). The stop loss is set one `GapTest` unit against the trade: if the gap widens by as much as the detection threshold, the trade premise is considered invalid.

`SetExitOnClose` provides the backtesting fallback: if neither limit nor stop has filled by session end, the position closes at the closing price. In live trading, End-of-Day Exit handles this role.

**Profit target and stop loss are symmetric in dollar distance** when `Gap = GapTest` — i.e. when the gap is exactly at the threshold. As `Gap` grows larger than `GapTest`, the profit target moves further away while the stop loss remains at one `GapTest` unit, creating an asymmetric risk/reward that favors larger gaps.

---

## Gap Down v1 vs v2: The Difference

Gap Down v1 is the original implementation. Gap Down v2 refactors the same logic into named booleans and separated blocks without changing any trading behavior.

### v1 — Compact and Inline

```pascal
// v1 — all detection and entry inline
If Date of Next Bar <> Date and Open of Next Bar < GapPrice - GapTest Then
Begin
    Buy ("GAP LE") Next Bar at Market;
    Gap = GapPrice - Open Next Bar;   // Note: older syntax without "of"
End;

If MarketPosition = 1 Then
Begin
    GapExitPxPT = EntryPrice + Gap;
    GapExitPxSL = EntryPrice - GapTest;
    Sell ("Filled LX") Next Bar at GapExitPxPT Limit;
    Sell ("Stop LX")   Next Bar at GapExitPxSL Stop;
    SetExitOnClose;
End;
```

Two observations on v1:
- `Open Next Bar` (without `of`) is the older EasyLanguage syntax. Both forms are functionally identical; v2 uses `Open of Next Bar` consistently.
- The gap size (`Gap`) is calculated inside the entry block alongside the entry order. This works but mixes signal measurement with order execution in a single block.

### v2 — Named Conditions and Separated Blocks

```pascal
// v2 — detection separated into named booleans
IsNewSession = Date of Next Bar <> Date;
IsGapDown    = Open of Next Bar < GapPrice - GapTest;

If IsNewSession and IsGapDown Then
Begin
    Gap = GapPrice - Open of Next Bar;
    Buy ("GAP LE") Next Bar at Market;
End;

IsLong = MarketPosition = 1;

If IsLong Then
Begin
    ...exits...
End;
```

The entry condition is now a composition of two readable booleans. `IsLong` makes the exit block's condition explicit rather than embedding `MarketPosition = 1` directly. The separation mirrors the Signal/Execution architecture established across the strategy repository.

**Summary:**

| | Gap Down v1 | Gap Down v2 | Gap Up v1 |
|---|---|---|---|
| **Trading logic** | ✓ | ✓ | ✓ (mirror) |
| **Named session/gap booleans** | — | ✓ | ✓ |
| **`IsLong` / `IsShort` state** | — | ✓ | ✓ |
| **`Open of Next Bar` syntax** | `Open Next Bar` | ✓ | ✓ |
| **Separated code blocks** | — | ✓ | ✓ |

### Gap Up v1 — Structural Symmetry with Gap Down v2

Gap Up v1 was built directly mirroring Gap Down v2's architecture. Every variable, block, and naming convention is symmetric — `IsGapDown` becomes `IsGapUp`, `IsLong` becomes `IsShort`, `Buy` becomes `SellShort`, `Sell` becomes `BuyToCover`, and the exit price calculations invert direction. The only structural difference is the `GapPrice` default input: `Low` for Gap Down, `High` for Gap Up.

This means Gap Up v1 is already at the v2 level of structure — it benefits from all the readability improvements of Gap Down v2 without requiring a separate version.

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `GapTest` | `Median(Range, 50)[1]` | Volatility threshold for gap significance. Only gaps exceeding this value trigger entry. Adapts automatically to recent market volatility. |
| `GapPrice` | `Low` (Gap Down) / `High` (Gap Up) | Reference price for gap detection. The previous session's boundary on the relevant side. Can be changed to `Close` to detect gaps from the prior close rather than the prior high/low. |

**On `GapPrice` flexibility:** Using `High` / `Low` as the reference means the strategy only activates when the open breaks *beyond* the prior session's range. Using `Close` instead would detect smaller gaps that start from within the prior range — a different and more frequent signal. The choice of reference price significantly affects trade frequency and average gap size.

---

## Trade Scenarios

### Scenario A — Gap Down, Full Fill (Profit Target)

- Previous session: Low at 3,975. `GapTest = Median(Range, 50)[1] = 10 pts`.
- Next session opens at 3,960. `3,960 < 3,975 − 10 = 3,965`. Gap qualifies.
- `Gap = 3,975 − 3,960 = 15 pts`. Entry: Buy at 3,960.
- `GapExitPxPT = 3,960 + 15 = 3,975` (prior low — gap fully filled).
- `GapExitPxSL = 3,960 − 10 = 3,950` (one threshold below entry).
- By 10:30 AM price rallies to 3,975. Profit target fills. Trade exits with +15 pts.

### Scenario B — Gap Down, Gap Widens (Stop Loss)

- Same setup: entry at 3,960. Stop at 3,950. Target at 3,975.
- Price continues lower. At 3,950, stop fills. Trade exits with −10 pts.
- The gap widened by `GapTest` — the setup is considered invalidated.

### Scenario C — Gap Up, Full Fill (Profit Target)

- Previous session: High at 3,995. `GapTest = 10 pts`.
- Next session opens at 4,012. `4,012 > 3,995 + 10 = 4,005`. Gap qualifies.
- `Gap = 4,012 − 3,995 = 17 pts`. Entry: SellShort at 4,012.
- `GapExitPxPT = 4,012 − 17 = 3,995` (prior high — gap fully filled).
- `GapExitPxSL = 4,012 + 10 = 4,022` (one threshold above entry).
- Price fades back to 3,995. Profit target fills. Trade exits with +17 pts.

### Scenario D — Gap Too Small, No Entry

- Previous session: Low at 3,975. `GapTest = 10 pts`.
- Next session opens at 3,968. `3,968 > 3,975 − 10 = 3,965`. Gap does not qualify.
- `IsGapDown = False`. No entry. Strategy waits for next session.

---

## Key Features

- **Volatility-adaptive threshold:** `Median(Range, 50)[1]` ensures the gap filter adjusts to current market conditions automatically — wider during volatile periods, tighter during quiet ones.
- **Gap-fill profit target:** The profit target is set at the exact price where the gap is fully closed, aligning the exit with the mean-reversion hypothesis.
- **Asymmetric risk/reward for larger gaps:** When `Gap > GapTest`, the profit target is further away than the stop loss, rewarding larger, more significant gap events proportionally.
- **`Open of Next Bar` detection:** Gap evaluation happens on the last bar of the current session, using the next bar's open — a correct and efficient EasyLanguage pattern for opening-bar strategies.
- **`SetExitOnClose` fallback:** Positions that neither hit profit target nor stop loss by session end are closed at the close price in backtesting, preserving simulation realism.
- **Directional independence:** Gap Down and Gap Up are separate strategy files. Each can be applied independently to test directional edge, or both can be applied simultaneously to the same instrument for full coverage.

---

## Trade Psychology

Opening Gap strategies embody the *gaps tend to fill* principle — one of the most empirically observed tendencies in equities and equity index futures. The rationale is that overnight gaps often represent overreactions: news-driven panic, thin pre-market liquidity, or positioning by participants who cannot access the regular session. When the regular session opens with full participation, the initial imbalance tends to correct as the market finds equilibrium.

The adaptive threshold is the key risk control. By requiring the gap to exceed recent median volatility, the strategy filters out gaps that are merely normal overnight noise — it only acts on gaps that are structurally abnormal relative to recent behavior. A gap that is twice the median range is a different market event than a gap that is half the median range.

The dual exit — a limit at the gap-fill level and a stop one threshold away — encodes the strategy's conviction precisely: *"I believe this gap will fill, and I will stay in the trade as long as the gap has not widened further than the threshold that triggered my entry."* If the gap widens by `GapTest`, the trade premise is invalidated — the market is not fading the gap, it is extending it.

---

## Use Cases

**Instruments:** Equity index futures (ES, NQ, YM) are the natural fit — they produce consistent, measurable opening gaps driven by overnight futures movement, and their liquidity at open ensures market orders fill near the quoted price. Individual stocks with active pre-market trading are also candidates, though gap fill rates vary more by sector and news context.

**Running both directions:** Gap Down and Gap Up can be applied simultaneously to the same instrument. On any given day, at most one can trigger (both require the open to break in one direction). Running both provides symmetric exposure to the gap-fade edge regardless of which direction the gap forms.

**Selective deployment:** Gap Down alone is appropriate for traders who want mean-reversion long exposure without short-side risk. Gap Up alone provides mean-reversion short exposure. Testing each direction independently first is recommended — gap fill rates may differ between the up and down sides for a specific instrument.

**Pairing with risk components:** Neither strategy has a time-based exit beyond `SetExitOnClose`. In live trading, End-of-Day Exit ensures positions close before the session ends if neither limit nor stop has triggered. AccountRiskCore provides account-level daily loss protection independent of the per-trade stop.
