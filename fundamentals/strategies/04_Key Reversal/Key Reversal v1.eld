{-------------------------------------------------------------------	
 Key Reversal v1
 
 Description:
 - Identifies potential key reversal patterns in the market.
 - A key reversal occurs when the price makes a new high or low compared to the previous bar but closes in the opposite direction, indicating a potential reversal in market sentiment.
 
-------------------------------------------------------------------}

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