{-------------------------------------------------------------------	
 Momentum Cross v1

 Description:
 - Buy when Momentum crosses above 0, Sell when it crosses below 0
 - Exit when Momentum changes direction (3 consecutive bars)
 - No filters, no limit orders, no stops
 - Very basic, not realistic, but good for learning
 - Next version will add filters and limit orders
 
-------------------------------------------------------------------}

Input:
	Price(Close),
	Length(10),
	BullLen(4),
	BearLen(4);

Vars:
	Mom(0),
	BullCx(false),
	BearCx(false);

Mom = Momentum(Price, Length);
BullCx = Mom Crosses Over 0;
BearCx = Mom Crosses Under 0;

{Setup de entrada}
If BullCx and MRO(BearCx, BearLen, 1) = -1 Then
	Buy Next Bar at Close of This Bar Limit;
If BearCx and MRO(BullCx, BullLen, 1) = -1 Then
	SellShort Next Bar at Close of This Bar Limit;

{Setup de salida}
If Mom < Mom[1] and Mom[1] < Mom[2] Then
	Sell Next Bar at Market;
If Mom > Mom[1] and Mom[1] > Mom[2] Then
	BuyToCover Next Bar at Market;

{	📈 BullCx → el momentum pasa de negativo a positivo
	📉 BearCx → el momentum pasa de positivo a negativo
		Esto solo es True en la barra exacta del cruce. En la siguiente barra vuelve a False
	
	📈 BullCx AND no ha habido BearCx en las últimas BearLen barras 
	👉 Esto evita: Entrar largo justo después de una señal bajista,	Whipsaws y cambios rápidos de dirección
	🎯 Aquí filtramos ruido, no solo reaccionando al cruce.
	🧠 Significa:
		- Momentum cruza a positivo
		- No hubo cruce bajista reciente
		- Coloca una orden limit en el cierre de la barra actual
	👉 La orden se ejecuta en la siguiente barra si el precio vuelve a ese nivel. Esto es:
		- Más conservador que Market
		- Más realista
		- Evita perseguir precio
	
	📉 Simétrico para entradas en corto
	
	🛑 Salidas por pérdida de Momentum
	Mom está cayendo durante 3 barras consecutivas. No necesitamos: Stop o Target fijos
	Salimos cuando el impulso se debilita.
	
	👉“Entro cuando aparece impulso limpio y salgo cuando ese impulso se deteriora”
}