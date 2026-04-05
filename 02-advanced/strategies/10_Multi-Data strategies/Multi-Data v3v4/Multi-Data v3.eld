{-------------------------------------------------------------------
    Multi-Data Strategy v3.0
    Description:
    Refined multi-data strategy with explicit state machine for position management and clearer signal definitions.
    We changed the the logic of the strategy to use the crossover event instead of the relationship 
    between the price and the moving average, this way we can have a more clear signal generation 
    and avoid some false signals that can happen when the price is above or below the moving average but not crossing it.

    Additional controls:
    - Explicit state machine for long and short positions
    - Clear separation of context confirmation and signal generation
    - Use of descriptive variable names for better readability

-------------------------------------------------------------------}

Inputs:
	MALenData1(12),                         //Length MA timeframe operativo = ejecución
	MALenData2(24);                         //Length MA timeframe superior (contexto) = tendencia mayor 

Vars:
	//MAs calculadas en cada dataset
	MAData1(0),
	MAData2(0),
	//State machine explícita
	IsLong(False),
	IsShort(False),
	//Dirección contexto mayor Data2
	ContextBullish(False),
	ContextBearish(False),
	//Eventos primarios de cruces en Data1
	LongSignal(False),
	ShortSignal(False);

// ─────────────────────────────────────────
// Cálculo de medias
// ─────────────────────────────────────────
MAData1 = Average(Close, MALenData1);          //Usamos Data1 por defecto
MAData2 = Average(Close of Data2, MALenData2); //Cálculo en dataset mayor Data2

// ─────────────────────────────────────────
// Confirmación de contexto (Data2)
// ─────────────────────────────────────────
ContextBullish = MAData2 > MAData2[1];         //Momentum alcista 
ContextBearish = MAData2 < MAData2[1];         //Momentum bajista

// ─────────────────────────────────────────
// Señales en Data1
// ─────────────────────────────────────────
LongSignal = Close Crosses Over MAData1;       
ShortSignal = Close Crosses Under MAData1;

// ─────────────────────────────────────────
// Setup de entrada
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
// State machine
// ─────────────────────────────────────────
IsLong = MarketPosition = 1;
IsShort = MarketPosition = -1;

// ─────────────────────────────────────────
// Salidas técnicas
// ─────────────────────────────────────────
//Salimos del largo si la barra completa queda por debajo de la media
If IsLong and High < MAData1 Then
	Sell ("MTF_LX") Next Bar at Market;

//Salimos del lado corto si la barra completa queda por encima de la media
If IsShort and Low > MAData1 Then
	BuyToCover ("MTF_SX") Next Bar at Market;