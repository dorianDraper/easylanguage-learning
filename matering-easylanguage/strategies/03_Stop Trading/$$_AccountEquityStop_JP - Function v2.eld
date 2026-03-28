{-------------------------------------------------------------------
 v2.0 - Updated version of the AccountEquityStop function with improved structure and comments.
 AccountEquityStop Function

 Description:
 Evaluates whether daily account P&L is within allowed limits.

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
	AccountEquityStop_JP = True
Else
	AccountEquityStop_JP = False;