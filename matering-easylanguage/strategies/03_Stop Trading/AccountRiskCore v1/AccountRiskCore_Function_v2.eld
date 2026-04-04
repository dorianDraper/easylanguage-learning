{-------------------------------------------------------------------
 AccountRiskCore_Function_v2

 Description:
 Updated version of the AccountRiskCore_Function_v1 with improved structure and comments.

 Returns:
    True  -> trading allowed
    False -> trading blocked

 Outputs:
    oDailyNetPL -> current daily P&L

-------------------------------------------------------------------}

Inputs:
	MaxDailyLoss(numeric),
	MaxDailyProfit(numeric),
	AccountID(string),
	oDailyNetPL(numericref);

Vars:
	BeginDayEquity(0),
	CurrentEquity(0),
	ComputedDailyPL(0);

{--------------------------------------------------
 Retrieve account equity
--------------------------------------------------}
BeginDayEquity = GetBDAccountNetWorth(AccountID);
CurrentEquity  = GetRTAccountNetWorth(AccountID);

{--------------------------------------------------
 Compute daily P&L
--------------------------------------------------}
ComputedDailyPL = CurrentEquity - BeginDayEquity;
oDailyNetPL     = ComputedDailyPL;

{--------------------------------------------------
 Evaluate limits
--------------------------------------------------}
If (ComputedDailyPL > -MaxDailyLoss) and
   (ComputedDailyPL <  MaxDailyProfit) Then
	AccountRiskCore_Function_v2 = True
Else
	AccountRiskCore_Function_v2 = False;