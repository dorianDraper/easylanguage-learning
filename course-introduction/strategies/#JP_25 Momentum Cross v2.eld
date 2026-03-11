// Versión 2 Momentum Cross

Input:
	Price(Close),
	MomLen(10),
	NumBullBars(4),
	NumBearBars(4),
	LimitPoints(.05);

Vars:
	Mom(0),
	BullMom(false),
	BearMom(false),
	BuyFilter(false),
	SellFilter(false),
	DownMom(false),
	UpMom(false);

// Momentum
Mom = Momentum(Price, MomLen);

// Eventos primarios
BullMom = Mom Crosses Over 0;
BearMom = Mom Crosses Under 0;

// Filtros MRO
BuyFilter = MRO(BearMom, NumBearBars, 1) = -1;
SellFilter = MRO(BullMom, NumBullBars, 1) = -1;

// Deterioro del Momentum
DownMom = Mom < Mom[1] and Mom[1] < Mom[2];
UpMom = Mom > Mom[1] and Mom[1] > Mom[2];

{Setup de entrada}
If BullMom and BuyFilter Then
	Buy Next Bar at Close of This Bar - LimitPoints Limit;
If BearMom and SellFilter Then
	SellShort Next Bar at Close of This Bar + LimitPoints Limit;

{Setup de salida}
If DownMom Then
	Sell Next Bar at Market;
If UpMom Then 
	BuyToCover Next Bar at Market;

// Print Log
Print("Date", Spaces(2), Date:7:0, Spaces(2), "Time", Spaces(2), Time:4:0,
Spaces(2), "Mom", Spaces(2), Mom, Spaces(2), "BullMom", Spaces(2), BullMom,
Spaces(2), "BearMom", Spaces(2), BearMom);

// Analysis Commentary
Commentary("Date", Spaces(2), Date:7:0, Spaces(2), "Time", Spaces(2), Time:4:0,
Spaces(2), "Mom", Spaces(2), Mom, Spaces(2), "BullMom", Spaces(2), BullMom,
Spaces(2), "BearMom", Spaces(2), BearMom);


{	📈 Momentum continuation
	🚦 Entrada solo con impulso limpio
	🧠 Salida por deterioro de impulso
	❌ Sin stops fijos
	❌ Sin targets
	✅ Basada en estructura del mercado
	
	“Solo entro cuando el mercado demuestra intención clara. Me quedo 
	mientras esa intención se mantiene. Salgo en cuanto esa intención 
	empieza a debilitarse.”

	🧠 Resumen mental (muy importante)
	Crear variables booleanas mejora:
		- lectura
		- depuración
		- mantenimiento
	🚀 Separamos siempre:
		🔹 eventos primarios (cruces, rupturas)
		🔹 filtros (MRO, time filters)
		🔹 salidas (deterioro, stops)

	👉 Esta forma de pensar es exactamente la que se usa en sistemas profesionales y research cuantitativo.
}