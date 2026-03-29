{Segunda versión con mejoras de semántica, lógica y separación de estados}

Inputs:
	FastLen(13),
	SlowLen(21),
	ExtensionLen(50),
	ReEntryBuffer(.10);

Vars:
	FastMA(0),
	SlowMA(0),
	MoveHigh(0),
	CanReEnter(false),
	IsFlat(false),
	IsLong(false),
	BullCross(false),
	BearCross(false);

// Tendencia (cálculo medias móviles)
FastMA = Average(Close, FastLen);
SlowMA = Average(Close, SlowLen);

// State machine
IsFlat = MarketPosition <= 0;
IsLong = MarketPosition = 1;

// Evento primario (cruce de medias móviles)
BullCross = FastMA Crosses Over SlowMA;
BearCross = FastMA Crosses Under SlowMA;

// Entrada inicial
If IsFlat and BullCross Then
Begin
	Buy ("InitLE") Next Bar at Market;
	MoveHigh = High;
	CanReEnter = False;
End; 

// Gestión estando largos
If IsLong Then
Begin
	//Actualizar máximo del movimiento
	If High > MoveHigh Then
		MoveHigh = High;
	
	//Salida por extensión (técnica, no por debilidad de tendencia)
	If not CanReEnter and High > Highest(High, ExtensionLen)[1] Then
	Begin
		Sell ("ExtLX") Next Bar at Market;
		CanReEnter = True;
	End;
	
	//Salida final por cambio de tendencia
	If BearCross Then
		Sell ("TrendLX") Next Bar at Market;
		CanReEnter = False;
		MoveHigh = 0;
End;

// Re-entrada
If MarketPosition = 0 and CanReEnter
	and High > MoveHigh + ReEntryBuffer Then
	Buy ("ReEntryLE") Next Bar at Market;


{🧠 Resumen mental / interpretación conceptual
🔑 Entro cuando nace la tendencia
🔑 Salgo cuando el movimiento se estira demasiado
🔑 Si la tendencia sigue viva, vuelvo a entrar
🔑 Solo dejo de re-entrar cuando la tendencia muere

O dicho de forma muy clara:
	No me caso con una sola entrada,
	me caso con la tendencia mientras exista.
	“la tendencia sigue viva → puedo volver a participar”

🧩 Tipo de estrategia
	📈 Trend-following (long only)
	🔁 Re-entry logic
	🧠 State-driven
	❌ No martingala
	❌ No piramidación

┌─────────┐
│  FLAT   │
└────┬────┘
     │ FastMA crosses over SlowMA
     ▼
┌──────────────┐
│  LONG ACTIVE │  ← seguimos el movimiento
└────┬─────────┘
     │ extensión excesiva (nuevo HH significativo)
     ▼
┌──────────────┐
│ TECH EXIT    │  ← salida técnica, no fallo de tendencia
│ CanReEnter=1 │
└────┬─────────┘
     │ continuidad alcista (nuevo impulso)
     ▼
┌──────────────┐
│ RE-ENTER LONG│
└────┬─────────┘
     │ FastMA crosses under SlowMA
     ▼
┌─────────┐
│  FLAT   │  ← tendencia invalidada
└─────────┘

}