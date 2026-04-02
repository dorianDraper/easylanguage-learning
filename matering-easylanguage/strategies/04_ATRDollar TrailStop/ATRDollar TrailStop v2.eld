{-------------------------------------------------------------------
Versión 2 con semántica y lógicas ajustadas
Inputs mantienen su nombre original pero Vars y lógica interna se han reescrito para mejorar 
claridad, consistencia y adaptabilidad.
-------------------------------------------------------------------}

Inputs:
	ATRTrail(1),  	        //Qué tan cerca sigue el trailing al precio una vez activo
	ATRFloor(2),  	        //Cuántos ATRs debe avanzar el precio para activar el trailing
	ATRStopLoss(1),         //Cuántos ATRs estamos dispuestos a perder al inicio
	ATRLen(9);  	        //Cómo medimos la volatilidad

Vars:
	ATRValue(0),            //Valor actual del ATR
	FloorDistance(0),       //Distancia en puntos para activar el trailing (ATRFloor x ATR)
	TrailDistance(0),       //Distancia en puntos para el trailing una vez activo (ATRTrail x ATR)
	StopLossDistance(0),    //Distancia en puntos para el stop inicial (ATRStopLoss x ATR)
	TrailingActive(false),  //Indica si el trailing ya está activo
	IsFlat(false),
	IsLong(false),
	IsShort(false);

// Cálculo ATR
ATRValue = AvgTrueRange(ATRLen);

FloorDistance = ATRValue * ATRFloor;
TrailDistance = ATRValue * ATRTrail;
StopLossDistance = ATRValue * ATRStopLoss;

// State machine
IsFlat = MarketPosition = 0;
IsLong = MarketPosition = 1;
IsShort = MarketPosition = -1;

// Si estamos flat, reseteamos todo
If IsFlat Then
	TrailingActive = False;

SetStopShare;

// Si tenemos una posición abierta (ya sea larga o corta) 
If MarketPosition <> 0 Then
Begin
	If not TrailingActive Then
	Begin
        //Mientras el trailing no esté activo, solo tenemos el stop inicial
		SetStopLoss(StopLossDistance * BigPointValue);
		
        // Verificamos si el precio ha avanzado lo suficiente para activar el trailing (ATRFloor x ATR)
		If(IsLong and High >= EntryPrice + FloorDistance) or 	
			(IsShort and Low <= EntryPrice - FloorDistance) Then
				TrailingActive = True;
	End;
	
    // Si el trailing ya está activo, seguimos al precio con la distancia definida por ATRTrail x ATR
	If TrailingActive Then
		SetDollarTrailing(TrailDistance * BigPointValue);
End;

{ 	
Volatility-aware, state-driven exit engine
🧩 Se trata de un componente de salida inteligente, basado en volatilidad (ATR), que:
🔹protege al inicio
🔹exige progreso real al trade,
🔹y solo entonces deja correr beneficios con un trailing dinámico.
🔹No entra al mercado. No decide dirección. Solo gestiona la salida.
🔹Las entradas: NO están aquí, vienen de estrategias pre-creadas (e.g., MACD LE/SE...)

📊 Flujo lógico paso a paso (barra a barra)
🟦 Estado 1: Flat
MarketPosition = 0
TrailingActive = false
Nada ocurre. El sistema está limpio.

🟨 Estado 2: Trade abierto – SIN trailing
MarketPosition ≠ 0
TrailingActive = false
✔ Se aplica Stop Loss inicial
✔ Basado en ATRStopLoss × ATR
✔ Convertido a dinero con BigPointValue
📌 Objetivo aquí: no perder demasiado si el trade falla rápido

🚪 Evento clave: activación del trailing (el “floor”)
🔹Para largo: High ≥ EntryPrice + (ATRFloor × ATR)
🔹Para corto: Low ≤ EntryPrice − (ATRFloor × ATR)
👉 Solo si el mercado realmente se mueve a favor, activamos trailing.
TrailingActive = true;

🟩 Estado 3: Trailing activo
SetDollarTrailing(ATRTrail × ATR × BigPointValue);
Ahora:
🔹el stop sigue al precio
🔹se adapta a la volatilidad
🔹protege beneficios
🔹deja respirar al mercado

🧠 Resumen mental / interpretación conceptual (para interiorizar)
🔑 Entro al mercado con riesgo controlado
🔑 Si el trade no demuestra valor, salgo rápido
🔑 Si demuestra valor, lo dejo correr
🔑 El mercado decide cuándo me saca, no yo
🔑 Todo se adapta automáticamente a la volatilidad

O dicho de otra forma: Primero sobrevivo, luego participo, solo después optimizo
}
