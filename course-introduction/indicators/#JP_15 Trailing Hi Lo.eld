// Este indicador traza dos líneas que representan el valor más alto y el más bajo de un input a lo largo de un número determinado de barras.

Input:
	TrlgBars(8),
	HiPx(High),
	LoPx(Low);

Vars:
	HighLine(0),
	LowLine(0);

HighLine = Highest(HiPx, TrlgBars)[1];
LowLine = Lowest(LoPx, TrlgBars)[1];

Plot1(HighLine, "TrlgHigh");
Plot2(LowLine, "TrlgLow");

{	🧠 Es un indicador de niveles dinámicos tipo trailing, que:
		>Calcula un máximo reciente y un mínimo reciente
		>Los desplaza una barra atrás
		>Los dibuja como líneas continuas
	🧩 Conceptualmente es muy cercano a: Canales de breakout, Donchian Channels (versión simple) y niveles de soporte/resistencia dinámicos.
	❓ Porqué usamos [1]? “Usa el valor de la barra anterior, no el de la barra actual”:
        ✅ Evita repainting: No se usan datos de la vela que aún se está formando. El nivel es estable durante toda la barra actual.
        ✅ Hace el indicador usable para trading real. El nivel que ves ya existía antes de que el precio llegue a él. 
        Es un nivel “conocido”, no recalculado en tiempo real.
        ✅ Sin [1], el nivel se movería con el precio actual.
	
	👉 Muy típico en:
        🔹Estrategias de breakout
        🔹Stops dinámicos
        🔹Canales de consolidación
        🔹Confirmaciones de tendencia
        🔹Ejercicios base de EasyLanguage (muy bien elegido)
	
    📈 Ejemplo conceptual: Buy si el precio rompe TrlgHigh; SellShort si rompe TrlgLow
	
	🧠 Este indicador NO predice, reacciona a lo que ya ha ocurrido y lo convierte en un nivel operativo.
}