# AccountRiskCore — v2

## System Description

AccountRiskCore v2 is an architectural evolution of the v1 system. The trading logic and risk protection behavior are identical — daily P&L monitoring, bidirectional limits, latch mechanism, and kill switch — but v2 restructures how the core function is consumed. In v1, `AccountRiskCore_Function` was called only by the strategy; the indicators duplicated the P&L calculation internally. In v2, all four components call the same function, achieving true separation of concerns and eliminating all redundant logic.

The function itself also gains a new output parameter (`oWithinLimits`) that exposes the boolean limit evaluation directly, so callers no longer need to infer status from the return value alone.

AccountRiskCore v2 is composed of four components, each named with the `_v2` suffix to identify their generation within the system:

| Component | Type | Role |
|---|---|---|
| `AccountRiskCore_Function_v2` | Function | Centralized risk calculation — single source of truth |
| `AccountRiskCore_Strategy_v2` | Strategy | Enforces trading halt, latch, and kill switch |
| `AccountRiskCore_Alert_v2` | Indicator | Real-time notification when limits are breached |
| `AccountRiskCore_Monitor_v2` | Indicator | Continuous visual display of daily P&L and limits |

> **On versioning:** Components carry the `_v2` suffix to indicate they belong to the second generation of the AccountRiskCore system, not to distinguish versions within this folder. This convention allows strategies and indicators to import components by generation (`AccountRiskCore_Function_v2`) and makes future evolution (v3, v4) unambiguous.

> **On component naming:** EasyLanguage does not allow dots, spaces, or hyphens in component names. The underscore convention is used throughout to comply with TradeStation naming rules while preserving readability.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│              AccountRiskCore v2 — Architecture              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         AccountRiskCore_Function_v2                  │   │
│  │         (Single Source of Truth)                     │   │
│  │  ├─ Retrieves begin-of-day equity                    │   │
│  │  ├─ Retrieves real-time equity                       │   │
│  │  ├─ Calculates daily P&L         → oDailyNetPL       │   │
│  │  ├─ Evaluates limits             → oWithinLimits     │   │
│  │  └─ Returns trading permission   → True / False      │   │
│  └──────────────────────────────────────────────────────┘   │
│           │               │               │                 │
│           ▼               ▼               ▼                 │
│  ┌──────────────┐  ┌────────────┐  ┌─────────────┐          │
│  │  Strategy_v2 │  │ Monitor_v2 │  │  Alert_v2   │          │
│  │              │  │            │  │             │          │
│  │ Kill switch  │  │ Visualizes │  │ Notifies    │          │
│  │ Latch        │  │ P&L and    │  │ on breach   │          │
│  │ Trade gate   │  │ limits     │  │             │          │
│  └──────────────┘  └────────────┘  └─────────────┘          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**The key architectural change from v1:** In v1, the indicators duplicated the equity retrieval and P&L calculation internally because they could not call the function. In v2, all three consumers — strategy, monitor, and alert — call `AccountRiskCore_Function_v2` directly. This means the risk calculation logic exists in exactly one place.

**v1 vs v2 architecture at a glance:**

| | AccountRiskCore v1 | AccountRiskCore v2 |
|---|---|---|
| Function called by strategy | ✓ | ✓ |
| Function called by indicators | ✗ (duplicated logic) | ✓ |
| `oWithinLimits` output | ✗ | ✓ |
| Single source of truth | Partial | Complete |
| Components in folder | 6 (2 functions, 2 strategies, 2 indicators) | 4 (1 of each) |

---

## Component Reference

### AccountRiskCore_Function_v2

The core of the system. A centralized EasyLanguage function that handles all risk calculation and exposes results through three outputs: a return value, a P&L reference, and a boolean limit status reference.

**Function signature:**

