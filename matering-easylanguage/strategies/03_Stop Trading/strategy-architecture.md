## Notes
This strategy has different components
1. Base Strategy ***Stop Trading***:  Controls whether trading is allowed based on daily account P&L. Acts as a wrapper around any strategy.
2. Function ***AccountEquityStop_JP***: Evaluates whether daily account P&L is within allowed limits.
3. Indicator ***AccountEquityAlert***: Detects in real time when daily limits are violated and **generates an immediate alert**. Not for backtesting (it uses *LastBarOnChart*).
4. Indicator ***AccountEquityMonitor***: Visualizes daily P&L status and limits. It uses *LastBarOnChart*.

## Components Relationship
👉 AccountEquityStop_JP (function)</br>
👉 Stop Trading strategy (Risk Gate / Kill Switch)</br>
👉 Indicatorss (Monitor + Alert)