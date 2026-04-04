# AccountRiskCore — v1

## System Description

AccountRiskCore is an account-level risk management system that monitors daily profit and loss in real time and automatically halts all trading activity when predefined limits are breached. It is not a trading strategy — it is a protective wrapper that any trading strategy can live inside. The system evaluates account equity continuously, provides visual monitoring and audible alerts, and mechanically closes all open positions the moment a risk threshold is crossed.

The system enforces two symmetric limits: a maximum daily loss (downside protection) and a maximum daily profit (upside discipline). Once either limit is breached, a latch mechanism ensures trading cannot resume for the remainder of the session — even if the P&L recovers back within limits.

AccountRiskCore v1 is composed of six components organised into two versioned pairs plus two shared indicators:

| Component | Type | Role |
|---|---|---|
| `AccountRiskCore_Function_v1` | Function | Core risk evaluation logic (v1) |
| `AccountRiskCore_Function_v2` | Function | Core risk evaluation logic (v2, improved structure) |
| `AccountRiskCore_Strategy_v1` | Strategy | Enforces trading halt and closes positions (calls Function v1) |
| `AccountRiskCore_Strategy_v2` | Strategy | Enforces trading halt with latch mechanism (calls Function v2) |
| `AccountRiskCore_Alert` | Indicator | Real-time notification when limits are breached |
| `AccountRiskCore_Monitor` | Indicator | Continuous visual display of daily P&L and limits |

> **On component naming:** EasyLanguage does not allow dots, spaces, or hyphens in component names. The underscore convention (`AccountRiskCore_Strategy_v1`) is used throughout to maintain readability while complying with TradeStation naming rules.

---

## Architecture Overview

The components share a common design principle: **a single calculation, multiple consumers.** The daily P&L and limit evaluation logic lives in the function layer. Each strategy version calls its corresponding function version. The two indicators replicate the same P&L calculation independently, because EasyLanguage indicators cannot call strategy functions.

```
AccountRiskCore_Function_v1 ──► AccountRiskCore_Strategy_v1
AccountRiskCore_Function_v2 ──► AccountRiskCore_Strategy_v2

AccountRiskCore_Alert    (independent P&L calculation — real-time bars only)
AccountRiskCore_Monitor  (independent P&L calculation — all bars)
```

The strategy/function pairing is explicit by design: v1 strategy with v1 function, v2 strategy with v2 function. This keeps each version self-contained and independently testable.

> **Architectural limitation in v1:** The indicators do not call either function — they duplicate the P&L calculation internally. This redundancy is the primary architectural gap that AccountRiskCore v2 addresses by refactoring into a single shared utility callable by all components.

---

## Component Reference

### AccountRiskCore_Function_v1 and AccountRiskCore_Function_v2

The core of the system. A reusable EasyLanguage function that retrieves real-time account equity, computes the day's P&L, compares it against the configured limits, and returns a boolean indicating whether trading is permitted.

**Function signature (identical in both versions):**

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
BeginDayEquity = GetBDAccountNetWorth(AccountID);   // Start-of-day equity snapshot
CurrentEquity  = GetRTAccountNetWorth(AccountID);   // Real-time equity

// Compute and output daily P&L
DailyNetPL  = CurrentEquity - BeginDayEquity;       // v1 internal variable
oDailyNetPL = DailyNetPL;                           // Pass to caller by reference

// Evaluate limits and return boolean
If DailyNetPL > -MaxDailyLoss
    and DailyNetPL < MaxDailyProfit Then
    AccountRiskCore_Function_v1 = True    // Trading permitted
Else
    AccountRiskCore_Function_v1 = False;  // Trading blocked
