## Notes
This strategy has different components
1. Base Strategy 'Stop Trading'
2. Function 'AccountEquityStop_JP'
3. Indicator 'AccountEquityAlert'
4. Indicator 'AccountEquityMonitor'
   
### Base Strategy 'Stop Trading'
 Controls whether trading is allowed based on daily account P&L. Acts as a wrapper around any strategy.

### Function 'AccountEquityStop_JP'
Evaluates whether daily account P&L is within allowed limits.

### Indicator 'AccountEquityAlert'
Detects in real time when daily limits are violated and **generates an immediate alert**. Not for backtesting (it uses *LastBarOnChart*)

### Indicator 'AccountEquityMonitor'
Visualizes daily P&L status and limits. It uses *LastBarOnChart*.

## Components Relationship
👉 AccountEquityStop_JP (function)
👉 Stop Trading strategy (Risk Gate / Kill Switch)
👉 Indicatorss (Monitor + Alert)