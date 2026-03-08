{	Este indicador traza la diferencia entre el Close y el Open de cada barra.
	Este valor dará positivo si el Close es mayor que el Open, y un valor negativo
	si el Close es menor que el Open. Esto corresponde al Real Body, verde o rojo,
	de un chart de velas.
}
// La forma sin Vars sería Plot1(Close - Open, "RealBody")

Vars: 
	RealBody(0);

RealBody = Close - Open;

Plot1(RealBody, "RealBody");
Plot2(0, "Doji");