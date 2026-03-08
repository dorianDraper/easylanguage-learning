{	Se trata de volver a escribir el reto #2, 08 Bands, incorporando 
	variables numéricas declaradas por el usuario. En nuestro caso,
	ya habíamos realizdo el ejercicio con variables numéricas, replicaremos
	la forma en la que se realiza en el manual.
}

Vars:
	HalfPrevRange(0),
	HighBand(0),
	LowBand(0);

HalfPrevRange = (High[1] - Low[1]) * .5;
HighBand = Open + HalfPrevRange;
LowBand = Open - HalfPrevRange;

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