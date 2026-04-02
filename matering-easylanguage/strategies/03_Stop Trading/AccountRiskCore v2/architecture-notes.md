## Account Equity Risk Gate Architecture

### System Overview

The **Account Equity Risk Gate** is an integrated, multi-layer account risk management system comprising four cohesive components that work in concert to protect account equity through real-time monitoring, automated alerts, visual feedback, and mechanical trade execution. The system follows a clean separation of concerns: a single function performs all risk calculations, two indicators provide monitoring and alerts, and a strategy wrapper enforces the kill switch.

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│         Account Equity Risk Gate System Architecture        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  AccountRiskCore Function (Single Source of Truth)   │   │
│  │  ├─ Retrieves begin-of-day equity                    │   │
│  │  ├─ Retrieves real-time equity                       │   │
│  │  ├─ Calculates daily P&L                             │   │
│  │  ├─ Evaluates limits                                 │   │
│  │  └─ Returns trading permission (T/F)                 │   │
│  └──────────────────────────────────────────────────────┘   │
│                         ▲                                   │
│                         │ (uses)                            │
│                         │                                   │
│        ┌────────────────┼────────────────┐                  │
│        ▼                ▼                ▼                  │
│  ┌─────────────┐  ┌────────────┐  ┌─────────────┐           │
│  │   Kill      │  │  Monitor   │  │   Alert     │           │
│  │  Strategy   │  │ Indicator  │  │ Indicator   │           │
│  │             │  │            │  │             │           │
│  │ Executes    │  │ Visualizes │  │ Notifies    │           │
│  │ kill switch │  │ status     │  │ on breach   │           │
│  │ and closes  │  │ and limits │  │             │           │
│  │ positions   │  │            │  │             │           │
│  └─────────────┘  └────────────┘  └─────────────┘           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Component 1: AccountRiskCore Function

**Purpose:** Centralized engine for all risk calculations. Single source of truth.

**Inputs:**

- `MaxDailyLoss`: Dollar threshold for maximum daily loss (default: $5,000)
- `MaxDailyProfit`: Dollar threshold for maximum daily profit (default: $5,000)
- `AccountNumber`: Account identifier for equity retrieval (string)

**Processing:**

1. Retrieves beginning-of-day account equity: `GetBDAccountNetWorth(AccountNumber)`
2. Retrieves real-time account equity: `GetRTAccountNetWorth(AccountNumber)`
3. Calculates daily P&L: `DailyNetPL = CurrentEquity - BeginDayEquity`
4. Evaluates trading permission:
   - Trading allowed if: `DailyNetPL > -MaxDailyLoss` AND `DailyNetPL < MaxDailyProfit`
   - Trading blocked if either limit is violated

**Output References (passed by reference):**

- `oDailyNetPL`: The current daily profit/loss amount
- `oWithinLimits`: Boolean flag indicating if P&L is within acceptable bounds

**Return Value:**

- `True`: Trading is permitted
- `False`: Trading is blocked (limit breached)

**Why This Design?**

- Single function eliminates duplicate risk logic across multiple components
- All four components (strategy, alert, monitor) call the same function
- Ensures consistency—every component evaluates risk identically
- Easy maintenance—change limits once, affects all components instantly

### Component 2: Account Equity Risk Gate with Kill Switch Strategy

**Purpose:** Execution layer that enforces account-level risk controls and closes positions.

**Architecture:**
The strategy acts as a wrapper that can contain any trading logic (entries, exits, position management).

**Execution Flow:**

1. **Real-Time Evaluation** (executes on real-time bars only):

   ```
   If LastBarOnChart Then
       AccountTradingAllowed = AccountRiskCore(...)
   ```

   On each real-time bar, checks current risk status.

2. **Latch Mechanism** (prevents re-enablement):

   ```
   If not AccountTradingAllowed Then
       RiskTriggered = True

   If RiskTriggered Then
       AccountTradingAllowed = False
   ```

   Once triggered, the kill switch remains disabled for the rest of the day.

3. **Kill Switch Execution** (closes all positions):

   ```
   If not AccountTradingAllowed Then
       If IsLong Then Sell ("AcctStop_LX") This Bar on Close
       If IsShort Then BuyToCover ("AcctStop_SX") This Bar on Close
   ```

   Immediately closes all open positions when limits are breached.

4. **Strategy Container** (protected execution space):
   ```
   If AccountTradingAllowed Then
   Begin
       // Your trading strategy code here
       // Entry logic, position sizing, etc.
   End
   ```
   Any trading strategy placed here only executes when risk gates permit.

**Key Behaviors:**

- **Immediate Action:** Closes positions on the same bar that triggers the limit (no delays)
- **One-Way Gate:** Once breached, doesn't allow further entries until next trading day
- **Position Closure:** Exits both long and short positions regardless of profitability
- **Protective Defaults:** Designed to preserve capital rather than maximize profits

### Component 3: AccountEquityMonitor Indicator

**Purpose:** Real-time visual display of daily P&L and account risk status.

**Displays:**

- **Plot 1 (Primary):** Daily net P&L (the account profit/loss)
  - Color changes: Green if within limits, Red if limits breached
- **Plot 2:** Zero line (reference)
- **Plot 3:** Maximum daily loss limit (displayed as negative value)
- **Plot 4:** Maximum daily profit limit