```pascal
Inputs:
    MaxDailyLoss(numeric),          // Maximum allowed daily loss in dollars
    MaxDailyProfit(numeric),        // Maximum allowed daily profit in dollars
    AccountID(string),              // Account identifier for equity retrieval
    oDailyNetPL(numericref),        // Output: current daily P&L
    oWithinLimits(truefalseref);    // Output: True if P&L is within limits
```

**Internal logic:**

```pascal
// Retrieve equity values
BeginDayEquity = GetBDAccountNetWorth(AccountID);
CurrentEquity  = GetRTAccountNetWorth(AccountID);

// Compute daily P&L and pass outputs
ComputedPL    = CurrentEquity - BeginDayEquity;
oDailyNetPL   = ComputedPL;

// Evaluate limits — result exposed via both oWithinLimits and return value
oWithinLimits =
    (ComputedPL > -MaxDailyLoss) and
    (ComputedPL <  MaxDailyProfit);

AccountRiskCore_Function_v2 = oWithinLimits;
```

**The new `oWithinLimits` output parameter:**

In v1, the function only returned a boolean via its return value. Callers could determine trading permission (`True`/`False`) but had no named variable to use for color coding or conditional logic in indicators without making additional calculations.

v2 adds `oWithinLimits` as a `truefalseref` output — a pass-by-reference boolean. This means the calling component receives both the return value and a named boolean variable populated by the function. The monitor and alert indicators use `oWithinLimits` directly for their color logic, eliminating any need for the indicators to perform their own limit evaluation.

**What changed from v1 functions:**

| | Function v1 / v2 (in v1 folder) | Function_v2 (this version) |
|---|---|---|
| `oDailyNetPL` output | ✓ | ✓ |
| `oWithinLimits` output | ✗ | ✓ |
| Called by indicators | ✗ | ✓ |
| Internal variable naming | `DailyNetPL` / `ComputedDailyPL` | `ComputedPL` (clean, unambiguous) |

> **Note on the trailing underscore in v1 code:** The original source code shows `AccountRiskCore_Function_ = oWithinLimits` with a trailing underscore in the return assignment. This is a typo in the function name — the correct name is `AccountRiskCore_Function_v2`. TradeStation will flag this as a mismatch at compile time. Ensure the return assignment matches the declared function name exactly.

---

### AccountRiskCore_Strategy_v2

The execution layer. Structurally identical to `AccountRiskCore_Strategy_v2` in the v1 folder, with one change: it calls `AccountRiskCore_Function_v2` (this version) and receives the additional `WithinLimits` output, which is available for use within the strategy container block if needed.

```pascal
If LastBarOnChart Then
Begin
    AccountTradingAllowed =
        AccountRiskCore_Function_v2(
            MaxDailyLoss,
            MaxDailyProfit,
            GetAccountID,
            DailyNetPL,
            WithinLimits);      // New: receives boolean limit status directly

    If not AccountTradingAllowed Then
        RiskTriggered = True;
End;

If RiskTriggered Then
    AccountTradingAllowed = False;

// Kill switch
If not AccountTradingAllowed Then
Begin
    If IsLong  Then Sell       ("AcctStop_LX") This Bar on Close;
    If IsShort Then BuyToCover ("AcctStop_SX") This Bar on Close;
End;

// Strategy gate
If AccountTradingAllowed Then
Begin
    // Strategy logic here
End;
```

The latch mechanism (`RiskTriggered`) and `This Bar on Close` exit behavior are preserved from v1's Strategy_v2. The behavioral difference is solely in the function being called and the availability of `WithinLimits` as a named variable within the strategy.

---

### AccountRiskCore_Monitor_v2

The key change in this component is the elimination of internal equity calls. In v1, the monitor calculated `DailyNetPL` by calling `GetBDAccountNetWorth` and `GetRTAccountNetWorth` directly. In v2, it calls `AccountRiskCore_Function_v2` and receives both `DailyNetPL` and `WithinLimits` as outputs:

