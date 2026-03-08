{	Este indicador traza una línea que conecta el precio medio de cada barra.
}

Vars: MidPrice(0);

MidPrice = (High + Low)*.5;

Plot1(MidPrice, "MidPrice");