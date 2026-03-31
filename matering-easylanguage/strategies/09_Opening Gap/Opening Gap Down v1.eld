{-------------------------------------------------------------------
Versión 1 - Gap Down según manual y vídeo
-------------------------------------------------------------------}

Inputs:
	//Tamaño mínimo gap bajista, importancia significativa del gap
	GapTest( Median(Range, 50)[1] ),
	//Precio actual de la barra para usarlo en cálculo gap
	GapPrice(Low);

Vars:
	//Tamaño gap actual 
	Gap(0),
	//Cantidad profit target
	GapExitPxPT(0),
	//Cantidad stop loss
	GapExitPxSL(0);

// Setup de entrada
If Date of Next Bar <> Date and Open of Next Bar < GapPrice - GapTest Then
Begin
	Buy ("GAP LE") Next Bar at Market;
	Gap = GapPrice - Open Next Bar; 
End;

// Setup de salida
If MarketPosition = 1 Then
Begin
	GapExitPxPT = EntryPrice + Gap; //Buscamos profit si cubre el gap
	GapExitPxSL = EntryPrice - GapTest; 
	Sell ("Filled LX") Next Bar at GapExitPxPT Limit;
	Sell ("Stop LX") Next Bar at GapExitPxSL Stop;
	SetExitOnClose; //Caso que no haya ejecutado profit target o stop loss 
End;