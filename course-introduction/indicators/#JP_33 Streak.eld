{Este indicador muestra la racha actual de barras hacia arriba o hacia abajo; en otras palabras, el número actual de barras 
consecutivas hacia arriba o hacia abajo. Está pensado para usar en RadarScreen.
}

Input:
	Price(Close),
	UpColor(green),
	DownColor(red),
	UpColor1(black),
	DownColor1(white);

Vars:
	UpCount(0),
	DownCount(0);

If Price > Price[1] or (UpCount > 0 and Price=Price[1]) Then
	UpCount = UpCount +1
Else
	UpCount = 0;
If Price < Price[1] or (DownCount < 0 and Price=Price[1]) Then
	DownCount = DownCount -1
Else
	DownCount = 0;

If UpCount > 0 Then
Begin
	Plot1(UpCount, "Streak");
	SetPlotColor(1, UpColor1);
	SetPlotBGColor(1, UpColor);
End Else
Begin
	Plot1(DownCount, "Streak");
	SetPlotColor(1, DownColor1);
	SetPlotBGColor(1, DownColor);
End;

{💡 Importante:
		UpCount siempre será positivo
		DownCount siempre será negativo
	Esto es intencional y muy elegante desde el punto de vista visual.
	
	Caso 1️: Price > Price[1]
		El precio sube respecto a la barra anterior
		👉 la racha alcista continúa → UpCount + 1
	Caso 2: Price = Price[1] pero ya había racha
		El precio no sube ni baja
		Pero no rompe la racha alcista
		👉 se sigue contando como racha
	Caso contrario:
		El precio baja
		👉 la racha alcista se rompe → UpCount = 0
	UpCount mide cuántas barras consecutivas no bajistas llevamos, 
	siempre que la racha haya empezado con subida. DownCount es simétrico en 
	sentido bajista
	
	Este indicador nos dice en una sola celda:
	“¿Cuántas barras seguidas lleva subiendo o bajando este activo?”
	Ideal para ver fuerza o agotamiento del movimiento
	Basado en estructura de precios, no en indicadores clásicos
}