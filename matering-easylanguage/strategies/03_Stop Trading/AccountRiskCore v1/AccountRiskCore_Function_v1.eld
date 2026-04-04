{-------------------------------------------------------------------
 AccountRiskCore_Function_v1 - v1.0

 Description:
 Evaluates whether daily account P&L is within allowed limits.

 Returns:
    True  -> trading allowed
    False -> trading blocked

 Outputs:
    oDailyNetPL -> current daily P&L

-------------------------------------------------------------------}


// Función de stop a nivel de cuenta basada en equity (P&L diario)
Inputs:
	MaxDailyLoss(numeric),
	MaxDailyProfit(numeric),
	AccountID(string),
	oDailyNetPL(numericref);

// Esta función evalúa el P&L diario de la cuenta y devuelve un booleano indicando si se permite seguir operando o no
Vars:
	BeginDayEquity(0),		
	CurrentEquity(0),	
	DailyNetPL(0);

// Equity de inicio del día
BeginDayEquity = GetBDAccountNetWorth(AccountID);

// Equity actual (real-time)
CurrentEquity = GetRTAccountNetWorth(AccountID);

// P&L diario
DailyNetPL = CurrentEquity - BeginDayEquity;
// Pasamos el P&L diario por referencia para que la estrategia pueda usarlo si lo desea
oDailyNetPL = DailyNetPL;

// Evaluación de límites
// Si el P&L diario está dentro de los límites permitidos, devolvemos True (se permite operar), si no, False (se bloquea el trading)
If DailyNetPL > -MaxDailyLoss
	and DailyNetPL <  MaxDailyProfit Then
	AccountRiskCore_Function_v1 = True   // trading permitido
Else
	AccountRiskCore_Function_v1 = False; // trading bloqueado
