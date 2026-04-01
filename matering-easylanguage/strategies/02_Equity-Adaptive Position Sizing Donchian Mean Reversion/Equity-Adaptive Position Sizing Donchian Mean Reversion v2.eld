{ Segunda versión con ajustes, mantenemos lógica intaca pero separamos semántica 
(riesgo vs sizing) y hacemos explícito el estado. Esto prepara el sistema para 
futuras mejoras como trailing stops o filtros adicionales sin complicar la lógica actual. }

Inputs:
	BaseTradeSize(1000),
	SizeStep(100),
	MaxTradeSize(2000),
	MinTradeSize(100),
	RiskUnit(500),
	DonchianLen(21);

Vars:
	TradeSize(0),
	TradeSizeAdjust(0),
	LongSetup(false),
	ShortSetup(false),
	IsFlat(false);

// State
IsFlat = MarketPosition = 0;

// Ajuste por equity
If AbsValue(NetProfit) >= RiskUnit Then
	TradeSizeAdjust = Round((NetProfit / RiskUnit), 0) * SizeStep
Else
	TradeSizeAdjust = 0;

// Límites de tamaño
TradeSize = BaseTradeSize + TradeSizeAdjust;

If TradeSize > MaxTradeSize Then
	TradeSize = MaxTradeSize
Else If TradeSize < MinTradeSize Then
	TradeSize = MinTradeSize;
	
// Señales Donchian
LongSetup = Low < Lowest(Low, DonchianLen)[1];
ShortSetup = High > Highest(High, DonchianLen)[1];

// Setup de entrada
If IsFlat and LongSetup Then
	Buy Next Bar TradeSize Shares at Market;

If IsFlat and ShortSetup Then
	SellShort Next Bar TradeSize Shares at Market;

// Gestión del riesgo
SetStopLoss(RiskUnit);
SetProfitTarget(RiskUnit);

{
⚠ Problemas semánticos y de diseño de la primera versión
1. El input 'ProfitStopLoss' controlaba demasiado: el SL, TP y escalado de tamaño, se
debía separar.
2. No había state machine explícita, se confía en el motor, se puede optimizar.

🧩 Criterios de mejora (sin añadir complejidad)
	✔️ Separar semántica (riesgo vs sizing)
	✔️ Hacer explícito el estado
	✔️ Mantener la lógica intacta
	✔️ Preparar el sistema para extensiones futuras (ej: trailing stops, filtros adicionales)

🧩 Tipo de estrategia
	📉 Mean reversion / contrarian
	📊 Basada en canal Donchian
	🔁 Entrada en extremos
	💰 Position sizing adaptativo por equity
	🛑 Salidas por: stop fijo, target fijo

🧠 Resumen mental (clave)
	“Cuando el mercado hace un extremo nuevo, entro en contra esperando reversión.
	Si el sistema va bien, aumento tamaño. Si va mal, reduzco exposición.
	Cada trade arriesga siempre la misma unidad.”

NOTA: SI INVERTIMOS EL SETUP (ENTRO LARGO CUANDO HACE NUEVO HIGH Y CORTO CUANDO HACE UN
NUEVO LOW, LA ESTRATEGIA TIENE MEJOR EQUITY.

Ajuste por equity: Por cada unidad de riesgo ganada o perdida, aumentamos o reducimos el
tamaño del trade = equity-based position sizing. Supongamos:

RiskUnit = 500
SizeStep = 100

NetProfit	NetProfit/RiskUnit	  Round	  Ajuste
+500			     1				 1		+100
+1200				 2.4			 2		+200
-500				 -1				-1		-100
-1300				 -2.6			-3		-300
}