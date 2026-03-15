{Esta estrategia entra en la dirección de la tendencia determinada por dos medias móviles exponenciales. 
El objetivo de beneficios y los niveles de stop loss están a n puntos del precio de entrada, establecidos mediante inputs.
La estrategia introduce varios conceptos como cooldown tras salida, dependencia del trade previo, uso explícito de EntryPrice, 
y gestión simétrica long/short.}

Inputs:
	FastEMAPrice(Close), FastEMALen(9),
	SlowEMAPrice(Close), SlowEMALen(18),
	CooldownBars(3), ProfitTargetPoints(1), StopLossPoints(.5);

Vars:
	FastEMA(0),	SlowEMA(0),
	BullTrend(false), BearTrend(false),
	IsFlat(false), IsLong(false), IsShort(false),
	CooldownPassed(false),
	FirstTrade(false);

// Cálculo de EMAs
FastEMA = XAverage(FastEMAPrice, FastEMALen);
SlowEMA = XAverage(SlowEMAPrice, SlowEMALen);

// Estado tendencia
BullTrend = FastEMA > SlowEMA;
BearTrend = FastEMA < SlowEMA;

// State machine básica
IsFlat = MarketPosition = 0;
IsLong = MarketPosition = 1;
IsShort = MarketPosition = -1;

// Cooldown tras salida
CooldownPassed = BarsSinceExit(1) >= CooldownBars;
FirstTrade = TotalTrades = 0;

// Setup de entrada
If IsFlat Then
Begin
	// Largo: tendencia alcista y último trade fue corto 
	If (FirstTrade or (CooldownPassed and MarketPosition(1) = -1))
		and BullTrend Then
		 Buy ("EMA_Trend_LE") Next Bar at Market;
		 	
	// Corto: tendencia bajista y último trade fue larto
	If (FirstTrade or (CooldownPassed and MarketPosition(1) = 1))
		and BearTrend Then
		 SellShort ("EMA_Trend_SE") Next Bar at Market;
End;

// Setup de salida
If IsLong Then
Begin
	Sell ("TP_LX") Next Bar at EntryPrice + ProfitTargetPoints Limit;
	Sell ("SL_LX") Next Bar at EntryPrice - StopLossPoints Stop;		
End;

If IsShort Then
Begin
	BuyToCover ("TP_SX") Next Bar at EntryPrice - ProfitTargetPoints Limit;
	BuyToCover ("SL_SX") Next Bar at EntryPrice + StopLossPoints Stop;
End;

// Tendencial trend continuation with directional alternation
{🧩Tipo de estrategia
	📈 Trend-following
	⚡ Basada en EMAs
	⏱️ Con cooldown tras salida
	🎯 Gestión fija por puntos
	🔁 Alterna dirección (evita reentrar en la misma)

👉No es un simple EMA cross, es un trend alternator con memoria del último trade.

🧠Resumen mental (muy importante)
	“Sigo la tendencia marcada por las EMAs. No reentro inmediatamente tras salir.
	Solo vuelvo a entrar cuando el mercado ha respirado y lo hago en la dirección opuesta al último trade.
	Cada trade tiene un riesgo y un objetivo fijos desde el inicio.”

🚀Setup de entrada
	📈 Largo: EMAs alineadas al alza + último trade fue corto o es el primer trade
	📉 Corto: EMAs alineadas a la baja + último trade fue largo o es el primer trade

🧩Regla de oro para salidas:
	🔹Si el precio de salida está “mejor” que el precio actual → LIMIT
	🔹Si el precio de salida está “peor” que el precio actual → STOP

📈Salidas de una posición LARGA
	🎯 Take Profit (TP): Orden limit es "véndeme a este precio o mejor (encima precio
	entrada)
	🛑 Stop Loss (SL): Orden stop sería "si el mercado llega aquí, ejecútame si o sí si
	el precio cae" (precio está por debajo del nivel actual)

📉Salidas de una posición CORTA
	🎯 Take Profit (TP): limit es "cómprame a este precio o mejor", mercado baja y usamos
	orden limit, compramos más barato
	🛑 Stop Loss (SL): stop está por encima precio actual "si el precio llega aquí, 
	ejecútame ya", 

Referenciamos a EntryPrice +/- X porque define el riesgo/beneficio desde la entrada.
👉“Gano si el mercado va a mi favor → espero con LIMIT. Pierdo si va en mi contra → me protejo con STOP.”
}