{	Reto 2: Escriba un indicador que trace dos bandas alrededor de los datos de
	precios. Una banda añade la mitad del rango de la barra previa a la apertura
	de la barra actual. La otra banda resta la mitad del rango de la barra previa
	a la apertura de la barra actual
}

Vars:
	HighBand(0),
	LowBand(0);

HighBand = Open + (High[1] - Low[1]) * .5;
LowBand = Open - (High[1] - Low[1]) * .5;

Plot1(HighBand, "HighBand");
Plot2(LowBand, "LowBand");

{	>Este indicador construye dos bandas intradía alrededor del precio de apertura 
	de la barra actual, usando la mitad del rango de la barra anterior como referencia.
		>Usa la volatilidad de la barra previa
		>La proyecta simétricamente arriba y abajo del Open actual
		>Crea un canal dinámico basado en el contexto inmediato anterior
	>La mitad del rango es el 50% de la volatilidad de la barra anterior. Es una medida
	simple y rápida de “cuánto se movió el mercado” en la vela previa.
	
	>UpperBand: Si el precio sube más de la mitad del rango previo desde el Open, 
	está mostrando fuerza.
	>LowerBand: Si el precio cae más de la mitad del rango previo desde el Open, 
	está mostrando debilidad.
}