```pascal
// v1 Monitor — duplicated equity calculation
BDAccountEquity      = GetBDAccountNetWorth(AccountNumber);
CurrentAccountEquity = GetRTAccountNetWorth(AccountNumber);
DailyNetPL           = CurrentAccountEquity - BDAccountEquity;
WithinLimits         = DailyNetPL > -MaxDailyLoss and DailyNetPL < MaxDailyProfit;

// v2 Monitor — single function call, all outputs received
TradingAllowed =
    AccountRiskCore_Function_v2(
        MaxDailyLoss,
        MaxDailyProfit,
        AccountNumber,
        DailyNetPL,       // Populated by function
        WithinLimits);    // Populated by function
```

The plotting and color logic is unchanged — `WithinLimits` still drives the green/red color switch on Plot1:

```pascal
Plot1(DailyNetPL, "Daily P&L");
Plot2(-MaxDailyLoss, "Max Loss");
Plot3(MaxDailyProfit, "Max Profit");

If WithinLimits Then
    SetPlotColor(1, Green)
Else
    SetPlotColor(1, Red);
```

> **Note:** `AccountRiskCore_Monitor_v2` does not use `LastBarOnChart` — it runs on every bar to provide continuous visual feedback. This means `AccountRiskCore_Function_v2` is called on every bar by the monitor, which is correct behavior: the monitor's job is to always show current status, not just on live bars.

---

### AccountRiskCore_Alert_v2

Like the monitor, the alert component now calls `AccountRiskCore_Function_v2` instead of performing its own equity calculations:

```pascal
If LastBarOnChart Then
Begin
    TradingAllowed =
        AccountRiskCore_Function_v2(
            MaxDailyLoss,
            MaxDailyProfit,
            AccountNumber,
            DailyNetPL,
            WithinLimits);

    If not TradingAllowed Then
        Alert;
End;
```

The alert retains the `LastBarOnChart` guard — it should only fire on live bars, not replay historical data. The `WithinLimits` output from the function drives the Plot1 color:

```pascal
Plot1(DailyNetPL, "Daily P&L");
Plot2(0, "Zero");
Plot3(-MaxDailyLoss, "Max Loss");
Plot4(MaxDailyProfit, "Max Profit");

If not WithinLimits Then
    SetPlotColor(1, Red);
```

**Alert vs Monitor — execution scope:**

| | AccountRiskCore_Alert_v2 | AccountRiskCore_Monitor_v2 |
|---|---|---|
| `LastBarOnChart` guard | Yes — live bars only | No — every bar |
| Function call frequency | Once per live bar | Every bar |
| Fires alert | Yes | No |
| Historical display | No | Yes |

---

## Parameters

All four components share the same three parameters, now fully consistent across the system — the `AccountID` vs `AccountNumber` naming inconsistency present in v1 is resolved:

| Parameter | Function_v2 | Strategy_v2 | Alert_v2 | Monitor_v2 |
|---|---|---|---|---|
| `MaxDailyLoss` | ✓ | ✓ | ✓ | ✓ |
| `MaxDailyProfit` | ✓ | ✓ | ✓ | ✓ |
| `AccountID` / `AccountNumber` | ✓ (`AccountID`) | via `GetAccountID` | ✓ (`AccountNumber`) | ✓ (`AccountNumber`) |

| Parameter | Default | Description |
|---|---|---|
| `MaxDailyLoss` | $5,000 | Maximum daily loss in dollars before all trading halts. |
| `MaxDailyProfit` | $5,000 | Maximum daily profit in dollars before all trading halts. |
| `AccountID` / `AccountNumber` | `""` | Broker account identifier for equity retrieval. |

> **Remaining naming inconsistency:** The function uses `AccountID` while the indicators use `AccountNumber`. Both refer to the same broker account string. A future v3 could standardize this to a single name across all components.

---

## System Behavior

System behavior is identical to AccountRiskCore v1 Strategy_v2. The architectural change does not affect any observable trading behavior — the same limits, the same latch, the same kill switch, the same session reset.

### Full Day Example

