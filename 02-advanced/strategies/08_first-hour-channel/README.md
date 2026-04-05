# First Hour Channel — v1.0 & v2.0

🇺🇸 English | 🇪🇸 [Español](README.es.md)

## Strategy Description

First Hour Channel is an intraday breakout strategy that captures the high and low of the market's opening period, then enters on limit orders when price revisits those boundaries after the opening window closes. The strategy operates on the principle that the first hour of trading establishes a volatility envelope representing the market's initial consensus — and that when price breaks beyond those boundaries later in the session, it often signals a momentum move worth trading.

The strategy allows at most one trade per direction per day, uses fixed dollar stop losses and profit targets, and stops accepting new entries at a configurable cutoff time. A companion indicator visualizes the channel boundaries directly on the chart throughout the active trading window.

---

## Core Mechanics

### 1. IntraBarOrderGeneration

```pascal
[IntraBarOrderGeneration = TRUE]
```

Required at the top of both versions. This directive allows the strategy to evaluate limit orders and generate fills within a bar as it forms, rather than waiting for bar close. Without it, a limit order placed at `FirstHourLow` would only be evaluated at the next bar's open — by which point price may have already moved through the level. With it, the limit triggers the moment price touches the channel boundary intrabar.

### 2. Session Start and First Hour Window

```pascal
IsFirstHour =
    Time <= CalcTime(SessionStartTime(1,1), FirstHourMinutes);
```

`SessionStartTime(1,1)` returns the official start time of the primary session for the first data series on the chart. `CalcTime` adds `FirstHourMinutes` minutes to that start time, producing the boundary of the opening window. This calculation makes the strategy instrument-agnostic — it reads the session definition directly from the chart rather than relying on hardcoded times.

During `IsFirstHour`, the channel is built using `HighD(0)` and `LowD(0)` — the current day's running high and low respectively. These values update on every bar during the first hour, so `FirstHourHigh` and `FirstHourLow` always reflect the true high and low of the opening period at any point during that window.

### 3. Trading Window

```pascal
TradingAllowed =
    not IsFirstHour
    and Time <= StopTradingTime;
```

The strategy only accepts entries after the first hour has closed (`not IsFirstHour`) and before the stop trading cutoff (`Time <= StopTradingTime`). This creates a defined window — typically from the end of the opening period through early afternoon — during which breakout orders are active. Once `StopTradingTime` is reached, no new limit orders are placed, reducing late-session slippage risk.

### 4. Channel Construction

```pascal
If IsFirstHour Then
Begin
    FirstHourHigh = HighD(0);
    FirstHourLow  = LowD(0);
End;
```

`HighD(0)` and `LowD(0)` are EasyLanguage functions that return the current session's running high and low. Assigning them continuously during the first hour means `FirstHourHigh` and `FirstHourLow` are always up to date — on the bar when `IsFirstHour` transitions to `False`, they capture the final values of the opening period and those values are retained for the remainder of the session.

### 5. Entry Logic — Limit Orders at Channel Boundaries

```pascal
If TradingAllowed and MarketPosition = 0 Then
Begin
    If CanLongToday Then
        Buy ("FHC_LE") Next Bar at FirstHourLow Limit;

    If CanShortToday Then
        SellShort ("FHC_SE") Next Bar at FirstHourHigh Limit;
End;
```

Both limit orders are placed simultaneously during the trading window. The long limit sits at `FirstHourLow` — if price drops to the lower boundary of the opening range, a long position is triggered. The short limit sits at `FirstHourHigh` — if price rises to the upper boundary, a short position is triggered. Only one can fill at a time since `MarketPosition = 0` is required, and once either fills, the corresponding flag is disabled.

This is a counter-intuitive entry direction worth noting: the long entry is at the *low* of the first hour (buying at support), and the short entry is at the *high* (selling at resistance). The strategy is not chasing breakouts above the high or below the low — it is fading back to the boundaries and entering in the direction of the anticipated bounce or continuation from those levels.