```

**Key design decisions:**
- `GetBDAccountNetWorth` retrieves beginning-of-day equity — a snapshot taken at session open. This ensures the daily P&L resets cleanly each session regardless of the prior day's closing equity.
- `GetRTAccountNetWorth` retrieves real-time equity, reflecting all open and closed P&L for the current session.
- `oDailyNetPL` uses `numericref` — a pass-by-reference output — allowing the caller to receive the computed P&L value without making a second equity call.
- The function returns its result by assigning the boolean to its own name (`AccountRiskCore_Function_v1 = True`), which is the standard EasyLanguage pattern for function return values.

**v1 vs v2 — the difference:**

Both versions implement identical logic. The evolution is purely structural:

| | Function v1 | Function v2 |
|---|---|---|
| Internal P&L variable | `DailyNetPL` — visually close to the `oDailyNetPL` output parameter, potential for confusion | `ComputedDailyPL` — distinct name, unambiguous |
| Code organisation | Inline comments | Labelled separated blocks |
| Readability | Functional | Self-documenting |

```pascal
// v1 — internal variable name is close to the output parameter name
Vars: DailyNetPL(0);
DailyNetPL  = CurrentEquity - BeginDayEquity;
oDailyNetPL = DailyNetPL;

// v2 — distinct internal variable, no risk of confusion
Vars: ComputedDailyPL(0);
ComputedDailyPL = CurrentEquity - BeginDayEquity;
oDailyNetPL     = ComputedDailyPL;
```

`AccountRiskCore_Function_v2` is the recommended version and the one called by `AccountRiskCore_Strategy_v2`.

---

### AccountRiskCore_Strategy_v1 and AccountRiskCore_Strategy_v2

The execution layer. Each strategy version calls its corresponding function, enforces the trading permission gate, closes all open positions when limits are breached, and provides an empty block where any trading logic can be placed.

**Strategy v1 — basic gate:**

```pascal
// Evaluate account risk on live bars only; default to allowed on historical bars
If LastBarOnChart Then
    AccountTradingAllowed =
        AccountRiskCore_Function_v1(
            MaxDailyLoss,
            MaxDailyProfit,
            GetAccountID,
            DailyNetPL)
Else
    AccountTradingAllowed = True;

// Kill switch — exit all positions if trading is not allowed
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

**Strategy v2 — latch mechanism:**

v1 has a critical gap: `AccountTradingAllowed` is re-evaluated on every live bar. If the P&L recovers back within limits after a breach — for example, a favorable move in an open position before the kill switch fully executes — the flag could return to `True` on the next bar and re-enable trading. This defeats the purpose of a hard daily stop.

v2 introduces `RiskTriggered`, a boolean latch that, once set to `True`, keeps `AccountTradingAllowed` permanently `False` for the remainder of the session regardless of subsequent P&L movement:

```pascal
If LastBarOnChart Then
Begin
    AccountTradingAllowed =
        AccountRiskCore_Function_v2(
            MaxDailyLoss,
            MaxDailyProfit,
            GetAccountID,
            DailyNetPL);

    // Latch: once triggered, cannot be reset within the session
    If not AccountTradingAllowed Then
        RiskTriggered = True;
End;

// Apply latched state — overrides any subsequent recovery in AccountTradingAllowed
If RiskTriggered Then
    AccountTradingAllowed = False;
```

v2 also changes the kill switch exit from `Next Bar at Market` to `This Bar on Close`, eliminating the one-bar delay:

```pascal
// v1 — exit on next bar (one bar of additional exposure after breach)
Sell ("AcctStop_LX") Next Bar at Market;

// v2 — exit on current bar close (same bar as breach detection)
Sell ("AcctStop_LX") This Bar on Close;
```

**Strategy v1 vs v2 summary:**

| | Strategy v1 | Strategy v2 |
|---|---|---|
| Function called | `AccountRiskCore_Function_v1` | `AccountRiskCore_Function_v2` |
| Latch mechanism | None — re-evaluates every bar | `RiskTriggered` flag permanently latches |
| Kill switch timing | Next bar at market | Same bar on close |
| Re-enablement after breach | Possible if P&L recovers | Impossible — latch holds |
| Code structure | Inline blocks | Labelled separated blocks |

---

### AccountRiskCore_Alert

