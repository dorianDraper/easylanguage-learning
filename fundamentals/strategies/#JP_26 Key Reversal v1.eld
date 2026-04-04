{	Key Reversal al alza y a la	baja para identificar puntos de entrada:
	> Orden limitada comprar en la barra siguiente a una barra Key Reversal al alza. Precio limitado mejor que el cierre de la barra actual.
	> Orden limitada vender al descubierto en la barra siguiente a una barra Key Reversal a la baja. Precio limitado mejor que el cierre de la barra actual.
	Input: número puntos por encima o por debajo del cierre de la barra Key Reversal con el que fijaremos el precio de las órdenes limitadas
	(5 puntos por defecto).
}

Input:
	LimitPoints(.05);

Vars:
	BullKeyRev(false),
	BearKeyRev(false);

BullKeyRev = Low < Low[1] and Close > Close[1];
BearKeyRev = High > High[1] and Close < Close[1];

{Setup de entrada}
If BullKeyRev Then
	Buy Next Bar at Close of This Bar - LimitPoints Limit;
If BearKeyRev Then
	SellShort Next Bar at Close of This Bar + LimitPoints Limit;

{	🧠 Un Key Reversal es una vela que:
		Hace un nuevo extremo respecto a la vela anterior pero cierra en dirección contraria
	👉 Indica que el mercado intentó continuar, fracasó, y entró fuerza en sentido opuesto.
        Es una señal de posible giro (no confirmación, sino advertencia).
	
	🔄 Bull Reversal
	- El mercado rompe mínimos → parece bajista
	- Pero entra compra fuerte → cierre más alto
	- Rechazo del movimiento bajista
	📈 Señal de posible reversión alcista:
		- La vela actual confirma el Key Reversal
		- Se coloca una orden limit
		- El precio de la orden es: Cierre actual - LimitPoints	
		- La orden se ejecuta en la siguiente barra
		👉 Buscamos mejorar el precio, esperando un pequeño retroceso.
	
	🔄 Bear Reversal
	- Intento de continuar subiendo
	- Fallo
	- Entrada de venta
	📉 Señal de posible reversión bajista
		- Colocamos la venta ligeramente por encima del cierre
		- Esperamos un pequeño pullback
		- Entramos si el mercado lo concede
	
	
}