### 6. Daily Reset and One-Trade-Per-Side Logic

```pascal
If Date <> LastTradeDate Then
Begin
    CanLongToday  = True;
    CanShortToday = True;
    LastTradeDate = Date;
End;
```

At the start of each new trading day, both direction flags reset to `True` and `LastTradeDate` updates to the current date. This guarantees a clean slate for each session regardless of what happened the previous day.

Once a position fills, the corresponding flag is disabled:

```pascal
If MarketPosition = 1  Then CanLongToday  = False;
If MarketPosition = -1 Then CanShortToday = False;
```

This prevents the strategy from re-entering the same direction after the first trade closes — whether by stop loss or profit target. Each direction gets exactly one opportunity per day.

### 7. Risk Management

```pascal
SetStopLoss(StopLossAmount);
SetProfitTarget(ProfitTargetAmount);
```

Fixed dollar stop loss and profit target are applied symmetrically to all positions. The default 1:1 ratio ($250 stop / $250 target) means the strategy needs a win rate above 50% to be profitable. These values should be calibrated to the instrument's typical daily range and point value.

---

## v1 vs v2: The Difference

### v1 — Three-State Flags and a Fragility Risk

v1 manages entry permission using `LongTrade` and `ShortTrade` variables with three states: `1` (permitted), `-1` (blocked), and `0` (initial/resetting). The channel is established and flags are reset in a single block during the first hour:

```pascal
If Time <= CalcTime(SessionStartTime(1,1), 60) Then
Begin
    HighVal    = HighD(0);
    LowVal     = LowD(0);
    LongTrade  = 1;
    ShortTrade = 1;
End Else
Begin
    If MarketPosition = 1  and LongTrade  = 1 Then LongTrade  = -1;
    If MarketPosition = -1 and ShortTrade = 1 Then ShortTrade = -1;
    ...
End;
```

The blocking logic checks `MarketPosition` and immediately sets the flag to `-1`. This approach has a fragility: with `IntraBarOrderGeneration = TRUE`, EasyLanguage evaluates strategy logic multiple times per bar as price moves. In the same bar where a limit order fills, `MarketPosition` may not yet reflect the new position at the moment the blocking check runs — depending on TradeStation's internal order of evaluation. This creates a window where the flag has not yet been disabled, and a second order in the same direction could theoretically be placed before `LongTrade` updates to `-1`.

In practice, `Intrabarpersist` on `LongTrade` and `ShortTrade` mitigates some of this risk by preserving the variable state across intrabar evaluations. However, the fundamental dependency on `MarketPosition` being current within the same bar evaluation cycle is a fragility that v2 resolves more robustly.

### v2 — Date-Based Reset and Clean Architecture

v2 replaces the three-state flag system with two `Intrabarpersist` booleans (`CanLongToday`, `CanShortToday`) and a date-based daily reset. The separation into clearly labelled sections makes each concern independently readable:

- **Daily reset block:** runs once at the start of each new day
- **Time window block:** computes `IsFirstHour` and `TradingAllowed`
- **Channel construction block:** updates `FirstHourHigh` and `FirstHourLow`
- **Entry block:** places limit orders when conditions are met
- **Flag disable block:** disables the direction flag when a position is open
- **Risk management block:** applies stop and target

The flag disable in v2 is also more reliable because it checks `MarketPosition` *after* the entry block has run, and the date-based reset ensures flags never carry over to the next session regardless of how the previous day's positions resolved.

v2 also parameterizes `FirstHourMinutes` (hardcoded to `60` in v1) and adds named order labels (`FHC_LE`, `FHC_SE`).

**Summary:**

| | v1.0 | v2.0 |
|---|---|---|
| **Channel construction** | ✓ | ✓ |
| **One trade per side per day** | ✓ (fragile) | ✓ (robust) |
| **Date-based daily reset** | — | ✓ |
| **`FirstHourMinutes` as parameter** | — | ✓ (hardcoded `60` in v1) |
| **Named order labels** | — | ✓ (`FHC_LE`, `FHC_SE`) |
| **Separated labelled blocks** | — | ✓ |
| **Intrabar flag fragility** | Present | Resolved |

