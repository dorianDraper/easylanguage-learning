Inputs:
    // Límites de pérdida y ganancia diaria
	MaxDailyLoss(5000),
	MaxDailyProfit(5000);
	
Vars:
    // Control de permisos a nivel de cuenta
	AccountTradingAllowed(false),
    // P&L diario
	DailyNetPL(0),
    // Estado de la posición
	IsLong(false),
	IsShort(false);

// State machine básica
IsLong = MarketPosition = 1;
IsShort = MarketPosition = -1;

// Evaluación de la cuenta (solo en barra viva)
If LastBarOnChart Then
    // Evaluamos si la cuenta puede seguir operando, llamada a la función que implementa la lógica de stop a nivel de cuenta
	AccountTradingAllowed = 
		AccountEquityStop_JP(
			MaxDailyLoss,
			MaxDailyProfit,
			GetAccountID,
			DailyNetPL)
Else
    // En barras históricas, asumimos que la cuenta podía operar (para backtesting)
	AccountTradingAllowed = True;

{ La función devuelve True si la cuenta puede seguir operando, False si se ha alcanzado el límite de pérdida o ganancia diaria }

// Account-level kill switch
// Si la cuenta no puede operar, cerramos cualquier posición abierta a mercado
If not AccountTradingAllowed Then
Begin
	If IsLong Then
	Sell ("AcctStop_LX") Next Bar at Market;
	
	If IsShort Then
	BuyToCover ("AcctStop_SX") Next Bar at Market;
End;

// Estrategia principal
If AccountTradingAllowed Then
Begin
	// Estrategia que queramos emplear
End;

{
🧠Esta NO es una estrategia, es un control de permisos a nivel de cuenta.
La estrategia real vive “dentro”. Si la cuenta no puede operar → nada más importa

El código implementa un "account-level kill switch" que detiene toda la actividad de trading en la 
cuenta si se alcanza un nivel de pérdida o ganancia diaria predefinido.

Esta estrategia está relacionada con la función AccountEquityStop_JP, demuestra 
su utilidad al evitar nuevas órdenes de entrada del sistema cuando se alcanza un 
beneficio o pérdida sobre la cuenta. La estrategia también cierra cualquier posición
existente a mercado una vez se alcanza el nivel de stop de la cuenta.
}