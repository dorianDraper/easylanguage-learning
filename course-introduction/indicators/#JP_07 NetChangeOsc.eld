{	Este indicador traza un oscilador de cambio neto de 5 barras.
}

Vars: NetChangeOsc(0);

NetChangeOsc = Close - Close[5];

Plot1(NetChangeOsc, "NCO");
Plot2(0, "0");

{	>Este es un indicador de Momentum que indica el cambio neto (cierre).
	>En nuestro caso indica el cierre actual menos el cierre de 5 barras atrás
}