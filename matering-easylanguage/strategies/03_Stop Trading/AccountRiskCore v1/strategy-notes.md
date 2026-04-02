## Strategy Description

The **Account Equity Risk Gate with Kill Switch** is a four-component account-level risk management system that monitors daily profit/loss and automatically stops trading when predefined limits are breached. The system evaluates account equity in real-time, provides visual monitoring and alerts, and mechanically closes all open positions when risk thresholds are exceeded.

### Component 1: AccountEquityStop_JP - Function v2

**Purpose:** Core risk evaluation function that measures daily P&L and determines trading permission.

**Operation:**

1. **Retrieves Start-of-Day Equity:** `BeginDayEquity = GetBDAccountNetWorth(AccountID)`
2. **Retrieves Real-Time Equity:** `CurrentEquity = GetRTAccountNetWorth(AccountID)`
3. **Calculates Daily P&L:** `ComputedDailyPL = CurrentEquity - BeginDayEquity`
4. **Evaluates Limits:**
   - Trading allowed if: `ComputedDailyPL > -MaxDailyLoss` AND `ComputedDailyPL < MaxDailyProfit`
   - Trading blocked if either limit is violated
5. **Returns Result:** `True` (trading allowed) or `False` (trading blocked)

**Outputs:**

- Return value: Boolean (trading permission)
- By reference: `oDailyNetPL` (current daily profit/loss amount)

**Parameters:**

- `MaxDailyLoss`: Maximum daily loss in dollars before halt (default: $5,000)
- `MaxDailyProfit`: Maximum daily profit in dollars before halt (default: $5,000)
- `AccountID`: Account identifier for equity retrieval

### Component 2: Account Equity Risk Gate with Kill Switch v2

**Purpose:** Execution layer that enforces trading restrictions and closes positions when risk gates trigger.

**Key Features:**

**Latch Mechanism:**

- Once the risk gate is triggered, it remains **disabled for the rest of the trading day**
- Prevents re-enablement even if P&L recovers within limits
- Implemented via `RiskTriggered` flag that, once set to `True`, keeps `AccountTradingAllowed = False`

**Real-Time Check:**

- Evaluates risk status only on real-time bars: `If LastBarOnChart Then`
- Calls `AccountEquityStop_JP()` function to determine trading permission

**Kill Switch Execution:**
When trading is no longer allowed:

- Closes all long positions: `Sell ("AcctStop_LX") This Bar on Close`
- Closes all short positions: `BuyToCover ("AcctStop_SX") This Bar on Close`
- Executes on the same bar that triggers the limit breach

**Strategy Container:**
Any trading strategy can be placed inside:

```
If AccountTradingAllowed Then
Begin
    // Your strategy code here
End
```

The strategy only executes when risk gates permit.

**Parameters:**

- `MaxDailyLoss`: Dollar loss threshold (default: $5,000)
- `MaxDailyProfit`: Dollar profit threshold (default: $5,000)

### Component 3: AccountEquityAlert - Indicator

**Purpose:** Real-time alert system that notifies when daily P&L limits are breached.

**Operation:**

- Executes only on real-time bars: `If LastBarOnChart Then`
- Calculates daily P&L: `DailyNetPL = CurrentAccountEquity - BDAccountEquity`
- Evaluates limits: `WithinLimits = (DailyNetPL > -MaxDailyLoss) and (DailyNetPL < MaxDailyProfit)`
- Triggers alert immediately if limits are breached: `If not WithinLimits Then Alert`

**Visual Display:**

- **Plot 1:** Daily P&L with dynamic color coding
- **Plot 2:** Zero reference line
- **Plot 3:** Maximum daily loss limit (negative value)
- **Plot 4:** Maximum daily profit limit

**Color Coding:**

- **Red:** Daily P&L exceeds loss or profit limit (alert state)
- **Default:** P&L within safe limits

**Parameters:**

