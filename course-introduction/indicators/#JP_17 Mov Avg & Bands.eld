{	Este indicador traza 3 líneas:
	- Una media móvil
	- La misma media móvil más una desviación standard de precio
	- La misma media móvil menos una desviación standard precio
}

Input:
	Price(Close),
	Length(18);	

Vars:
	MovAvg(0),
	HiBand(0),
	LoBand(0),
	StDv(0);

MovAvg = Average(Price, Length);
StDv = StdDev(Price, Length);
HiBand = MovAvg + StDv;
LoBand = MovAvg - StDv;
	
Plot1(MovAvg, "Avg");
Plot2(HiBand, "HighBand");
Plot3(LoBand, "LowBand");

If Close Crosses Over HiBand Then
	Alert("Close has crossed over HiBand" + Description);

If Close Crosses Under LoBand Then
	Alert("Close has crossed under LoBand" + Description);

{	🧠 Este indicador: 
        - Calcula una media móvil
        - Mide la volatilidad con desviación estándar std
        - Crea un canal dinámico que detecta cuando el precio:
            > rompe por arriba (expansión alcista)
            > rompe por abajo (expansión bajista)
        - Lanza alertas para esos eventos

	🧩 Es un indicador de volatilidad + momentum, muy usado como base para:
		>breakout systems
		>filtros de entrada
		>detección de expansión tras consolidación

	🔍 Length(18): Número de barras usadas para la media móvil y la desviación	estándar. 
        Importante: ambos cálculos usan el mismo Length, lo que hace el indicador coherente.
	    Tenemos en MovAvg una media simple SMA, que refleja la media de los últimos 18 cierres.
	
	📈 La desviación estándar mide:
		> cuánto se aleja el precio de su media, es decir, volatilidad
		> StDv grande → mercado volátil
		> StDv pequeña → mercado tranquilo / en rango
	
	📈 HighBand → límite superior
	📉 LowBand → límite inferior
	📌 Conceptualmente: el precio suele oscilar alrededor de la media,cuando se aleja más de una desviación estándar, 
    está en una zona extrema relativa. Es un concepto muy parecido a las Bandas de Bollinger, pero usando 1× desviación 
	en lugar de 2×.
	
	👉 Aunque usamos "Price(Close)" para los cálculos, las alertas usan "Close Crosses Over...". Esto significa que las bandas pueden calcularse 
	sobre otro precio si cambiamos Price, pero las alertas siempre se basan en el Close; no es un error, pero es una decisión de diseño.
}