**Visual Representation:**
When P&L moves toward either limit, traders can visually observe:

- Safe zone: P&L between -$5,000 and +$5,000 (green)
- Breached zone: P&L exceeds either limit (red)
- Trend: Rising/falling P&L approaching limits

**Use Case:**

- Live trading window that shows real-time account status
- Allows traders to see proximity to kill switch triggers
- No automation—purely informational display

**Real-Time Requirement:**
Works only on `LastBarOnChart` (real-time bars); useless for backtesting.

### Component 4: AccountEquityAlert Indicator

**Purpose:** Real-time notification system that alerts before the kill switch fully executes.

**Behavior:**

```
If LastBarOnChart Then
    TradingAllowed = AccountRiskCore(...)
    If not TradingAllowed Then
        Alert
```

**Alert Triggers:**

- Fires the exact moment a daily P&L limit is breached
- Can be configured as:
  - Visual pop-up alert
  - Audible bell/sound
  - Email notification
  - Message on chart

**Timing:**

- Alerts on the same bar that would trigger the kill switch
- Provides immediate feedback before positions are forcefully closed
- Real-time only (no alerts in historical backtests)

**Dual-Purpose:**

1. **Awareness:** Trader knows immediately when the limit is breached
2. **Learning:** Helps traders understand which strategies/times cause rapid drawdowns

### Data Flow and Sequencing

**During a Trading Bar:**

1. **Calculation Phase:**
   - AccountRiskCore function runs (gets equity, calculates P&L, evaluates limits)
   - Result: `TradingAllowed` boolean and `DailyNetPL` value

2. **Parallel Responses:**
   - **Monitor Indicator:** Plots the daily P&L and changes color if breached
   - **Alert Indicator:** Triggers alert if limit is breached
   - **Kill Switch Strategy:** Closes positions if limit is breached; blocks new entries

3. **Protected Execution:**
   - Any trading strategy inside the strategy wrapper only executes if `AccountTradingAllowed = True`
   - If false, no new entries; existing positions close

### Information Flow Across Components

| Event                                   | Trigger         | Monitor     | Alert       | Kill Strategy     |
| --------------------------------------- | --------------- | ----------- | ----------- | ----------------- |
| P&L +$2,000 (within)                    | AccountRiskCore | Green       | ---         | Continues trading |
| P&L +$5,200 (exceeds)                   | Limit breach    | Red         | Alert fires | Closes positions  |
| P&L recovers to +$4,000 (still latched) | Latch remains   | Stays red   | ---         | Still stopped     |
| Next day opens                          | Daily reset     | Green again | ---         | Can trade again   |

### Design Principles

**1. Single Source of Truth**

- All four components call the same `AccountRiskCore` function
- No duplicate risk logic across codebase
- Changes to risk limits propagate automatically to all components

**2. Separation of Concerns**

- **Function:** Calculations only
- **Strategy:** Execution and position management only
- **Indicators:** Monitoring and alerting only
- Each component has one job; none duplicates responsibility

**3. Real-Time Architecture**

- Uses `LastBarOnChart` to distinguish live bars from historical
- Retrieves real account equity via platform APIs
- Enables accurate, live position control

**4. Mechanical Enforcement**

- No discretion once limits are set
- Latch mechanism prevents circumvention
- Immediate position closure without negotiation

**5. Layered Protection**

- Function layer: Risk calculation truth
- Indicator layers: Early warning system
- Strategy layer: Mechanical enforcement

### Integration Points

**How to Use This System:**

1. **Set Account Parameters:**

   ```
   MaxDailyLoss = 5000    (lose $5K, system stops)
   MaxDailyProfit = 5000  (win $5K, system stops)
   AccountNumber = "ABC123" (your trading account)
   ```

2. **Attach Monitor to Chart:**
   - Shows daily P&L constantly
   - Visual indication of proximity to limits

3. **Attach Alert to Chart:**
   - Get notified immediately when limits breach
   - Understand what market conditions caused the breach

4. **Use Kill Strategy as Wrapper:**
   - Place your trading strategy inside the `If AccountTradingAllowed` block
   - Strategy only enters when risk gates permit
   - Positions automatically close when limits hit

### System Advantages

- **Account Protection:** Hard stop on losses/gains, not just position stops
- **Discipline:** Enforces risk rules mechanically, eliminating emotional override
- **Transparency:** Visual display + alerts keep trader aware constantly
- **Consistency:** All components use identical risk logic
- **Simplicity:** Four components; each does one thing well
- **Flexibility:** Works with any trading strategy (as long as placed in wrapper)
- **Scalability:** Manages multiple accounts by changing `AccountNumber` parameter

### Common Use Cases

| Scenario           | Configuration           | Benefit                              |
| ------------------ | ----------------------- | ------------------------------------ |
| Risk-averse trader | $3K loss / $3K profit   | Tight daily limits protect capital   |
| Volatility trading | $10K loss / $15K profit | Asymmetric limits match volatility   |
| Profit protection  | Small loss / $5K profit | Lock in wins once $5K target reached |
| Account recovery   | $1K loss / $2K profit   | Close small, reduce exposure         |
| Prop firm rules    | $2K loss / $ ∞ profit   | Match firm requirements exactly      |

### Notes
