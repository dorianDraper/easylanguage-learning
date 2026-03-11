{	Esta estrategia toma posiciones cortas y largas basándose en los cruces de dos medias móviles. Una posición se cerrará cuando 
    se haya mantenido abierta por lo menos un número mínimo de barras y no haya alcanzado al menos un beneficio mínimo.
}

Input:
	ShortPrice(Close),
	LongPrice(Close),
	ShortLen(9),
	LongLen(18),
	MinHold(8),
	MinProfit(100);

Vars:
	ShortMA(0),
	LongMA(0);

ShortMA = Average(ShortPrice, ShortLen);
LongMA = Average(LongPrice, LongLen);

{Setup entrada}
If ShortMA Crosses Over LongMA Then
	Buy Next Bar at Market;
If ShortMA Crosses Under LongMA Then
	SellShort Next Bar at Market;

{Setup salida}
If BarsSinceEntry > MinHold and OpenPositionProfit < MinProfit Then
Begin
	Sell Next Bar at Market;
	BuyToCover Next Bar at Market;
End; 

{	👉 Entrada por momentum cruce de medias. Buscamos movimientos rápidos y	eficientes, evitar quedarse atrapado en trades laterales.
	🔹 Entrada larga (Buy)
		- Cuando la media rápida cruza hacia arriba la lenta.
		- Interpretación: cambio de momentum a alcista.
		- La orden se ejecuta: Next Bar At Market (al precio disponible al abrir la siguiente vela).

	🔹 Entrada corta (SellShort)
		- Cuando la media rápida cruza hacia abajo la lenta.
		- Interpretación: cambio de momentum a bajista.
	
	📌 Importante:
		Aquí sí usamos If, porque los cruces son eventos lógicos, no precios.
		No hay [1] porque Crosses Over/Under ya gestiona internamente la comparación entre barras.
	
	🛑 Salida
        “Si ya llevo suficiente tiempo en la operación y no estoy ganando lo suficiente, salgo.”
        If (tiempo suficiente) AND (beneficio insuficiente)
	
        🧠 BarsSinceEntry > MinHold
        Cuenta cuántas barras han pasado desde que entramos.
        Evita salir demasiado pronto. Obliga a “darle tiempo” a la operación.
        
        🧠 OpenPositionProfit < MinProfit
        Evalúa el beneficio actual no realizado.
        Está en dólares (o moneda de la cuenta). 
        Si tras ese tiempo el trade no ha generado suficiente beneficio 
        → se considera ineficiente.
}