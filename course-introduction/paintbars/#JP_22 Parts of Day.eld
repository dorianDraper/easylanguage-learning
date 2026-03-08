// PaintBar que pinte la mitad inferior de aquellas barras que están en la primera y última hora del día

Input:
	FirstPartEnd(1030),
	LastPartStart(1501);

Vars:
	HalfBar(0);

HalfBar = (High + Low) * .5;

If Time <= FirstPartEnd or Time >= LastPartStart Then
    PlotPB(Low, HalfBar, "PartsOfDay")
Else
    NoPlot(1);


{	🧠 Este PaintBar:
		Usa el tiempo para filtrar barras relevantes
		Calcula la mitad del rango de la vela
		Pinta solo la mitad inferior
	👉 Resalta:
		- Apertura
		- Cierre
	👉 Ayuda a:
		- Identificar zonas de mayor participación
		- Dar contexto visual al precio
		- Evitar sobreanálisis en horas “muertas” 
    🔍 Nuestra variable también se podría escribir así: HalfBar = Low + (Range / 2)
	Visualmente sería así:
		High
		│
		│─── HalfBar  ← punto medio
		│
		Low
    ❓ La barra actual ocurre en la primera o última hora del día?
    Si la respuesta es sí, pintamos la mitad inferior de la barra. Si no, usamos NoPlot para no pintar nada.
    
}