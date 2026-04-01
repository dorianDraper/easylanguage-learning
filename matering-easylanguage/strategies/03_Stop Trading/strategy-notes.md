## Strategy Description

The **Account Equity Risk Gate with Kill Switch** is a sophisticated account-level risk management system that automatically halts all trading activity when daily profit or loss limits are exceeded. Rather than protecting individual positions, this system protects the entire account by enforcing strict daily P&L boundaries. It acts as a programmable circuit breaker that triggers when market volatility or adverse trading results threaten the account.

### Core Architecture

The system consists of four integrated components that work together to create a unified risk management framework:

**1. AccountRiskCore Function (Single Source of Truth)**

This centralized function eliminates logic duplication by consolidating all risk evaluation into one reusable component:

- **Input Retrieval:** Fetches the account's beginning-of-day equity using `GetBDAccountNetWorth(AccountID)`
- **Real-Time Tracking:** Retrieves current account equity using `GetRTAccountNetWorth(AccountID)`
- **Daily P&L Calculation:** Computes `DailyNetPL = CurrentEquity - BeginDayEquity`
- **Limit Evaluation:** Checks if daily P&L falls within acceptable bounds:
  - `DailyNetPL > -MaxDailyLoss` (loss limit not breached)
  - `DailyNetPL < MaxDailyProfit` (profit limit not breached)
- **Permission Return:** Returns `True` if both conditions are met (trading allowed) or `False` if either limit is violated

**2. Account Equity Risk Gate with Kill Switch v2 (Strategy Wrapper)**

This is the execution layer that implements the kill switch mechanism:

- **Latch Mechanism:** Once the risk gate is triggered, it remains disabled for the rest of the trading day, preventing re-entry even if P&L recovers within limits
- **Position Closure:** When triggered, all open positions are immediately closed:
  - Long positions: Sell at market `This Bar on Close`
  - Short positions: Buy to cover at market `This Bar on Close`
- **Real-Time Check:** Evaluates `AccountTradingAllowed` on each real-time bar using `If LastBarOnChart`
- **Safe Strategy Wrapper:** Any trading strategy can be placed inside the `If AccountTradingAllowed Then Begin... End;` block, ensuring the strategy only executes when risk gates are not breached

**3. AccountEquityMonitor Indicator (Visual Display)**

A real-time visualization tool that displays:

- Current daily P&L
- Maximum daily loss limit
- Maximum daily profit limit
- Visual indicators showing proximity to limits

Used for monitoring during live trading sessions.

**4. AccountEquityAlert Indicator (Immediate Notification)**

A real-time alert system that:

- Detects the exact moment daily limits are violated
- Generates an immediate alert (visual, audible, or email)
- Works only on real-time bars (`LastBarOnChart`)
- Provides immediate warning before the kill switch executes

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
