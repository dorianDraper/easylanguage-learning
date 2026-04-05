{	Este indicador traza el Momentum de los precios de cierre de 10 barras.
}

Input:
	Price(Close),
	Length(10);

Vars: 
	Mom(0);

Mom = Momentum(Price, Length);

Plot1(Mom, "Momentum");
Plot2(0, "Zero");

{	>La función Momentum refleja un precio menos un precio anterior, la length que nosotros digamos
    >Momentum function calculates the change in momentum on the current bar relative to a specified number of bars ago.
}
{   >Si el Momentum es positivo, el precio actual es mayor que el precio de hace 10 barras, lo que indica una tendencia alcista.
    >Si el Momentum es negativo, el precio actual es menor que el precio de hace 10 barras, lo que indica una tendencia bajista.
    >Si el Momentum es cero, el precio actual es igual al precio de hace 10 barras, lo que indica una falta de tendencia o un mercado lateral.
}