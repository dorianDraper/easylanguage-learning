{-------------------------------------------------------------------	
 Breakout v2

 Description:
 - Improve legibility and semantic intention of Breakout v1
 - Prepare code for future extensions (filters, risk management, post-analysis)
-------------------------------------------------------------------}

Inputs:
	LongPrice(High),
	LongLen(8),
	ShortPrice(Low),
	ShortLen(8),
	EntryBuffer(.02);

Vars:
	LongBreakout(0),
	ShortBreakout(0);

{🧮 Cálculo de niveles de ruptura}
LongBreakout = Highest(LongPrice, LongLen) + EntryBuffer;
ShortBreakout = Lowest(ShortPrice, ShortLen) - EntryBuffer;

{🚀 Setup de entrada}
Buy ("Brk LE") Next Bar at LongBreakout Stop;
SellShort ("Brk SE") Next Bar at ShortBreakout Stop;

{Esta estrategia compra en una ruptura por encima del High más alto de las 8 barras anteriores; vende al descubierto en 
una ruptura por debajo del Low más bajo de las últimas barras precedentes.

🧠“El mercado lleva varias barras sin romper extremos. Si rompe el 
máximo reciente, quiero comprar. Si rompe el mínimo reciente, quiero vender.
No opino, solo reacciono.”

🧩 Qué tipo de estrategia es esta
	📈 Breakout puro
	🔁 Always-in-the-market (órdenes activas)
	⏱️ Independiente del timeframe
	🧠 Ejercicio fundacional para:
		stops
		targets
		filtros
		multi-timeframe
}