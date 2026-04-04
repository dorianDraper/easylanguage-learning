{-------------------------------------------------------------------	
 Multi-Data v1

 Description:
 - Implements a long-only strategy that uses two different data series (timeframes) to confirm trade
   entries.
 - The strategy buys when the price on the primary timeframe (Data1) is above its moving average and 
 the price on the secondary timeframe (Data2) is also above its moving average, indicating a strong bullish trend across multiple timeframes.

 -------------------------------------------------------------------}

Input:
	MALenD1(20),
	MALenD2(50);

Vars:
	MAD1(0),
	MAD2(0);

MAD1 = Average(Close Data1, MALenD1);
MAD2 = Average(Close Data2, MALenD2);

{Setup de entrada}
If Close > MAD1 and Close Data2 > MAD2 Then
	Buy Next Bar at Market
Else
	Sell Next Bar at Market;

{📈 Estrategia Long-only Multi-Data con Medias Móviles (Data1 & Data2)
	
	🧠 Inputs
	MALenD1(20): Periodo MA aplicada al Data1 (timeframe principal / operativo).
	MALenD2(50): Periodo MA aplicada al Data2 (timeframe superior / filtro).
	
	🧮 Cálculo de indicadores
	Close Data1 → Cierre del timeframe operativo (por ejemplo 5 min)
	Close Data2 → Cierre del timeframe superior (por ejemplo 60 min o diario)
	📌 Cada media se calcula en su propio universo temporal, no se mezclan.
	Esto es multi-timeframe real, no un truco visual.
	
	🚀 Setup de entrada
	🟢 Condición de compra (BUY)
	Se ejecuta solo si ambas condiciones son verdaderas:
	Data1 está alcista: Close > MAD1
		→ El precio actual del timeframe operativo está por encima de su media.
	Data2 también está alcista: Close Data2 > MAD2
		→ El precio del timeframe superior confirma la tendencia.
	📈 Conclusión:
	“Opero largo solo si el corto plazo y el contexto mayor van en la misma dirección”.
	
	📌 Cuando la condición es falsa, se ejecuta Sell. Esto solo tiene efecto 
	si ya vamos largos. NO abre una posición corta. Por tanto, este Else NO 
	es simétrico al Buy.
	
	Qué tipo de estrategia es esta:
		📈 Trend Following
		⏱  Multi-Timeframe
		🧭 Filtro de tendencia por timeframe superior
}