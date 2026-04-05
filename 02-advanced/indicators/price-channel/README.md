# Donchian-Style Breakout Indicator v2

🇺🇸 English | 🇪🇸 [Español](README.es.md)

## Overview
This indicator identifies **price breakouts from a historical range** using a Donchian-style channel. It calculates the highest high and lowest low over a specified lookback period (excluding the current bar) and signals when price breaks above or below these levels.

The indicator is designed for both **Chart** and **RadarScreen** environments, adapting its visual feedback and alerts accordingly.

---

## How It Works

- **Upper Band** → Highest high over the last *N* bars (excluding current bar)  
- **Lower Band** → Lowest low over the last *N* bars (excluding current bar)

Breakout conditions:
- **Bullish breakout** → Price crosses above the upper band  
- **Bearish breakout** → Price crosses below the lower band  

Key implementation details:
- Uses `[1]` offset to avoid look-ahead bias  
- Supports plot displacement (`Displace`) for visual analysis  
- Provides **real-time alerts** only when not projecting into the future  
- Adapts visualization:
  - **Charts** → line highlighting (color + width)
  - **RadarScreen** → cell coloring (background + text)

---

## Key Features

- Donchian channel breakout detection  
- Real-time alerting on breakout events  
- Environment-aware visualization (Chart vs RadarScreen)  
- Safe handling of displaced plots  
- Clean separation of calculation, visualization, and alert logic  

---

## Use Cases in Trading Strategies

This indicator can be used as a core building block in multiple strategy types:

### 1. Trend Following (Breakout Systems)
- Enter long on upper breakout  
- Enter short on lower breakout  
- Example: Turtle Trading-style systems  

### 2. Volatility Expansion Strategies
- Use breakouts as signals of increasing volatility  
- Combine with ATR or volume filters  

### 3. Mean Reversion (with Filters)
- Detect extremes and wait for **failed breakout / re-entry into channel**  
- Combine with RSI or z-score for confirmation  

### 4. Intraday Range Breakout
- Apply to session-based ranges  
- Useful in opening range breakout systems  

### 5. Market Scanning (RadarScreen)
- Identify instruments breaking key levels across a watchlist  
- Use color-coded alerts for rapid decision-making  

---

## Notes

- Breakouts alone do not imply direction persistence; consider combining with:
  - Trend filters (e.g., moving averages)
  - Volatility filters (e.g., ATR)
  - Momentum indicators  

- Particularly effective in **trend-following contexts**, but requires confirmation logic for mean reversion systems.

---