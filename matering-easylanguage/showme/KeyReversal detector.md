## KeyReversal Detector - ShowMe Indicator

### Overview

The **KeyReversal Detector** is a visual indicator that identifies classic key reversal patterns on a chart. It detects when price makes a structural low followed by a bullish close, which often signals the beginning of a bounce or reversal. The indicator plots three distinct levels of confirmation, allowing traders to see both the pattern development and completion.

### Core Mechanics

**Structural Low Detection:**
The indicator scans for the most recent bar that has made a new lowest low relative to the previous n bars (default: 21-bar Donchian channel). This structural low represents a significant support test.

**Reference Close Capture:**
Once a structural low is identified, the indicator records the close of that bar as the `ReferenceClose`. This becomes the anchor point for measuring bullish confirmation.

**Bullish Close Confirmation:**
The indicator then checks if the next bars close above the reference close (with allowance for a tolerance factor). If the current close exceeds:

- `ReferenceClose × (1 - ConfirmationTolerancePct * 0.01)`

Then a bullish close is confirmed, signaling rejection of the structural low.

### Parameters

- **DonchianLen:** Lookback period for identifying structural lows (default: 21 bars). Bars that break below the lowest low of this period qualify as structural lows.
- **CarryForwardBars:** Number of bars after the structural low to continue considering it valid (default: 0). Allows flexibility in how recent the structural low must be.
- **ConfirmationTolerancePct:** Percentage tolerance for the bullish close confirmation (default: 0%). Allows slight slippage or gap adjustments. For example, 5% tolerance means the close only needs to be 95% of the way back to the reference close.

### Visual Outputs (Plots)

The indicator produces three distinct plot levels, each representing a stage of pattern confirmation:

**Plot 1: Structural Low (HasStructuralLow)**

- Displayed at one-third down from the bar low
- Shows when a structural low has been identified
- Appears when a new lower low is formed relative to the lookback period
- Color: Indicates potential support test

**Plot 2: Bullish Close (HasBullishClose)**

- Displayed at two-thirds down from the bar low
- Shows when bullish confirmation has occurred
- Appears when close reverses above the reference close (with tolerance)
- Color: Marks the reversal rejection signal

**Plot 3: Complete KeyReversal (HasStructuralLow AND HasBullishClose)**

- Displayed at 99% down from the bar low (near the actual low)
- Shows only when BOTH conditions are met simultaneously
- Appears when a structural low is coupled with immediate bullish confirmation
- Color: Marks the complete, confirmed key reversal pattern

### Trade Interpretation

**Single Structural Low Alert:**
When only Plot 1 appears, the market has reached a new low. This is a potential support test, but no reversal signal yet. Price must confirm with a bullish close.

**Structural Low + Bullish Close:**
When Plots 1 and 2 both appear, the market has rejected the structural low with a bullish close. This is a key reversal signal—the market tested support and immediately bounced, indicating conviction.

**Complete KeyReversal Signal:**
When Plot 3 appears (both conditions on same bar or consecutively), a high-confidence key reversal has formed. This pattern often precedes bounce trades or mean-reversion entries.

### Practical Usage

**Standalone Detection:**
Use this indicator on any intraday or daily chart to identify key reversal formations automatically. No need to manually scan for the pattern.

**Entry Confirmation:**
Combine with existing trading strategies. When the KeyReversal detector shows all three plots, it confirms the pattern exists on the chart, validating pattern-based entries.

**Support Testing:**
Track when structural lows form to understand where buyers are stepping in. The bullish close confirmation shows conviction at those support levels.

**Volatility Gauge:**
In choppy markets, structural lows (Plot 1) appear frequently but without bullish confirmation (Plot 3 rarely shows). In cleaner uptrends, KeyReversal signals cluster near support zones.

### Code Logic Summary

```
1. Calculate structural low: MRO(Low < Lowest(Low, DonchianLen)[1], ...)
2. If structural low exists, capture reference close from that bar
3. Check if current close > ReferenceClose * (1 - tolerance)
4. Plot all three confirmation levels
5. Reset on each bar
```

### Key Features

- **Real-Time Detection**: Updates on every bar to show pattern development
- **Multi-Stage Confirmation**: Three separate plots show pattern progression
- **Flexible Parameters**: Adjust Donchian length and tolerance to match market characteristics
- **No Repainting**: Uses historical reference points; once detected, pattern remains on chart
- **Clean Visual**: Three distinct plot levels make reversal patterns immediately visible

### Use Cases

- Intraday scalpers seeking bounce patterns
- Mean reversion traders confirming support reversals
- Swing traders identifying key support zones
- Traders combining technical pattern recognition with mechanical signals
- Trading system developers needing pattern detection for entry logic

### Notes
