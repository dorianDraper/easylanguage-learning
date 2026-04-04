# AccountRiskCore — v1

## System Description

AccountRiskCore is an account-level risk management system that monitors daily profit and loss in real time and automatically halts all trading activity when predefined limits are breached. It is not a trading strategy — it is a protective wrapper that any trading strategy can live inside. The system evaluates account equity continuously, provides visual monitoring and audible alerts, and mechanically closes all open positions the moment a risk threshold is crossed.

The system enforces two symmetric limits: a maximum daily loss (downside protection) and a maximum daily profit (upside discipline). Once either limit is breached, a latch mechanism ensures trading cannot resume for the remainder of the session — even if the P&L recovers back within limits.

AccountRiskCore v1 is composed of four components that work together as a single integrated system:

| Component | Type | Role |
|---|---|---|
| `AccountRiskCore.Function` | Function | Core risk evaluation logic |
| `AccountRiskCore.Strategy` | Strategy | Enforces trading halt and closes positions |
| `AccountRiskCore.Alert` | Indicator | Real-time notification when limits are breached |
| `AccountRiskCore.Monitor` | Indicator | Continuous visual display of daily P&L and limits |

---

## Architecture Overview

The four components share a common design principle: **a single calculation, multiple consumers.** The daily P&L and limit evaluation logic lives in `AccountRiskCore.Function`. Every other component either calls this function directly or replicates the same calculation independently for display purposes.

```
AccountRiskCore.Function
        │
        ├──► AccountRiskCore.Strategy  (enforces halt + kill switch)
        │
        ├──► AccountRiskCore.Alert     (fires alert when limits breached)
        │
        └──► AccountRiskCore.Monitor   (plots P&L and limit bands)
```

`AccountRiskCore.Strategy` is the only component that calls the function directly. The two indicators replicate the P&L calculation independently because EasyLanguage indicators cannot call strategy functions — they use the same logic but via direct equity calls rather than the shared function.

> **v1 architectural note:** In v1, the indicators do not call `AccountRiskCore.Function` — they duplicate the P&L calculation internally. This redundancy is the primary architectural limitation that v2 addresses by refactoring the function into a shared utility callable by all components.

---

## Component Reference

### AccountRiskCore.Function

**Previously named:** `AccountEquityStop_JP`

The core of the system. A reusable EasyLanguage function that retrieves real-time account equity, computes the day's P&L, compares it against the configured limits, and returns a boolean indicating whether trading is permitted.

**Function signature:**
```pascal
Inputs:
    MaxDailyLoss(numeric),      // Maximum allowed daily loss in dollars
    MaxDailyProfit(numeric),    // Maximum allowed daily profit in dollars
    AccountID(string),          // Account identifier for equity retrieval
    oDailyNetPL(numericref);    // Output: current daily P&L passed by reference
```

**Internal logic:**

```pascal
// Retrieve equity values
BeginDayEquity = GetBDAccountNetWorth(AccountID);   // Start-of-day equity
CurrentEquity  = GetRTAccountNetWorth(AccountID);   // Real-time equity

// Compute daily P&L
DailyNetPL  = CurrentEquity - BeginDayEquity;
oDailyNetPL = DailyNetPL;   // Pass P&L back to caller by reference

// Evaluate limits and return result
If DailyNetPL > -MaxDailyLoss
    and DailyNetPL < MaxDailyProfit Then
    AccountEquityStop_JP = True    // Trading permitted
Else
    AccountEquityStop_JP = False;  // Trading blocked
```

**Key design decisions:**
- `GetBDAccountNetWorth` retrieves beginning-of-day equity — a snapshot taken at session open, not the prior close. This ensures the daily P&L resets cleanly each session.
- `GetRTAccountNetWorth` retrieves real-time equity, reflecting all open and closed P&L for the current session.
- The `oDailyNetPL` output parameter uses `numericref` — a pass-by-reference mechanism — allowing the caller to receive the computed P&L value without a second equity call.
- The function name `AccountEquityStop_JP` is preserved in v1 code for TradeStation compatibility; the rename to `AccountRiskCore.Function` applies to documentation and repository naming.

**Function v1 vs Function v2 — the difference:**

Both versions implement identical logic. The evolution is structural:

