{-------------------------------------------------------------------	
 RSI Overbought/Oversold v1

 Description:
 - Identifies potential reversal points based on the Relative Strength Index (RSI).
 - The strategy looks for situations where the RSI is on one side of the 50 level but has not made a new extreme in the last few bars, indicating a potential loss of momentum and a possible reversal.
-------------------------------------------------------------------}

Input:
	Price(Close),
	Length(14),
	StopAmt(50),
	TrlgAmt(100),
	BEAmt(50);

Vars:
	xRSI(0);

xRSI = RSI(Price, Length);

{Setup de entrada}
If xRSI < 50 and LowestBar(xRSI, 7) >= 3 Then
	Buy Next Bar at Market;
If xRSI > 50 and HighestBar(xRSI, 7) >= 3 Then
	SellShort Next Bar at Market;

{Setup de salida}
SetStopLoss(StopAmt);
SetBreakeven(BEAmt);
SetDollarTrailing(TrlgAmt);

{	🧩 Tipo de estrategia
		🔄 Reversión de momentum
		📉📈 Usa RSI como indicador de desaceleración
		❌ No persigue rupturas
		✅ Busca giro tras pérdida de impulso
		
		No es: ni una estrategia de sobrecompra/sobreventa clásica (70/30) 
		ni una estrategia tendencial pura.
	🧠 Resumen mental
	“Cuando el RSI está a un lado de 50 pero deja de empujar en esa dirección, 
	entro anticipando un giro. El riesgo está controlado desde el inicio y 
	dejo que el mercado gestione el resto.”
	
	Price (Close) → Precio usado para calcular el RSI.
	Length (14) → Periodo del RSI (valor clásico).
	📌 En esta estrategia NO se usan sobrecompra/sobreventa (70/30)
	👉 Se usa el nivel 50 como frontera de momentum.
	
	🚀 Setup de entrada
        📈 Entrada LARGA (Buy)
        👉xRSI < 50
            El mercado está en momentum bajista o débil.
        👉LowestBar(xRSI, 7) >= 3
            El RSI NO ha marcado su mínimo reciente en las últimas 3 barras.
            Es decir, el impulso bajista se está agotando.
            Supongamos el siguiente ejemplo RSI de las últimas 7 barras:
            Bar index:   6   5   4   3   2   1   0   ← barra actual
            RSI:        42  38  35  30  33  37  41
            El RSI más bajo es 30, ocurrió en la barra 3, entonces:
                LowestBar(xRSI, 7) = 3
                ✔️ Cumple >= 3
            Significa que el punto de mayor debilidad ocurrió hace al menos 
            3 barras. El RSI ya tocó su punto extremo, no está ocurriendo ahora.
            El mercado ha tenido tiempo para absorber el movimiento.Esto evita comprar 
            justo en el mínimo, en plena aceleración bajista, o bien entrar demasiado pronto
            
            🎯 ¿Por qué el valor 3?	No es mágico, es práctico:
                >= 1 → demasiado pronto
                >= 2 → aún muy cerca del extremo
                >= 3 → pequeño cool-off del mercado
                >= 5 → puede llegar tarde
            👉 3 barras es un filtro temporal razonable: ni impulsivo, ni tardío

        🧠 Lectura mental:
        “El RSI está por debajo de 50, pero ya no cae con fuerza → posible giro alcista.”
        
        📉 Entrada CORTA (SellShort)
        👉xRSI > 50
            Momentum alcista.
        👉HighestBar(xRSI, 7) >= 3
            El RSI no ha hecho máximos recientes.
            El impulso alcista pierde fuerza.
        🧠 Lectura mental:
        “El RSI está por encima de 50, pero deja de empujar → posible giro bajista.”
        
    🛑 Gestión de salidas
        🔻 Stop Loss
        🔐 Break Even
        🎯 Trailing Stop
            Acompaña al precio a favor.
            Bloquea beneficios si el mercado gira.
            📌 El trailing actúa después de que el trade se mueva a favor.
}