## Strategy Description

The **Equity-Adaptive Position Sizing Donchian Mean Reversion** is a sophisticated mean-reversion system that combines two powerful concepts: Donchian channel extremes for entry signals and dynamic position sizing that scales with account profitability. Rather than trading fixed share quantities, the strategy automatically adjusts position size based on cumulative profit, allowing winners to compound while protecting losers.

### Core Mechanics

**Donchian Channel Detection:** The strategy uses a 21-period Donchian channel—the highest high and lowest low over the last 21 bars—to identify price extremes. The theory is that when price breaks beyond these extremes, it has overextended and is likely to revert.

**Mean Reversion Signals:**

- **Long Signal:** Price breaks below the Donchian low (lower extreme reached)
- **Short Signal:** Price breaks above the Donchian high (upper extreme reached)

When triggered, the strategy enters at market on the next bar at whatever position size the equity-adjustment formula has calculated.

**Equity-Adaptive Position Sizing:** This is the strategy's most innovative feature. Position size is not fixed; instead, it adjusts based on accumulated profit or loss:

1. **Calculate Net Profit:** `NetProfit` from the strategy's trading results
2. **Check Profitability Threshold:** If cumulative profit exceeds one risk unit (default: $500), the strategy grows
3. **Scale Size Up on Gains:** For every $500 in cumulative profit, add one position step (default: 100 shares)
   - Formula: `TradeSizeAdjust = (NetProfit / RiskUnit) × SizeStep`
4. **Enforce Limits:** Ensure position size never exceeds maximum (default: 2,000 shares) or falls below minimum (default: 100 shares)

**Example Sizing Progression:**

- Starting: 1,000 shares base
- After +$500 profit: 1,100 shares (base 1,000 + one step of 100)
- After +$1,000 profit: 1,200 shares (base 1,000 + two steps of 100)
- After +$2,000 profit: 1,400 shares (base 1,000 + four steps of 100)
- Maximum enforced cap: 2,000 shares
- Loss phase: Back to 1,000 base (no scaling while losing)

**Risk Management:** All positions use fixed risk units:

- **Stop Loss:** Always $500 (the RiskUnit), protecting the account from large swings
- **Profit Target:** Always $500 (the RiskUnit), capturing mean reversion gains systematically

Due to the variable position sizes, the percentage return varies while the dollar amount remains consistent.

### Parameters

- **BaseTradeSize:** Foundation position size (default: 1,000 shares)
- **SizeStep:** Share increment added per completed risk unit of profit (default: 100 shares)
- **MaxTradeSize:** Absolute maximum position size during winning periods (default: 2,000 shares)
- **MinTradeSize:** Absolute minimum position size floor (default: 100 shares)
- **RiskUnit:** Dollar amount defining profitability threshold and position management (default: $500)
- **DonchianLength:** Lookback period for channel calculation (default: 21 bars)

### Trade Scenarios

**Scenario 1: Scaling Up During Winning Streak**

- Initial account equity: $10,000
- Trade 1: Enters 1,000 shares on Donchian low
- Profit target of $500 hits; position size: 1,000 shares
- Account equity: $10,500
- Trade 2: Enters 1,100 shares (base + 100 for one full profit unit)
- Profit target hits again; position size: 1,100 shares
- Account equity: $11,100 (10,500 + 600 from second trade due to larger size)
- Trade 3: Enters 1,200 shares (base + 200 for two full profit units)
- Momentum continues; larger position captures bigger gains

**Scenario 2: Scaling Back Down During Drawdown**

- Account has accumulated +$2,000 profit; position size at 1,400 shares
- Market reverses; stop loss hits on several trades
- Cumulative equity drops from $12,000 back to $10,800 (loss of $1,200)
- NetProfit drops below multiple risk units; position size shrinks back to base 1,000 shares
- Smaller sizes reduce exposure during the drawdown

**Scenario 3: Protection During Loss Phase**

- Account underwater: -$200 cumulative
- Position size stays at minimal (100 shares, the floor)
- Cannot scale down further; minimum size prevents over-sizing risks
- Stop loss on each trade still loses $500 in dollars, but only 100 shares traded

### Key Features

- **Profit-Scaling Elegance:** Larger positions during winning periods compound gains; smaller positions during losses limit damage
- **Consistent Risk Dollars:** Every position risks the same dollar amount ($500), even as share quantities vary
- **Donchian Simplicity:** Two-line entry rule—price breaks channel extremes—is easy to understand and trade
- **Anti-Heroic Design:** The strategy cannot oversize during losses (minimum floor enforced) and cannot pyramid without profit
- **Self-Limiting:** The maximum cap (2,000 shares) prevents runaway position sizing even during long winning streaks
- **Automatic Reset:** When equity drops, scaling reverses automatically without intervention
- **State Clarity:** Clear calculation of adapting size based on visible NetProfit metric

### Trade Psychology

The strategy embodies a "Let winners run with bigger size" philosophy. Account profitability directly funds position growth—not borrowed margin or arbitrary multipliers. This creates a natural feedback loop: success breeds larger positions, failures breed smaller positions. The strategy cannot lie about itself because the position size is always reflected in current equity.

### Comparison to Fixed Sizing

| Aspect                | Fixed Position Sizing        | Equity-Adaptive                  |
| --------------------- | ---------------------------- | -------------------------------- |
| Position per trade    | Always 1,000 shares          | Scales 100-2,000 based on profit |
| Risk per trade        | Variable (share loss × $500) | Always $500                      |
| Profit per trade      | Variable                     | Always $500 (but different %)    |
| Scaling during losses | None                         | Protected with minimum floor     |
| Scaling during wins   | None                         | Grows systematically             |
| Compounding effect    | No                           | Yes                              |
| Drawdown behavior     | Consistent                   | Adapts lower                     |

### Use Cases

- Traders wanting systematic profit reinvestment without discretion
- Mean reversion strategies on elastic markets (indices, currencies)
- Account protection—automatic downsizing during difficult periods
- Compounding systems where winning trades fund larger future trades
- Mechanical traders seeking rules-based position sizing
- Risk management automation reducing emotional sizing decisions

### Execution Notes

- **Daily Profit Tracking:** The strategy calculates `NetProfit` across all trades; ensure the trading platform supports accurate cumulative metrics
- **Donchian on Intraday:** The 21-bar Donchian adapts to timeframe; on 1-minute charts it's 21 minutes, on hourly charts it's 21 hours
- **Slippage Impact:** Mean reversion on tight stops ($500 per share) requires liquid markets to avoid excessive slippage
- **Equity Curve Dependency:** Position sizing depends on real-time equity; each trade affects the next trade's size

### Notes
