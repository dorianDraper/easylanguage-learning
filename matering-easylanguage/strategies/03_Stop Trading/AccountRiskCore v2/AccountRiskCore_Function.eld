{-------------------------------------------------------------------
 AccountRiskCore_Function - Function

 Description:
 Centralized account risk evaluation function.

 Computes:
    - Daily Net P&L
    - Whether trading is allowed within defined limits

 Returns:
    True  -> trading allowed
    False -> trading blocked

 Outputs:
    oDailyNetPL   -> current daily P&L
    oWithinLimits -> boolean status

-------------------------------------------------------------------}

Inputs:
	MaxDailyLoss(numeric),
	MaxDailyProfit(numeric),
	AccountID(string),
	oDailyNetPL(numericref),
	oWithinLimits(truefalseref);

Vars:
	BeginDayEquity(0),
	CurrentEquity(0),
	ComputedPL(0);

{--------------------------------------------------
 Retrieve account equity
--------------------------------------------------}
BeginDayEquity = GetBDAccountNetWorth(AccountID);
CurrentEquity  = GetRTAccountNetWorth(AccountID);


{--------------------------------------------------
 Compute daily P&L
--------------------------------------------------}
ComputedPL   = CurrentEquity - BeginDayEquity;
oDailyNetPL  = ComputedPL;


{--------------------------------------------------
 Evaluate limits
--------------------------------------------------}
oWithinLimits =
	(ComputedPL > -MaxDailyLoss) and
	(ComputedPL <  MaxDailyProfit);


{--------------------------------------------------
 Return permission
--------------------------------------------------}
AccountRiskCore_Function = oWithinLimits;