A real-time indicator that fires an audible and visual alert the moment daily P&L limits are breached. Executes only on live bars (`LastBarOnChart`) to ensure it uses actual real-time equity values rather than stale historical data.

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
        Alert;
End;
```

**Visual plots:**

| Plot | Label | Value |
|---|---|---|
| Plot1 | Daily P&L | Current daily P&L (turns red on breach) |
| Plot2 | Zero | 0 reference line |
| Plot3 | Max Loss | `-MaxDailyLoss` |
| Plot4 | Max Profit | `+MaxDailyProfit` |

A commented-out color scheme (Olive, Gainsboro, IndianRed, RoyalBlue) is available in the source and can be activated by uncommenting.

> **Role:** Alert serves as the early warning layer — it fires when either limit is breached. Actual position closure is handled by the kill switch in `AccountRiskCore_Strategy_v1` or `_v2`.

---

### AccountRiskCore_Monitor

A continuous monitoring indicator that calculates and displays daily P&L on every bar — not just live bars. Unlike `AccountRiskCore_Alert`, Monitor runs on all bars to provide a persistent visual reference of the account's daily risk status throughout the session.

```pascal
// No LastBarOnChart guard — runs on every bar
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
| Plot1 | Daily P&L | Green within limits, red when breached |
| Plot2 | Max Loss | `-MaxDailyLoss` boundary |
| Plot3 | Max Profit | `+MaxDailyProfit` boundary |

A commented-out zero line (Plot4) and explicit color scheme (Darkgreen, Darkred, Cyan, Darkgray) are available for activation.

**Alert vs Monitor — when to use each:**

| | AccountRiskCore_Alert | AccountRiskCore_Monitor |
|---|---|---|
| Execution | Live bars only | Every bar |
| Primary purpose | Notification | Visualization |
| Fires alert | Yes | No |
| Historical display | No | Yes |
| Useful in backtesting | No | Yes (visual review) |

In live trading, both should be active simultaneously: Monitor provides the continuous visual dashboard, Alert provides the real-time notification when action is required.

---

## Parameters

| Parameter | Function v1/v2 | Strategy v1/v2 | Alert | Monitor |
|---|---|---|---|---|
| `MaxDailyLoss` | ✓ | ✓ | ✓ | ✓ |
| `MaxDailyProfit` | ✓ | ✓ | ✓ | ✓ |
| `AccountID` / `AccountNumber` | ✓ (as `AccountID`) | via `GetAccountID` | ✓ (as `AccountNumber`) | ✓ (as `AccountNumber`) |

> **On `AccountID` vs `AccountNumber`:** The functions receive account identity as a string input named `AccountID`; the strategies retrieve it automatically via `GetAccountID` at runtime; the indicators accept it as a string input named `AccountNumber`. All refer to the same broker account identifier. This naming inconsistency is a v1 design artifact.

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
- Monitor displays P&L within the green band `[-MaxDailyLoss, +MaxDailyProfit]`.
- `AccountTradingAllowed = True`. Any strategy inside the gate executes normally.

### Limit Breach Sequence

1. Daily P&L reaches or crosses either limit (loss or profit).
2. The corresponding function returns `False`.
3. **Strategy v1:** `AccountTradingAllowed = False`. Kill switch places exit orders for next bar at market.
4. **Strategy v2:** `AccountTradingAllowed = False`. `RiskTriggered = True` (latch engaged). Kill switch closes positions on this bar's close.
5. `AccountRiskCore_Alert` fires audible/visual notification.
6. Monitor changes Plot1 to red.

### Remainder of Session

- **v1:** `AccountTradingAllowed` could theoretically recover to `True` if P&L moves back within limits — the known gap in v1.
- **v2:** `RiskTriggered = True` holds `AccountTradingAllowed = False` permanently regardless of subsequent P&L movement.
- Monitor remains red. Alert remains active as a reminder.

### Next Session

