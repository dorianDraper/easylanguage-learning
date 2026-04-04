# End-of-Day Exit — v1.0 & v2.0

## Strategy Description

End-of-Day Exit is an exit-only component that automatically closes all open positions a configurable number of minutes before the market session ends. It is not a trading strategy — it is a protective wrapper that can be added to any intraday strategy to guarantee that no positions are held overnight. The component handles both live trading and backtesting, using real computer time for live execution and `SetExitOnClose` as a historical approximation for strategy validation.

---

## Core Mechanics

### 1. IntrabarOrderGeneration

```pascal
[IntraBarOrderGeneration = TRUE]
```

This compiler directive must be declared at the top of the script. It instructs TradeStation to evaluate the strategy logic and generate orders *within* each bar as it forms, rather than waiting for the bar to close. Without this directive, the EOD exit check would only run at bar close — by which time the session may have already ended and the position carried overnight. It is the foundational requirement that makes time-based intrabar exits possible.

### 2. Temporal Context Detection

The component determines which execution path to take by evaluating two temporal conditions:

```pascal
IsRealTime  = LastBarOnChart and Date = CurrentDate;
IsEODWindow = CurrentTime >= CalcTime(SessionEndTime(1, 1), -EODExitMinutes);
```

**`IsRealTime`** is `True` only when both conditions hold simultaneously: the current bar is the last bar on the chart (`LastBarOnChart`) *and* the bar's date matches today's date (`Date = CurrentDate`). This combination identifies a live, real-time bar — as opposed to a historical bar being replayed in backtesting.

**`IsEODWindow`** is `True` when the current computer time has reached or passed the calculated exit trigger time. `CalcTime(SessionEndTime(1, 1), -EODExitMinutes)` computes the session close time minus `EODExitMinutes` minutes. `SessionEndTime(1, 1)` returns the official end time of the primary session for the first data series on the chart — this works correctly across stocks, futures, and forex without any instrument-specific configuration.

Think of `IsRealTime` and `IsEODWindow` as two independent clocks that must both agree before the exit fires: one confirms *"this is happening now, not in a historical replay"*, the other confirms *"the clock says it is time to exit."*

### 3. Execution Branches

```pascal
If EODExitMinutes > 0 Then
Begin
    If IsRealTime and IsEODWindow Then
    Begin
        If IsLong  Then Sell       ("EOD_LX") Next Bar at Market;
        If IsShort Then BuyToCover ("EOD_SX") Next Bar at Market;
    End
    Else
        SetExitOnClose;
End;
```

The logic has three possible states:

**Branch A — Live exit (IsRealTime = True, IsEODWindow = True):**
The EOD window has opened on a live bar. Exit orders are placed for the next bar at market. `IntraBarOrderGeneration = TRUE` ensures these orders are submitted before the session closes, not after.

**Branch B — Backtesting approximation (IsRealTime = False):**
The current bar is historical. `SetExitOnClose` instructs the backtesting engine to close the position at the bar's closing price. This is not a perfect simulation of live EOD behavior — in live trading, exit fills depend on market conditions in the final minutes — but it provides a reasonable and consistent approximation for strategy validation.

**Branch C — Guard condition (EODExitMinutes = 0):**
Setting `EODExitMinutes = 0` disables the entire component. Neither live exits nor `SetExitOnClose` are called. This allows the component to be toggled off without removing it from the strategy.

### 4. Position State Machine (v2)

v2 introduces explicit position tracking:

```pascal
IsLong  = MarketPosition =  1;
IsShort = MarketPosition = -1;
```

In v1, exit orders are placed unconditionally — both `Sell` and `BuyToCover` are called regardless of whether a position is open. EasyLanguage ignores exit orders when there is no matching position, so this works in practice, but it generates unnecessary order activity in the platform's order log. In v2, each exit order is only placed when there is an actual position to close.

---

## v1 vs v2: The Difference

The two versions implement identical behavior. The evolution is structural.

### v1 — Compact and Direct

All logic is inline. Exit orders are placed unconditionally (no position check), and there are no named variables for temporal conditions:

```pascal
If LastBarOnChart and Date = CurrentDate Then
Begin
    If CurrentTime >= CalcTime(SessionEndTime(1,1), -MinstoX) Then
    Begin
        Sell ("EOD LX") Next Bar at Market;        // No IsLong check
        BuyToCover ("EOD SX") Next Bar at Market;  // No IsShort check
    End;
End Else
    SetExitOnClose;
```

The logic is correct but requires the reader to parse temporal conditions inline and infer the two-branch structure from the `If / Else` pattern.

### v2 — Named Conditions and Position Guards

v2 extracts the temporal conditions into named booleans and adds position guards before each exit order:

```pascal
IsRealTime  = LastBarOnChart and Date = CurrentDate;
IsEODWindow = CurrentTime >= CalcTime(SessionEndTime(1,1), -EODExitMinutes);

If IsRealTime and IsEODWindow Then
Begin
    If IsLong  Then Sell       ("EOD_LX") Next Bar at Market;
    If IsShort Then BuyToCover ("EOD_SX") Next Bar at Market;
End
Else
    SetExitOnClose;
```

The entry logic now reads as a sentence: *"if we are in real time and the EOD window has opened, close positions."* The conditions are named for what they mean, not what they compute.

v2 also renames the parameter from `MinstoX` to `EODExitMinutes` — the original name was a truncated abbreviation (`Mins to X`, where `X` was presumably "exit") that required guesswork to interpret. The new name is self-explanatory.