| Time | Event | Daily P&L | Status |
|---|---|---|---|
| 09:30 | Session opens | $0 | Trading allowed |
| 10:15 | Two winning trades | +$3,000 | Within limits — Monitor green |
| 11:45 | Profit limit reached | +$5,100 | **Limit breached** |
| 11:45 | Kill switch fires | +$5,100 | Positions closed, latch engaged |
| 11:45 | Alert fires | +$5,100 | Audible/visual notification |
| 13:00 | Market moves favorably | +$3,800 | Latch holds — no re-entry |
| 16:00 | Session close | +$3,800 | Day protected |
| 09:30+1 | New session | $0 | All variables reset |

### Information Flow Across Components

| Event | Function_v2 | Monitor_v2 | Alert_v2 | Strategy_v2 |
|---|---|---|---|---|
| P&L +$2,000 (within limits) | Returns True | Green | — | Trading continues |
| P&L +$5,200 (breach) | Returns False | Red | Alert fires | Closes positions |
| P&L recovers to +$4,000 (latched) | Returns True | Red (latch holds) | — | Still stopped |
| Next session | Resets | Green | — | Can trade again |

---

## Key Features

- **True single source of truth:** All four components call `AccountRiskCore_Function_v2`. No component duplicates equity retrieval or limit evaluation logic.
- **`oWithinLimits` output:** Exposes the boolean limit status directly from the function, eliminating any need for callers to re-evaluate limits after receiving the return value.
- **Simplified indicator code:** Monitor and Alert components are significantly shorter in v2 — each replaces six lines of equity calculation and limit logic with a single function call.
- **Consistent behavior guarantee:** Because all components call the same function, it is impossible for them to evaluate risk differently. In v1, a bug in the duplicated indicator logic could have produced inconsistent status display while the strategy was executing correctly.
- **Latch and kill switch preserved:** The behavioral protections from v1 Strategy_v2 are fully carried forward.
- **Same observable behavior:** From a trading perspective, v2 behaves identically to v1. The improvement is architectural, not behavioral.

---

## Trade Psychology

AccountRiskCore v2 does not change what the system does — it changes how it does it. The behavioral philosophy described in the v1 documentation applies in full: protect the account first, enforce bidirectional limits, prevent re-entry via the latch, and remove intra-session discretion entirely.

What v2 adds is an architectural discipline that mirrors the same principle applied to code: **eliminate redundancy, centralize truth.** A system where four components independently calculate the same value is a system with four potential points of inconsistency. v2 collapses those four independent calculations into one, just as the latch mechanism collapses four potential re-entry decisions into one rule.

The `oWithinLimits` output is a small but meaningful design improvement: instead of forcing callers to infer limit status from the return value and then re-evaluate for their own display logic, the function simply tells them directly. Fewer inferences, fewer potential mismatches between what the system is doing and what it is showing. In risk management systems — as in trading — clarity and consistency are not aesthetic preferences; they are safety requirements.

---

## Use Cases

Identical to AccountRiskCore v1. The architectural improvement does not change the system's applicability — it improves its maintainability and consistency, which matters most when modifying parameters, adding new components, or debugging unexpected behavior in live trading.

**When to use v2 over v1:**

- **New deployments:** v2 should be the default choice for any new system setup. The architecture is cleaner and more maintainable.
- **Extending the system:** If a new component needs to display or react to account risk status, v2 makes it trivial — call the function and receive all outputs. In v1, each new component would require duplicating the equity calculation.
- **Debugging:** When behavior is unexpected, v2 offers a single point of investigation. In v1, inconsistencies between indicator display and strategy execution could require checking three separate codebases.

**When v1 remains relevant:**

- **Existing live deployments:** If v1 is already running and performing correctly, migrating to v2 mid-deployment introduces unnecessary risk. v1 Strategy_v2 provides all the behavioral protections of v2.
- **TradeStation compatibility:** If the platform version in use has any restrictions on calling functions from indicators, v1's independent calculation approach remains valid.
