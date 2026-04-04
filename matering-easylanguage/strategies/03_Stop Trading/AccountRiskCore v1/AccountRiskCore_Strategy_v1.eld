{-------------------------------------------------------------------
AccountRiskCore_Strategy_v1
 
 Description:
 	- Initial version of the account risk core strategy.
 	- Controls whether trading is allowed based on daily account P&L.
 	- Acts as a wrapper around any strategy.

-------------------------------------------------------------------}

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
		AccountRiskCore_Function_v1(
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