| | Function v1 | Function v2 |
|---|---|---|
| Internal variable naming | `DailyNetPL` (shadows output parameter name) | `ComputedDailyPL` (distinct name, no shadowing) |
| Code blocks | Inline comments | Separated labelled blocks |
| Readability | Functional | Cleaner, self-documenting |

```pascal
// v1 — variable name shadows the output parameter
DailyNetPL  = CurrentEquity - BeginDayEquity;
oDailyNetPL = DailyNetPL;

// v2 — distinct internal variable, no ambiguity
ComputedDailyPL = CurrentEquity - BeginDayEquity;
oDailyNetPL     = ComputedDailyPL;
```

Function v2 is the recommended version and the one used in `AccountRiskCore.Strategy v2`.

---

### AccountRiskCore.Strategy

**Previously named:** `Account Equity Risk Gate with Kill Switch`

The execution layer. This component calls `AccountRiskCore.Function` on every live bar, enforces the latch mechanism, closes all open positions when limits are breached, and gates any trading strategy inside a permission block.

**Strategy v1:**

```pascal
// Evaluate account risk on live bars only
If LastBarOnChart Then
    AccountTradingAllowed =
        AccountEquityStop_JP(
            MaxDailyLoss,
            MaxDailyProfit,
            GetAccountID,
            DailyNetPL)
Else
    AccountTradingAllowed = True;   // Historical bars: assume trading allowed

// Kill switch
If not AccountTradingAllowed Then
Begin
    If IsLong  Then Sell       ("AcctStop_LX") Next Bar at Market;
    If IsShort Then BuyToCover ("AcctStop_SX") Next Bar at Market;
End;

// Strategy execution gate
If AccountTradingAllowed Then
Begin
    // Strategy logic here
End;
```

**Strategy v2 — the latch mechanism:**

v1 has a critical gap: `AccountTradingAllowed` is re-evaluated on every bar. If the P&L recovers back within limits after a breach — for example, an open position moves favorably — the flag could return to `True` and re-enable trading. This defeats the purpose of a hard daily stop.

v2 introduces `RiskTriggered`, a boolean latch that, once set to `True`, keeps `AccountTradingAllowed` permanently `False` for the remainder of the session:

```pascal
If LastBarOnChart Then
Begin
    AccountTradingAllowed =
        AccountEquityStop_JP(
            MaxDailyLoss,
            MaxDailyProfit,
            GetAccountID,
            DailyNetPL);

    // Latch: once triggered, cannot be reset within the session
    If not AccountTradingAllowed Then
        RiskTriggered = True;
End;

// Apply latched state
If RiskTriggered Then
    AccountTradingAllowed = False;
```

v2 also changes the kill switch exit order from `Next Bar at Market` to `This Bar on Close`:

```pascal
// v1 — exit on next bar
Sell ("AcctStop_LX") Next Bar at Market;

// v2 — exit on current bar close (faster, same session)
Sell ("AcctStop_LX") This Bar on Close;
```

`This Bar on Close` executes on the same bar that triggered the breach, eliminating the one-bar delay of v1 and reducing exposure during the period between detection and exit.

**Strategy v1 vs v2 summary:**

| | Strategy v1 | Strategy v2 |
|---|---|---|
| Latch mechanism | None — re-evaluates every bar | `RiskTriggered` flag permanently latches |
| Kill switch timing | Next bar at market | Same bar on close |
| Re-enablement after breach | Possible if P&L recovers | Impossible — latch holds |
| Code structure | Inline blocks | Labelled separated blocks |

---

### AccountRiskCore.Alert

**Previously named:** `AccountEquityAlert`

A real-time indicator that fires an audible and visual alert the moment daily P&L limits are breached. Executes only on live bars (`LastBarOnChart`) to ensure it uses actual real-time equity values rather than historical data.

```pascal
If LastBarOnChart Then
Begin
    BDAccountEquity      = GetBDAccountNetWorth(AccountNumber);
    CurrentAccountEquity = GetRTAccountNetWorth(AccountNumber);
    DailyNetPL           = CurrentAccountEquity - BDAccountEquity;

    WithinLimits =
        DailyNetPL > -MaxDailyLoss
        and DailyNetPL < MaxDailyProfit;

    If not WithinLimits Then
        Alert;   // Fires audible/visual alert
End;
```

**Visual plots:**

| Plot | Label | Value |
|---|---|---|
| Plot1 | Daily P&L | Current daily P&L |
| Plot2 | Zero | 0 reference line |
| Plot3 | Max Loss | `-MaxDailyLoss` |
| Plot4 | Max Profit | `+MaxDailyProfit` |

