## First Hour Channel - Indicator

### Description

Displays the opening hour's high and low as fixed horizontal reference lines during the trading session. The indicator captures the highest and lowest prices during the first 60 minutes (default), then plots these levels from the end of the first hour until a specified stop time (default: 3:00 PM). Used to identify opening range breakouts and support/resistance boundaries throughout the day.

### Mechanics

1. **First Hour Capture** (0:00 - 1:00): Records the daily high and low during the opening period
2. **Channel Display** (1:00 - 3:00): Plots captured levels as horizontal lines with color coding
3. **Auto-Hide**: Stops plotting after stop time to reduce chart clutter

### Parameters

- **FirstHourMinutes**: Duration of opening period (default: 60 minutes)
- **StopPlotTime**: Time when indicator stops plotting (default: 1500 / 3:00 PM)
- **HighColor**: Color for first hour high line (default: Blue)
- **LowColor**: Color for first hour low line (default: Red)

### Use Cases

- Intraday traders identifying opening range support/resistance
- Breakout traders detecting when price escapes the opening range
- Range-bound traders monitoring consolidation boundaries

### Notes