- `AccountNumber`: Account identifier (string, default: "")
- `MaxDailyLoss`: Loss threshold (default: $5,000)
- `MaxDailyProfit`: Profit threshold (default: $5,000)

**Note:** Real-time only; not useful for historical backtesting.

### Component 4: AccountEquityMonitor - Indicator

**Purpose:** Visual monitoring display showing current daily P&L and risk boundaries.

**Operation:**

- Calculates daily P&L on every bar: `DailyNetPL = CurrentAccountEquity - BDAccountEquity`
- Evaluates limits: `WithinLimits = (DailyNetPL > -MaxDailyLoss) and (DailyNetPL < MaxDailyProfit)`
- Continuously updates visual plots

**Visual Display:**

- **Plot 1:** Daily P&L line
- **Plot 2:** Maximum daily loss limit (negative value)
- **Plot 3:** Maximum daily profit limit

**Color Coding:**

- **Green:** Daily P&L within acceptable limits
- **Red:** Daily P&L violates loss or profit boundary

**Parameters:**

- `AccountNumber`: Account identifier (string, default: "")
- `MaxDailyLoss`: Loss threshold (default: $5,000)
- `MaxDailyProfit`: Profit threshold (default: $5,000)

**Use:** Continuous visual feedback during live trading sessions.

### System Behavior

**Normal Trading State:**

- Account opens; daily P&L starts at zero
- Monitor displays P&L within green bands [−MaxDailyLoss, +MaxDailyProfit]
- Risk Gate allows strategy execution and new trades

**Limit Breach:**

1. Daily P&L reaches or exceeds a limit
2. Alert Indicator triggers (audible/visual notification)
3. Kill Switch detects breach on next real-time bar
4. All open positions close immediately (`This Bar on Close`)
5. Latch mechanism engages: `RiskTriggered = True`
6. Monitor changes Plot 1 to red color

**Remainder of Day:**

- No new trades allowed (strategy container blocked)
- Latch prevents re-enablement even if P&L recovers
- Monitor remains red until end of session
- Alert remains active as reminder

**Next Trading Day:**

- Latch resets automatically
- Daily P&L calculation begins fresh
- Risk gate re-evaluates from new beginning equity

### Integration

All four components work together:

- **Function v2:** Calculates risk status
- **Kill Switch v2:** Uses function to enforce trading halt and close positions
- **Alert Indicator:** Uses same limit logic to notify before positions close
- **Monitor Indicator:** Uses same limit logic to visualize status continuously

### Parameters Summary

| Parameter      | Function v2 | Kill Switch v2   | Alert Indicator | Monitor Indicator |
| -------------- | ----------- | ---------------- | --------------- | ----------------- |
| MaxDailyLoss   | ✓           | ✓                | ✓               | ✓                 |
| MaxDailyProfit | ✓           | ✓                | ✓               | ✓                 |
| AccountID      | ✓           | via GetAccountID | AccountNumber   | AccountNumber     |

### Notes

### Parameters

- **MaxDailyLoss:** Maximum loss allowed per day before trading stops (default: $5,000)
- **MaxDailyProfit:** Maximum profit target per day before trading stops (default: $5,000)

### Operating Logic

**Example Workflow During a Trading Day:**

1. **Morning Open:** Account begins with $100,000 equity
   - Risk boundaries: [-$5,000, +$5,000]
   - Trading is enabled

2. **Mid-Morning:** Account reaches +$3,000 P&L
   - P&L is within limits [$-5K, +5K]
   - Trading continues

3. **Late Morning:** Account reaches +$5,200 P&L
   - P&L exceeds profit limit (+$5,000)
   - `AccountTradingAllowed` triggers to `False`
   - All open positions close `This Bar on Close`
   - Latch engages: `RiskTriggered = True`

4. **Noon to Close:** Account recovers to +$3,000 P&L
   - Despite being within limits now, latch keeps `AccountTradingAllowed = False`
   - No new trades allowed for the remainder of the day
   - Account is protected from over-trading

