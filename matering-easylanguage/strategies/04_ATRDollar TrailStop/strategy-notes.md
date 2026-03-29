## Strategy Description

The **ATRDollar TrailStop** strategy implements a dynamic trailing stop mechanism based on Average True Range (ATR) volatility, allowing the stop loss to adapt automatically to market conditions. Unlike fixed-dollar or fixed-point stops, this approach scales with the instrument's volatility, making it applicable across different symbols and timeframes.

### Core Mechanics

**Initial Protection:** When a trade is entered, an immediate stop loss is set at 1 ATR (by default), providing initial downside protection before any trailing mechanism activates.

**Floor Activation:** The trailing stop doesn't activate immediately. Instead, it waits until the trade has advanced by a floor amount (2 ATR by default). This prevents premature stop activation due to minor pullbacks and allows the position to establish a profitable cushion before the trailing logic engages.

**Dynamic Trailing:** Once the floor is reached, the trailing stop becomes active and follows the high/low of the price action at a distance of 1 ATR (by default). As volatility changes, the ATR recalculates dynamically, automatically adjusting the stop distance to remain relevant to current market conditions.

**Dollar-Based Scaling:** The strategy converts ATR values (measured in points) to dollar amounts using `BigPointValue`, ensuring that the risk is consistent across different instruments. For example, an ES contract with a 1.25-point ATR and BigPointValue of 50 translates to a $62.50 risk unit.

### Parameters

- **ATRTrail:** Multiplier for the dynamic trailing stop distance (default: 1x ATR)
- **ATRFloor:** Multiplier for the floor activation level (default: 2x ATR)
- **ATRStopLoss:** Multiplier for initial stop loss protection (default: 1x ATR)
- **ATRLen:** Period for ATR calculation (default: 9 bars)

### Notes
