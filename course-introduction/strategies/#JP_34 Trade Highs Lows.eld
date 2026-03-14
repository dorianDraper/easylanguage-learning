{Esta estrategia introduce una orden limitada para comprar siguiendo el número de nuevos Lows consecutivos, según se ha determinado 
con el input LowsToBuy. La estrategia introduce una orden limitada para vender al descubierto siguiendo el número de nuevos Highs consecutivos 
según se ha	determinado con el input HighsToSell. El precio límite se establece para el	Close de la barra señal, -/+ el número de puntos 
establecido en el input LimitPoints. Las órdenes de beneficio y de stop de pérdidas se usan en base a la posición con los valores de los inputs ProfTgt y StopLoss, respectivamente.
}

Input:
	LowsToBuy(2),
	HighsToSell(2),
	LimitPoints(.02),
	ProfTgt(50),
	StopLoss(50);

Vars:
	LowsCount(0),
	HighsCount(0);

If High > High[1] Then
	HighsCount = HighsCount + 1
Else
	HighsCount = 0;

If Low < Low[1] Then
	LowsCount = LowsCount + 1
Else
	LowsCount = 0;
	
{Setup de entrada}
If LowsCount >= LowsToBuy Then
	Buy Next Bar at Close of This Bar - LimitPoints Limit;
	
If HighsCount >= HighsToSell Then
	SellShort Next Bar at Close of This Bar + LimitPoints Limit;

{Setup de salida}
SetStopPosition;
SetProfitTarget(ProfTgt);
SetStopLoss(StopLoss);