**Summary:**

| | v1.0 | v2.0 |
|---|---|---|
| **Exit behavior** | ✓ | ✓ |
| **`SetExitOnClose` for backtesting** | ✓ | ✓ |
| **Named temporal conditions** | — | ✓ (`IsRealTime`, `IsEODWindow`) |
| **Position guards before exits** | — | ✓ (`IsLong`, `IsShort`) |
| **Descriptive parameter name** | `MinstoX` | `EODExitMinutes` |
| **Named order labels** | `EOD LX`, `EOD SX` (space) | `EOD_LX`, `EOD_SX` (underscore) |

> **On order label naming:** v1 uses spaces in order labels (`"EOD LX"`). v2 uses underscores (`"EOD_LX"`), consistent with the component naming convention used across this repository and safer for platform compatibility.

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `EODExitMinutes` | 3 | Minutes before session close to trigger exit orders. Set to `0` to disable the component entirely. |

**On choosing the right value:** The appropriate number of minutes depends on the instrument's liquidity in the final minutes of the session and the platform's order submission latency. Three minutes is a conservative default for liquid futures (ES, NQ) during regular trading hours. Thinly traded instruments or slower order routing may require a larger buffer. Setting this too small risks the exit order not filling before the session closes.

---

## Trade Scenarios

### Scenario A — Live Exit Triggered (Long Position)

- Session end time: 16:00 (4:00 PM). `EODExitMinutes = 3`.
- Exit trigger time: `CalcTime(16:00, -3) = 15:57`.
- At 15:57:30, `CurrentTime >= 15:57` → `IsEODWindow = True`.
- `LastBarOnChart = True`, `Date = CurrentDate` → `IsRealTime = True`.
- `IsLong = True` → `Sell ("EOD_LX") Next Bar at Market` placed.
- Order fills on the next intrabar tick. Position closed before 16:00.

### Scenario B — Live Exit, No Position Open

- Same conditions as Scenario A, but `MarketPosition = 0`.
- `IsRealTime = True`, `IsEODWindow = True`.
- `IsLong = False`, `IsShort = False` → no exit orders placed.
- Component does nothing. No unnecessary order activity (v2 behavior).

### Scenario C — Historical Bar (Backtesting)

- Processing a historical bar from three months ago.
- `LastBarOnChart = False` → `IsRealTime = False`.
- `SetExitOnClose` called → position closes at the bar's closing price.
- This applies to all historical bars regardless of time of day.

### Scenario D — Component Disabled

- `EODExitMinutes = 0`.
- Outer `If EODExitMinutes > 0` guard evaluates to `False`.
- Neither live exits nor `SetExitOnClose` are called.
- Positions managed entirely by the parent strategy's own exit rules.

---

## Key Features

- **Exit-only design:** No entry rules. The component attaches to any existing strategy without interfering with its entry logic.
- **`IntraBarOrderGeneration`:** Required directive that enables intrabar order submission, making time-based exits within a bar possible.
- **Dual-mode execution:** Real computer time for live trading; `SetExitOnClose` for backtesting — both controlled by the same code path.
- **`SessionEndTime(1, 1)` universality:** Session end time is read directly from the chart's session definition, making the component instrument-agnostic. No hardcoded times.
- **Disable via parameter:** Setting `EODExitMinutes = 0` cleanly disables the component without code changes.
- **Position guards (v2):** Exit orders only placed when a matching position exists, keeping the order log clean.

---

## Trade Psychology

The End-of-Day Exit component encodes a simple but important risk management principle: **known risks are preferable to unknown ones.** An intraday strategy that closes at a defined time each day incurs a known, bounded exit cost — slippage in the final minutes of the session. The alternative — holding overnight — exposes the account to gap risk: price moves that occur between the close and the next open, during which no stop loss or trailing stop can protect the position.

For systematic intraday traders, the EOD exit is not a concession to fear — it is a deliberate constraint that keeps the strategy's behavior within the regime it was designed and backtested for. A strategy that was optimized on intraday data and exits intraday has a defined edge within those conditions. Holding overnight introduces a different market regime (lower liquidity, different participants, news events) that the strategy has no model for.

The three-minute buffer before close reflects a practical reality: markets thin out in the final minutes of a session. Exiting slightly before the close typically produces better fills than a market order placed at the last second of trading.

---

## Use Cases

**Intraday strategies requiring daily resets:** Any strategy that assumes flat positioning at the start of each session — momentum, mean reversion, breakout — benefits from a guaranteed EOD close to ensure the next day's signals start from a clean state.

**Overnight gap prevention:** Futures contracts and individual stocks can gap significantly between sessions on news, earnings, or macro events. The EOD exit eliminates this exposure entirely for strategies that have no overnight thesis.

**Regulatory or firm risk limits:** Proprietary trading firms and regulated accounts often impose intraday-only constraints. The EOD exit provides a mechanical enforcement layer that complements AccountRiskCore's account-level protection.

**Backtesting consistency:** `SetExitOnClose` ensures historical simulations reflect an EOD exit discipline, preventing the backtester from holding positions across sessions when the live strategy would not.

**Pairing with other components:** End-of-Day Exit is designed to work alongside entry strategies and risk components like AccountRiskCore and ATRDollar TrailStop. In a typical setup: the entry strategy opens positions, ATRDollar TrailStop manages the trailing exit, AccountRiskCore enforces the daily P&L limit, and End-of-Day Exit ensures nothing survives to the next session.