---

## First Hour Channel — Indicator

The indicator runs the same time window and channel construction logic as the strategy and plots `FirstHourHigh` and `FirstHourLow` as horizontal lines during the active trading window. Lines are suppressed outside the channel-active window using `NoPlot`.

```pascal
IsFirstHour = Time <= CalcTime(SessionStartTime(1,1), FirstHourMinutes);

IsChannelActive =
    Time > CalcTime(SessionStartTime(1,1), FirstHourMinutes)
    and Time <= StopPlotTime;

If IsFirstHour Then
Begin
    FirstHourHigh = HighD(0);
    FirstHourLow  = LowD(0);
End;

If IsChannelActive Then
Begin
    Plot1(FirstHourHigh, "FH High");
    Plot2(FirstHourLow,  "FH Low");
End Else
Begin
    NoPlot(1);
    NoPlot(2);
End;
```

**`NoPlot` behavior:** When `IsChannelActive` is `False` — during the first hour itself and after `StopPlotTime` — `NoPlot(1)` and `NoPlot(2)` suppress the channel lines. This keeps the chart clean during the opening window (before the channel is finalized) and after trading stops. The lines only appear during the window when the strategy's entry orders are active.

**Configurable colors:** `HighColor` and `LowColor` inputs (defaulting to Blue and Red) allow the channel boundaries to be visually distinguished and customized to match chart color schemes.

**Indicator parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `FirstHourMinutes` | 60 | Duration of the opening window. Match to strategy setting. |
| `StopPlotTime` | 1500 | Time when channel lines are suppressed. Match to `StopTradingTime` in strategy. |
| `HighColor` | Blue | Color for the upper channel line. |
| `LowColor` | Red | Color for the lower channel line. |

> **Usage note:** Keep `FirstHourMinutes` and `StopPlotTime` identical between the indicator and the strategy to ensure visual channel lines align exactly with the strategy's active entry window.

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `FirstHourMinutes` | 60 | Duration of the opening window used to build the channel. |
| `StopTradingTime` | 1500 | Time (HHMM format) after which no new entries are accepted. |
| `StopLossAmount` | $250 | Fixed dollar stop loss applied to all positions. |
| `ProfitTargetAmount` | $250 | Fixed dollar profit target applied to all positions. |

**On `StopTradingTime`:** The value `1500` represents 15:00 (3:00 PM) in EasyLanguage's HHMM integer format. For instruments with earlier closes (e.g. bond futures at 16:00 CT or equity futures at 16:15 ET), this should be adjusted accordingly. Setting it too close to the session end risks positions not being resolved before close — pair with End-of-Day Exit if overnight positions are unacceptable.

**On stop and target sizing:** The default $250 symmetric values imply a 1:1 risk/reward ratio requiring >50% win rate for profitability. These should be calibrated to the instrument's `BigPointValue` and typical daily range. For ES futures at $50/point, $250 equals 5 points of risk — appropriate for a session with an average daily range of 30–50 points.

---

## Trade Scenarios

### Scenario A — Long Entry at First Hour Low

- Session opens at 09:30. `FirstHourMinutes = 60`.
- During 09:30–10:30: ES reaches a high of 4,985 and a low of 4,962. Channel established: `FirstHourHigh = 4,985`, `FirstHourLow = 4,962`.
- 10:30: `IsFirstHour` transitions to `False`. `TradingAllowed = True`. Both limit orders placed.
- 11:15: Price drops to 4,962. Long limit fills. `CanLongToday = False`.
- Stop at $250 below entry (≈4,957 for ES at $50/pt = 5pts).
- Target at $250 above entry (≈4,967).
- Price rallies. Profit target fills at 4,967. Trade closed.
- Short limit still active — `CanShortToday` still `True`.

### Scenario B — Short Entry at First Hour High, Long Blocked

