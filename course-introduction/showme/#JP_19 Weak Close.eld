{	Reto 4: Escriba un ShowMe que marque el High de aquellas barras que tienen un Close que está en el tercio inferior de su rango. 
    Incluya una instrucción NoPlot para eliminar un Plot si la condición de verdadero se convierte en falso antes de que finalice la barra.
}

Input:
	RangePortion(3);

If Close < Low + (Range / RangePortion) Then
Begin
	Plot1(High, "Weak Close");
	Alert;
End
Else
	NoPlot(1);

{
	🧠 Concepto clave: “Weak Close”
	👉 Una vela tiene un Weak Close cuando:
        > Su precio de cierre está cerca del mínimo del rango de la vela.
        > Este código define “cerca” como: Estar dentro del primer tercio inferior del rango total de la vela.

	👉 El punto lo queremos situado a 1/3 del rango por encima del mínimo:

				High
				│
				│   Parte alta (2/3 a 3/3)
				│
				│--- Low + 2*(Range/3)
				│
				│   Parte media (1/3 a 2/3)
				│
				│--- Low + (Range/3)
				│
				│   Parte baja (0 a 1/3)
				Low

	🔍 Así que si el cierre está dentro del primer tercio del rango (la parte baja de la vela) entonces la vela se considera débil.
            >>Identificamos presión vendedora dentro de la vela
            >>Señales de agotamiento del precio
            >>Filtrar velas de debilidad en swings alcistas
            >>Crear condiciones para estrategias de reversión o continuación
		
	🧩 Si quisiéramos un Strong Close cambiaríamos a:
	"""If Close > High - (Range / RangePortion) Then....Plot1(Low, "Strong Close")"""
	WEAK CLOSE = If Close < Low + (Range / RangePortion) == El cierre está dentro del primer tercio por encima del Low
	STRONG CLOSE = If Close > High - (Range / RangePortion) == El cierre está dentro del último tercio (superior) antes del High
	
	🎯 NEXT STEP COMBINAR AMBOS WEAK & STRONG CLOSE
}