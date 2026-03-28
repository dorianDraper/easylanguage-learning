## Notes
The default name of the strategy in the course is 'EquityCurve TradeSize'. This name is used to ilustrate the concept of position sizing. An appropiate name would be:
```
Donchian Mean Reversion Strategy with Adaptive Position Sizing
``` 

## Description
Contrarian strategy that trades reversions after price reaches extremes defined by a Donchian channel.

Position size dynamically adjusts based on strategy performance (NetProfit), increasing exposure during profitable periods and reducing risk during drawdowns.