- Same channel: `FirstHourHigh = 4,985`, `FirstHourLow = 4,962`.
- 10:45: Price rallies to 4,985. Short limit fills. `CanShortToday = False`.
- Stop at $250 above entry; target at $250 below.
- Price continues higher, stop loss fills. Trade closed at loss.
- 12:00: Price drops to 4,962. Long limit would trigger — but `CanLongToday` is still `True`.
- Long entry fills. `CanLongToday = False`.
- Both sides traded for the day.

### Scenario C — StopTradingTime Reached, No Entry

- Channel: `FirstHourHigh = 4,985`, `FirstHourLow = 4,962`.
- Price stays between channel boundaries all day.
- 15:00: `Time > StopTradingTime`. `TradingAllowed = False`. Limit orders no longer placed.
- No trade taken. Strategy resets tomorrow.

---

## Key Features

- **`IntraBarOrderGeneration`:** Required directive enabling limit order fills within a bar, ensuring precise execution at channel boundary levels without waiting for bar close.
- **`SessionStartTime(1,1)` universality:** Opening window calculated from the chart's session definition rather than hardcoded times, making the strategy instrument-agnostic.
- **`HighD(0)` / `LowD(0)` channel building:** Running daily high and low updated continuously during the first hour, capturing the true opening range boundary at the moment the window closes.
- **One trade per direction per day:** Date-based reset combined with `Intrabarpersist` flags prevents re-entry in the same direction after the first trade resolves.
- **Defined trading window:** `TradingAllowed` combines post-opening and pre-cutoff conditions into a single boolean, keeping the entry block clean and readable.
- **`NoPlot` in indicator:** Channel lines suppressed outside the active window keep the chart clean during the opening period and after trading stops.
- **Configurable opening window:** `FirstHourMinutes` as a parameter allows testing with 30-minute, 45-minute, or other opening windows without code changes.

---

## Trade Psychology

First Hour Channel embodies a specific belief about intraday market structure: **the opening hour reveals the day's volatility range, and revisiting its boundaries later in the session represents a high-probability mean-reversion opportunity.**

The opening period is unique in that it concentrates overnight order flow, gap fills, and initial institutional positioning into a compressed window. The high and low established during this period are not random — they reflect the market's initial auction process, where buyers and sellers establish the day's early reference points. When price returns to these levels later in the session, it is testing whether the initial consensus holds.

The one-trade-per-direction rule reflects a disciplined stance on range behavior: once a boundary has been tested and the trade has resolved (whether by stop or target), the boundary has served its purpose for that session. Re-entering the same level multiple times increases exposure to whipsaws — the market may oscillate around the boundary rather than delivering a clean directional move.

The symmetric $250 stop and target encode a neutral view on which direction will prevail: the strategy has no directional bias within the day's range. It simply says *"if price reaches this level, something is likely to happen"* — and accepts equal risk in both directions.

---

## Use Cases

**Instruments:** Well suited to liquid intraday markets with predictable opening volatility — equity index futures (ES, NQ, YM), individual stocks with active opening sessions, and major FX futures. The channel construction requires sufficient price activity during the opening window to establish meaningful boundaries; thinly traded instruments may produce artificially narrow channels.

**Timeframes:** Designed for intraday bars (1-min, 5-min, 15-min). The opening window and channel boundaries are session-specific — the strategy resets fully each day. Bar size affects entry precision: smaller bars allow finer limit order placement and faster response to channel touches.

**Market conditions:** Performs best when the session has directional momentum after the opening window — price breaks to or from a boundary and follows through. Struggles in sessions where price oscillates repeatedly around channel boundaries without resolution, generating multiple boundary touches without clean directional moves. The one-trade-per-side rule limits damage in choppy conditions but also caps upside on very clean trending days.

**Pairing with other components:** First Hour Channel manages entries and risk through fixed stop/target but has no time-based exit. Pairing with End-of-Day Exit ensures positions do not carry overnight if the profit target or stop has not been reached by session end. AccountRiskCore provides account-level daily loss protection independent of the strategy's per-trade stop.
