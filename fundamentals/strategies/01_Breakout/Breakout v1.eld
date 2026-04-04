{-------------------------------------------------------------------	
 Breakout v1 

 Description:
 - Breakout strategy based on the highest high and lowest low of the last 8 bars
 - Uses stop orders to enter the market on breakouts
 
-------------------------------------------------------------------}

Input:
	TrlgBars(8);

Vars:
	BuyPx(0),
	SellPx(0);

BuyPx = Highest(High, TrlgBars) + .02;
SellPx = Highest(Low, TrlgBars) - .02;

{Setup entrada}
Buy ("BrkLE") Next Bar at BuyPx Stop;
SellShort ("BrkSE") Next Bar at SellPx Stop;

{	⏱ TrlgBars()
        Define cuántas barras hacia atrás se usan para calcular el rango de ruptura (8). 	
        Quiero buscar rupturas del máximo/mínimo de las últimas 8 velas.
	
	🚀 BuyPx/SellPx
        Guardan los niveles de precio donde se colocarán las órdenes stop. Se recalculan en cada barra. 
        +-.02 añade/resta un pequeño buffer para evitar ejecuciones falsas justo en el nivel
	
    👉 NO se usa [1], porque 
        Las órdenes stop se colocan para la próxima barra, no para la barra actual.
		La orden se ejecuta en la siguiente barra, el cálculo se hace al cierre de la barra actual
        El cálculo ocurre ahora, la orden se coloca para la próxima barra. La orden NO se ejecuta inmediatamente
        
	
	📈 Solo se ejecuta si: El precio sube/baja y rompe el nivel BuyPx/SellPx, es una estrategia de continuación / momentum
	
	🔍 ¿Qué pasaría si usáramos [1]?
        Estaríamos calculando un nivel potencialmente obsoleto, nos perderíamos 
        rupturas que se están formando ahora mismo. El stop quedaría más lejos 
        del mercado real. En estrategias de breakout, eso no es deseable.
}
{   🎯 Criterios de mejora
        El objetivo NO es “hacerlo más complejo”, sino: mejorar legibilidad, mejorar intención semántica y facilitar extensión futura
        Ejemplos:
        Nombrar mejor variables (precio vs condición).
        Agrupar lógica por bloques claros.
        Preparar el código para:
            filtros
            gestión de riesgo
            análisis posterior
}