5. **Next Trading Day:** Latch resets
   - New daily P&L calculation begins
   - Risk gates re-evaluate fresh
   - Account risk meter resets

### Key Features

- **Account-Level Protection:** Not trade-level—controls entire account exposure
- **Bidirectional Limits:** Protects against both excessive losses AND excessive gains (profit cap)
- **Latch Guarantee:** Once triggered, the kill switch cannot be accidentally re-enabled during the same session
- **Immediate Execution:** Closes all positions on the same bar that triggered the limit (no delayed exit)
- **Single Source of Truth:** All risk logic centralized in `AccountRiskCore` function—indicators and strategy all reference the same calculation
- **Real-Time Evaluation:** Works on live bars only (`LastBarOnChart`), ensuring real equity values are used
- **Zero-Discretion Design:** The system is completely mechanical—no manual intervention required

### Risk Management Psychology

The strategy embodies a **"protect the portfolio, not the trade"** philosophy. Rather than protecting individual positions, it steps back and protects the entire account. The bidirectional limits (loss and profit caps) reflect a dual concern:

1. **Downside Protection:** Stop losses when the account is bleeding
2. **Upside Discipline:** Lock in profits when the day is extremely favorable

The profit cap is often overlooked but critical—it prevents greedy over-trading when markets are moving in your favor. The latch mechanism ensures that once triggered, the account isn't gradually whittled away by repeated small losses after hitting the limit.

### Bidirectional Limits Explained

| Scenario              | MaxDailyLoss | MaxDailyProfit | Status           | Action                  |
| --------------------- | ------------ | -------------- | ---------------- | ----------------------- |
| +$2,000 P&L           | $5,000       | $5,000         | Within limits    | Trading continues       |
| -$6,000 P&L           | $5,000       | $5,000         | Loss limit hit   | Kill switch activates   |
| +$5,200 P&L           | $5,000       | $5,000         | Profit limit hit | Kill switch activates   |
| +$4,500 P&L → +$3,000 | $5,000       | $5,000         | Was triggered    | Latch held; no recovery |

### Integration with Any Strategy

The system is designed as a wrapper, allowing any strategy to be protected:

```easylanguage
If AccountTradingAllowed Then
Begin
    // Your strategy code here
    // EMA crosses, mean reversion, breakouts, etc.
    // This code only executes when risk gates allow
End;
```

This separation of concerns ensures risk management is independent of entry/exit logic.

### Use Cases

- **Proprietary Trading:** Firms managing multiple accounts with strict daily risk limits
- **Risk-Averse Traders:** Individuals wanting automatic profit-taking after strong days
- **Highly Volatile Markets:** Protection during earnings, economic releases, or gap events
- **Account Blowout Prevention:** Dramatic reduction in catastrophic loss scenarios
- **Discipline Enforcement:** Maintains position size and risk limits despite emotional trading urges
- **Multi-Strategy Portfolios:** Protects entire account when running multiple entry systems

### Execution Notes

- **Real-Time Only:** The system requires real-time bar data; it uses `LastBarOnChart` and real equity functions
- **Account ID:** Requires correct `GetAccountID` to pull the right account's equity
- **Intraday Horizon:** Resets daily; designed for daily trading limits, not multi-day positions
- **Broker Connectivity:** Relies on real-time account equity updates from the broker
- **Order Execution:** Final exit uses `This Bar on Close` to ensure market participation at close

### Historical Note

The system evolved through versions:

- **v1:** Basic risk gate mechanism
- **v2:** Added latch mechanism to prevent re-enablement after triggering, ensuring hard stops

The refactoring to `AccountRiskCore` function was driven by the need to **eliminate duplicate logic** across the strategy, monitors, and alerts. Now all four components use a single function, creating a "single source of truth" for risk evaluation.

### Notes
