{	Este indicador traza la media de 10 barras de la diferencia entre el Close
	y el Open de cada una de ellas, tal y como se hizo en #04 Real Body
}

Input:
	Length(10);

Vars:
	RealBody(0),
	AvgRealBody(0);

RealBody = Close - Open;
AvgRealBody = Average(RealBody, Length);

Plot1(AvgRealBody, "AvgRB");
Plot2(0, "Zero");

{	🧠 Este indicador mide el tamaño medio del cuerpo real de las velas durante las últimas Length barras, y lo representa alrededor de una línea cero.
	🧩 Sirve para responder a preguntas como:
		>>¿Predominan cuerpos alcistas o bajistas?
		>>¿La presión compradora o vendedora está aumentando o disminuyendo?
		>>¿El mercado está ganando o perdiendo impulso direccional?
	🔍 Clave conceptual
		- Si Close > Open → cuerpo positivo → vela alcista.
		- Si Close < Open → cuerpo negativo → vela bajista.
		- Si Close ≈ Open → cuerpo pequeño → indecisión.
	👉 Esta variable "AvgRealBody = Average(RealBody, Length)" significa:
	“En promedio, ¿los cuerpos recientes son alcistas o bajistas?”
		AvgRealBody > 0 → presión compradora dominante.
		AvgRealBody < 0 → presión vendedora dominante.
		Cerca de 0 → mercado equilibrado / lateral.
	👉 Qué NO es este indicador
		No es un RSI
		No mide sobrecompra/sobreventa
		No da señales de entrada por sí solo
		Es un indicador de contexto, muy útil como filtro.
}