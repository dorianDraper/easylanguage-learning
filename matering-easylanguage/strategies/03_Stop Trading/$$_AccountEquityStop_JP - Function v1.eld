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
	AccountEquityStop_JP = True   // trading permitido
Else
	AccountEquityStop_JP = False; // trading bloqueado

{
🧠 Esta función es un "account-level kill switch" que se puede usar dentro de cualquier estrategia 
para controlar si la cuenta puede seguir operando o no en función del P&L diario. Si el P&L diario 
supera los límites definidos, la función devuelve False, lo que indica que se debe detener toda la 
actividad de trading en la cuenta. Esto es especialmente útil para proteger el capital y evitar 
pérdidas excesivas o asegurar ganancias cuando se alcanzan ciertos objetivos.
}

