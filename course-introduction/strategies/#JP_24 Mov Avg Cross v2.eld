{Versión 2 de Mov Avg Cross añadiendo un filtro de volumen para abrir las posiciones. El sistema solo puede abrir posición, 
tanto corta como larga, si el volumen de la barra actual es mayor que el volumen medio de las últimas 20 barras. 
Incluimos AutoStop-Loss de $500 que sea input.}

Input:
	FastPrice(Close), SlowPrice(Close),
	FastLen(9), SlowLen(18),
	VolLen(20),	MinHold(8),	MinProfit(100),
	SLAmt(500),	PositionBasis(true);

Vars:
	FastMA(0),
	SlowMA(0),
	AnyVol(0),
	AvgAnyVol(0);

{
For Daily, Weekly, or Monthly bars, use "Volume"; for all other bar types use
"Ticks"; in the case of second or minute data, also set the "For volume, use:"
field in the Format Symbol dialog to Trade Vol or Tick Count, as desired; when
using advanced chart types, "Ticks" returns volume if the chart is built from
1-tick interval data
}

// Normalización volumen
If BarType >= 2 and BarType < 5 Then	
	AnyVol = Volume
Else
	AnyVol = Ticks;

// Cálculo medias y volumen medio
AvgAnyVol = AverageFC(AnyVol, VolLen);
FastMA = AverageFC(FastPrice, FastLen);
SlowMA = AverageFC(SlowPrice, SlowLen);

// Setup de entrada: filtro volumen y eventos
Condition1 = AnyVol > AvgAnyVol;
If Condition1 Then
Begin
	If FastMA Crosses Over SlowMA Then
		Buy Next Bar at Market;
	
	If FastMA Crosses Under SlowMA Then
		SellShort Next Bar at Market; 
End;

{Setup de salida}
If BarsSinceEntry > MinHold and OpenPositionProfit < MinProfit Then
Begin
	Sell Next Bar at Market;
	BuyToCover Next Bar at Market;
End;

// SL flexible
If PositionBasis Then
	SetStopPosition
Else
	SetStopShare;

SetStopLoss(SLAmt);

// Tendencial
{   🧩Tipo estrategia: Trend-following & Moving Avg Crossover, confirmada por volumen
	con filtro time+profit y gestión riesgo. Esta estrategia incorpora:
	🔹cruce de medias
	🔹filtro de volumen adaptable al tipo de barra
	🔹lógica de salida por tiempo + beneficio
	🔹y gestión del riesgo configurable (por posición o por contrato)
	
    🔁Inputs:
	🔹FastPrice / SlowPrice: Precio usado para cada media (normalmente Close).
	🔹FastLen / SlowLen: Periodos de la media rápida (9) y lenta (18).
	🔹VolLen: Periodo para calcular el volumen medio (20 barras).
	🔹MinHold: Número mínimo de barras que debe mantenerse una posición antes de permitir salida por bajo beneficio.
	🔹MinProfit: Beneficio mínimo esperado tras MinHold barras.
	
    🔻Si no se alcanza → salida forzada:
	🔹SLAmt: Stop Loss monetario (en dólares).
	🔹PositionBasis:
		🔹🔹true → stop calculado sobre toda la posición
		🔹🔹false → stop calculado por contrato/acción
	👉 Este input es muy importante para adaptar la estrategia a futuros, acciones o CFDs.
  	
  	📈 Normalización volumen: La estrategia se adapta automáticamente:
  		🔹En gráficos de tiempo → usa Volume
  		🔹En gráficos no temporales → usa Ticks
  	
  	👉 Usa AverageFC (faster calculation), más eficiente que Average. Calcula:
		🔹volumen medio
		🔹media rápida
		🔹media lenta

	📌 Condition1 solo permite operar cuando el volumen actual > vol medio reciente, esto permite identificar:
		🔹Hay participación real
		🔹Se evitan cruces “vacíos” o de baja liquidez
		🔹Reduce señales falsas en rangos muertos
	
	🚀 Entramos si el volumen está por encima de la media y cruce de medias:
		🔹Largo: media rápida cruza por encima lenta y hay volumen (interés comprador)
		🔹Corto: media rápida cruza por debajo lenta y hay volumen (presión vendedora real)

	🛑 Obliga a mantener la posición al menos MinHold barras. 
    Pasado ese tiempo si no hay suficiente beneficio se sale a mercado. Dos modos de Stop:
 		🔹SetStopPosition: basado en resultado total de la posición
 		🔹SetStopShare: por contrato/acción
}