Plot1 turns red when limits are breached. Default colors are defined in commented-out blocks in the code, providing a ready-made color scheme (Olive for P&L, Gainsboro for zero, IndianRed for loss limit, RoyalBlue for profit limit) that can be activated by uncommenting.

> **Scope:** Alert fires when *either* limit is breached — loss or profit. It serves as an early warning layer; the kill switch in `AccountRiskCore.Strategy` handles actual position closure.

---

### AccountRiskCore.Monitor

**Previously named:** `AccountEquityMonitor`

A continuous monitoring indicator that calculates and displays daily P&L on every bar — not just live bars. Unlike the Alert component, Monitor runs on all bars to provide a persistent visual reference of the account's daily risk status throughout the session.

```pascal
// Runs on every bar (no LastBarOnChart guard)
BDAccountEquity      = GetBDAccountNetWorth(AccountNumber);
CurrentAccountEquity = GetRTAccountNetWorth(AccountNumber);
DailyNetPL           = CurrentAccountEquity - BDAccountEquity;

WithinLimits =
    DailyNetPL > -MaxDailyLoss
    and DailyNetPL < MaxDailyProfit;
```

**Visual plots:**

| Plot | Label | Value |
|---|---|---|
| Plot1 | Daily P&L | Current daily P&L (green/red) |
| Plot2 | Max Loss | `-MaxDailyLoss` boundary |
| Plot3 | Max Profit | `+MaxDailyProfit` boundary |

Plot1 is green when P&L is within limits and turns red when either boundary is crossed. A commented-out Plot4 (zero line) is available for activation.

**Alert vs Monitor — when to use each:**

| | AccountRiskCore.Alert | AccountRiskCore.Monitor |
|---|---|---|
| Execution | Live bars only | Every bar |
| Primary purpose | Notification | Visualization |
| Fires alert | Yes | No |
| Historical display | No | Yes |
| Use during live trading | Yes (notification layer) | Yes (visual layer) |
| Use in backtesting | Not useful | Useful for visual review |

In live trading, both components should be active simultaneously: Monitor provides the continuous visual dashboard, Alert provides the real-time notification when action is required.

---

## Parameters

| Parameter | Function | Strategy | Alert | Monitor |
|---|---|---|---|---|
| `MaxDailyLoss` | ✓ | ✓ | ✓ | ✓ |
| `MaxDailyProfit` | ✓ | ✓ | ✓ | ✓ |
| `AccountID` / `AccountNumber` | ✓ (as `AccountID`) | via `GetAccountID` | ✓ (as `AccountNumber`) | ✓ (as `AccountNumber`) |

> **On `AccountID` vs `AccountNumber`:** The function uses `AccountID` (string input passed by the caller); the strategy retrieves it automatically via `GetAccountID`; the indicators use `AccountNumber` as a string input. All refer to the same broker account identifier — the naming inconsistency is a v1 artifact addressed in v2.

| Parameter | Default | Description |
|---|---|---|
| `MaxDailyLoss` | $5,000 | Maximum daily loss in dollars before all trading halts. |
| `MaxDailyProfit` | $5,000 | Maximum daily profit in dollars before all trading halts. |
| `AccountID` / `AccountNumber` | `""` | Broker account identifier used to retrieve equity values. |

---

## System Behavior

### Normal Trading State

- Session opens. `GetBDAccountNetWorth` captures beginning-of-day equity.
- `DailyNetPL = 0`. Both limits inactive.
- Monitor displays P&L line within the green band between `[-MaxDailyLoss, +MaxDailyProfit]`.
- `AccountTradingAllowed = True`. Strategy executes normally.

### Limit Breach Sequence

1. Daily P&L reaches or crosses a limit (loss or profit).
2. `AccountRiskCore.Function` returns `False`.
3. **Strategy v1:** `AccountTradingAllowed = False` on this bar. Kill switch places exit orders for next bar at market.
4. **Strategy v2:** `AccountTradingAllowed = False`. `RiskTriggered = True` (latch engaged). Kill switch closes positions on this bar's close.
5. `AccountRiskCore.Alert` fires audible/visual notification.
6. Monitor changes Plot1 to red.

### Remainder of Session

