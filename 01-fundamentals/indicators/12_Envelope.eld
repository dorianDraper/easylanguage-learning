//Reto 3: Escriba un indicador que trace la media variable de 20 barras de los Highs y lo mismo para los Lows.

Input:
	UpperLength(20),
	LowerLength(20);

Vars:
	UpperLine(0),
	LowerLine(0);

UpperLine = Average(High, UpperLength);
LowerLine = Average(Low, LowerLength);

Plot1(UpperLine, "Highs");
Plot2(LowerLine, "Lows");

{	🧠 Este indicador construye dos líneas dinámicas:
		Una línea basada en la media de los máximos (High)
		Otra línea basada en la media de los mínimos (Low)
	🔍 No es un canal de volatilidad (como Bollinger), sino un canal estructural basado en promedios.
	👉 Al crear la length de las líneas como inputs tenemos la posibilidad de hacer ajustes asimétricos y experimentar (por ejemplo, suavizar más un 
	lado que otro).
	👉 La media móvil de los Highs representa una resistencia media dinámica, mientras que los Lows representa un soporte medio dinámico.
	👉 Estas líneas respetan la estructura extrema del precio y son más sensibles a la presión compradora/vendedora.
	
	Este tipo de indicador es muy útil para:
		>Identificar estructura de tendencia
		>Detectar zonas dinámicas de soporte y resistencia
		>Filtrar trades (solo largos por encima del canal, cortos por debajo)
		>Construir sistemas tipo:
			Pullbacks
			Breakouts suaves
			Mean reversion dentro de canal
}