{-------------------------------------------------------------------
    Multi-Data Strategy v4.0
    Description:
    Further refined multi-data strategy with added re-entry logic and improved state management for better handling of market conditions.
    
    Additional controls:
    - Re-entry logic based on recent exit and current market conditions
    - Improved state management for clearer position tracking
    - Use of descriptive variable names for better readability
-------------------------------------------------------------------}

Inputs:
	MALenData1(12),     //Length MA timeframe operativo = ejecución
	MALenData2(24),     //Length MA timeframe superior (contexto) = tendencia mayor
	ReEntryBars(5);     //Ventana máxima para reentrada

Vars:
	//MAs calculadas en cada dataset
	MAData1(0),
	MAData2(0),
	//Dirección contexto mayor Data2
	ContextBullish(False),
	ContextBearish(False),	
	//Eventos primarios de cruces en Data1
	LongSignal(False),
	ShortSignal(False),	
	//State machine explícita
	IsLong(False),
	IsShort(False),
	//Validación reentradas
	CanReEnterLong(False),
	CanReEnterShort(False);

// ─────────────────────────────────────────
// Cálculo de medias
// ─────────────────────────────────────────
MAData1 = Average(Close, MALenData1);           //Usamos Data1 por defecto
MAData2 = Average(Close of Data2, MALenData2);  //Cálculo en dataset mayor Data2

// ─────────────────────────────────────────
// Confirmación de contexto (Data2)
// ─────────────────────────────────────────
ContextBullish = MAData2 > MAData2[1];          //Momentum alcista 
ContextBearish = MAData2 < MAData2[1];          //Momentum bajista

// ─────────────────────────────────────────
// Señales en Data1
// ─────────────────────────────────────────
LongSignal = Close Crosses Over MAData1;
ShortSignal = Close Crosses Under MAData1;

// ─────────────────────────────────────────
// State machine
// ─────────────────────────────────────────
IsLong = MarketPosition = 1;
IsShort = MarketPosition = -1;

// ─────────────────────────────────────────
// Entrada primaria
// ─────────────────────────────────────────
//Entramos si estamos flat
If MarketPosition = 0 Then
Begin
	//Largo si contexto mayor sube y Data1 cruza arriba
	If ContextBullish and LongSignal Then
		Buy ("MTF_LE") Next Bar at Market;
	//Corto si contexto mayor baja y Data1 cruza abajo
	If ContextBearish and ShortSignal Then
		SellShort ("MTF_SE") Next Bar at Market;
End;

// ─────────────────────────────────────────
// Reentrada por continuación
// ─────────────────────────────────────────
CanReEnterLong =
	//Contexto sigue alcista, precio > MA, salida fue reciente y no hay nuevo cruce
	ContextBullish  
	and Close > MAData1
	and BarsSinceExit(1) <= ReEntryBars
	and not LongSignal; 

CanReEnterShort =
	//Contexto sigue bajista, precio > MA, salida fue reciente y no hay nuevo cruce
	ContextBearish 
	and Close < MAData1
	and BarsSinceExit(1) <= ReEntryBars
	and not ShortSignal;

If MarketPosition = 0 Then
Begin
	If CanReEnterLong Then
		Buy ("MTF_RELE") Next Bar at Market;
	If CanReEnterShort Then
		SellShort ("MTF_RESE") Next Bar at Market;
End;

// ─────────────────────────────────────────
// Salidas técnicas
// ─────────────────────────────────────────
//Salimos del largo si la barra completa queda por debajo de la media
If IsLong and High < MAData1 Then
	Sell ("MTF_LX") Next Bar at Market;

//Salimos del lado corto si la barra completa queda por encima de la media
If IsShort and Low > MAData1 Then
	BuyToCover ("MTF_SX") Next Bar at Market;