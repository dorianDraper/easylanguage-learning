// Mejora de las anteriores versiones con foco en legibilidad, intención semántica y preparación para futuras extensiones. 
// Añadimos gestión de riesgo, análisis posterior y mejoramos la claridad del código.

Input:
	BuyLen(8),
	SellLen(8),
	StopPoints(.02),
	StopAmt(.2),
	TargetAmt(.3),
	BEAmt(.15);

Vars:
	BuyBrk(0),
	SellBrk(0);

BuyBrk = Highest(High, BuyLen) + StopPoints;
SellBrk = Lowest(Low, SellLen) - StopPoints;

{Setup de entrada}
Buy ("BrkLE") Next Bar at BuyBrk Stop;
SellShort ("BrkSE") Next Bar at SellBrk Stop;

{Setup de salida}
SetStopShare;

SetStopLoss(StopAmt);
SetProfitTarget(TargetAmt);
SetBreakeven(BEAmt);

{	🧠 Resumen mental
	“El mercado lleva varias barras moviéndose dentro de un rango.
	Si rompe con decisión ese rango, quiero subirme al movimiento.
	Si me equivoco, pierdo poco. Si va a favor, aseguro break-even 
	y busco un objetivo definido.”

	👉 BuyLen/SellLen = inputs configurables, ventanas de breakout.
	StopPoints(.02) = filtro que se añade/resta al nivel de ruptura. Evita 
	ejecuciones por toques exactos o ruido.
	
	Tomamos el High/Low más alto de las últimas BuyLen/SellLen barras
	Este será el precio stop de compra/venta
	
	👉 No usamos [1] porque:
		Queremos incluir la barra actual
		La orden se ejecuta en la siguiente barra
		Las órdenes stop ya son condicionales por naturaleza
	
	🚀 Setup de entrada
	No hay IF, las órdenes están siempre activas, solo se ejecutan si el precio alcanza el nivel. Esto es correcto porque:
		- Una orden Stop ya es una condición
		- Si el precio no rompe → no hay trade
	
	🛑 Gestión de salidas
	SetStopShare = Activamos stops por acción
	Todos los valores (StopAmt, TargetAmt, BEAmt)se interpretan por acción / contrato, no por trade total
	🔻 Stop Loss == Si el trade pierde 0.2 → se cierra automáticamente
	🎯 Profit Target == Si el trade gana 0.3 → se cierra automáticamente
	🔐 Break Even
		Cuando el trade alcanza +0.15
		El stop se mueve al precio de entrada	
		El trade ya no puede perder	
}