- `RiskTriggered = True` (v2 only): latch holds `AccountTradingAllowed = False` regardless of subsequent P&L movement.
- No new entries permitted. Strategy execution gate blocked.
- Monitor remains red. Alert remains active as a reminder.

### Next Session

- `RiskTriggered` resets to `False` (EasyLanguage variables reset between sessions).
- `GetBDAccountNetWorth` captures new beginning-of-day equity.
- System evaluates fresh from zero daily P&L.

### Full Day Example

| Time | Event | Daily P&L | Status |
|---|---|---|---|
| 09:30 | Session opens | $0 | Trading allowed |
| 10:15 | Two winning trades | +$3,000 | Within limits |
| 11:45 | Profit limit reached | +$5,100 | **Limit breached** |
| 11:45 | Kill switch fires | +$5,100 | Positions closed, latch engaged |
| 13:00 | Open trade would have recovered | +$3,800 | Latch holds — no re-entry |
| 16:00 | Session close | +$3,800 | Day protected |
| 09:30+1 | New session | $0 | System resets |

---

## Key Features

- **Account-level protection:** Risk management operates at the account level, not the trade level. A single system protects all strategies running simultaneously.
- **Bidirectional limits:** Both loss and profit caps are enforced. The profit cap prevents over-trading on strong days and locks in exceptional results.
- **Latch guarantee (v2):** Once triggered, the kill switch cannot be re-enabled within the session — not by P&L recovery, not by manual logic. The latch is a one-way gate.
- **Immediate exit (v2):** `This Bar on Close` exits on the same bar that triggers the breach, eliminating the one-bar delay of v1's `Next Bar at Market`.
- **Single source of truth:** All risk evaluation logic lives in `AccountRiskCore.Function`. The strategy and indicators all derive their permission state from the same calculation.
- **Real-time evaluation:** The function and strategy use `LastBarOnChart` to ensure only live equity values are used for risk decisions. Historical bars default to `AccountTradingAllowed = True` to allow backtesting.
- **Zero-discretion design:** The system is fully mechanical. No manual override is possible within a session once the latch is engaged.
- **Strategy agnostic:** Any trading strategy can be placed inside the `If AccountTradingAllowed Then` block without modification. The risk wrapper is completely independent of entry and exit logic.

---

## Trade Psychology

AccountRiskCore embodies a single governing principle: **protect the account first, the trade second.**

Most risk management in trading focuses at the position level — stop losses, position sizing, maximum loss per trade. These are necessary but insufficient. A strategy with a well-defined per-trade stop can still blow up an account through a sequence of maximum losses in a single session, or through over-trading a winning streak until it reverses. AccountRiskCore operates one level above: it does not care about individual trades, only about whether the account as a whole is within acceptable daily bounds.

The profit cap deserves particular attention because it is psychologically counter-intuitive. Stopping trading after a strong day feels like leaving money on the table. The rationale is the opposite: a day with +$5,000 in P&L is a day worth protecting. Markets that give generously in the morning often take back aggressively in the afternoon. The profit cap is not pessimism — it is the recognition that exceptional days are rare and worth locking in.

The latch mechanism addresses a specific psychological trap: the temptation to rationalize re-entry after a limit breach. *"The P&L has recovered, the market looks good, the limit was just briefly touched."* The latch removes this decision entirely. Once triggered, the session is over. The rule was set before the trading day began, when judgment was clear — that pre-commitment is exactly what the latch enforces.

---

## Use Cases

**Proprietary trading desks:** Firms managing multiple traders or strategies under a single account can apply AccountRiskCore as a daily circuit breaker, ensuring no single session can produce catastrophic losses regardless of what individual strategies do.

**Individual systematic traders:** A portfolio of algorithmic strategies running simultaneously can overwhelm per-trade risk controls if multiple strategies enter large positions in the same direction. AccountRiskCore provides the final account-level safety net.

**Highly volatile sessions:** Economic releases, earnings announcements, and geopolitical events can produce rapid, large moves that exceed normal per-trade stop assumptions. The account-level kill switch provides protection in these tail scenarios.

**Discipline enforcement:** For traders prone to revenge trading or over-trading after large wins, the mechanical latch removes the decision entirely. The system enforces the rules that were set with a clear head before the session began.

**Multi-strategy portfolios:** AccountRiskCore is designed to wrap any strategy without modification. A single instance can protect ES trend-following, NQ mean reversion, and CL momentum strategies simultaneously, treating them as a unified account rather than independent risks.