- All EasyLanguage variables reset between sessions. `RiskTriggered` returns to `False`.
- `GetBDAccountNetWorth` captures new beginning-of-day equity.
- System evaluates fresh from zero daily P&L.

### Full Day Example

| Time | Event | Daily P&L | Status |
|---|---|---|---|
| 09:30 | Session opens | $0 | Trading allowed |
| 10:15 | Two winning trades | +$3,000 | Within limits |
| 11:45 | Profit limit reached | +$5,100 | **Limit breached** |
| 11:45 | Kill switch fires | +$5,100 | Positions closed, latch engaged (v2) |
| 13:00 | Market moves favorably | +$3,800 | Latch holds — no re-entry (v2) |
| 16:00 | Session close | +$3,800 | Day protected |
| 09:30+1 | New session | $0 | System resets |

---

## Key Features

- **Account-level protection:** Risk management operates at the account level, not the trade level. A single system protects all strategies running simultaneously on the same account.
- **Bidirectional limits:** Both loss and profit caps are enforced. The profit cap prevents over-trading on strong days and locks in exceptional results.
- **Latch guarantee (v2):** Once `RiskTriggered` is set, the kill switch cannot be re-enabled within the session by any means.
- **Immediate exit (v2):** `This Bar on Close` exits on the same bar that triggers the breach, eliminating the one-bar delay of v1.
- **Versioned function/strategy pairs:** Each strategy version calls its own function version, keeping the two implementations self-contained and independently testable.
- **Real-time evaluation:** Both strategies use `LastBarOnChart` to ensure only live equity values drive risk decisions. Historical bars default to `AccountTradingAllowed = True` to preserve backtesting compatibility.
- **Strategy agnostic:** Any trading strategy can be placed inside the `If AccountTradingAllowed Then` block without modification.
- **Zero-discretion design:** The system is fully mechanical. Once the latch engages, no intra-session override is possible.

---

## Trade Psychology

AccountRiskCore embodies a single governing principle: **protect the account first, the trade second.**

Most risk management in trading focuses at the position level — stop losses, position sizing, maximum loss per trade. These are necessary but insufficient. A strategy with well-defined per-trade stops can still produce catastrophic session losses through a sequence of maximum losses, or by over-trading a winning streak until it reverses. AccountRiskCore operates one level above: it does not evaluate individual trades, only whether the account as a whole remains within acceptable daily bounds.

The profit cap is psychologically counter-intuitive. Stopping trading after a strong day feels like leaving money on the table. The rationale is the opposite: a day with +$5,000 in P&L is a day worth protecting. Markets that give generously in the morning often take back aggressively in the afternoon. The profit cap is not pessimism — it is the recognition that exceptional days are rare and worth locking in intact.

The latch mechanism addresses a specific psychological trap: the temptation to rationalize re-entry after a limit breach. *"The P&L has recovered, the market looks good, the limit was just briefly touched."* The latch removes this decision entirely. Once triggered, the session is over. The rule was set before the trading day began, when judgment was clear — that pre-commitment is exactly what the latch enforces.

---

## Use Cases

**Proprietary trading desks:** Firms managing multiple traders or strategies under a single account can apply AccountRiskCore as a daily circuit breaker, ensuring no single session produces catastrophic losses regardless of what individual strategies do.

**Individual systematic traders:** A portfolio of algorithmic strategies running simultaneously can overwhelm per-trade risk controls if multiple strategies enter large positions in the same direction. AccountRiskCore provides the final account-level safety net.

**Highly volatile sessions:** Economic releases, earnings announcements, and geopolitical events can produce rapid moves that exceed normal per-trade stop assumptions. The account-level kill switch provides protection in these tail scenarios.

**Discipline enforcement:** For traders prone to revenge trading or over-trading after large wins, the mechanical latch removes the decision entirely. The system enforces rules that were set with a clear head before the session began.

**Multi-strategy portfolios:** A single AccountRiskCore instance wraps any combination of strategies — ES trend-following, NQ mean reversion, CL momentum — treating them as a unified account exposure rather than independent risks.
