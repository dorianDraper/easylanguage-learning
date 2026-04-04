{-------------------------------------------------------------------
 AccountRiskCore_Strategy_v2

 This strategy demonstrates how to use the updated AccountRiskCore_Function_v2 to implement an equity 
 risk gate with a kill switch. The strategy evaluates the daily net profit/loss against 
 specified limits and disables trading if those limits are breached.

-------------------------------------------------------------------}

Inputs:
	MaxDailyLoss(5000),
	MaxDailyProfit(5000);

Vars:
	IsLong(false),
	IsShort(false),

	AccountTradingAllowed(true),
	DailyNetPL(0),
	WithinLimits(false),

	RiskTriggered(false);

{--------------------------------------------------
 State
--------------------------------------------------}
IsLong  = MarketPosition = 1;
IsShort = MarketPosition = -1;

{--------------------------------------------------
 Risk evaluation
--------------------------------------------------}
If LastBarOnChart Then
Begin

	AccountTradingAllowed =
		AccountRiskCore_Function_v2(
			MaxDailyLoss,
			MaxDailyProfit,
			GetAccountID,
			DailyNetPL,
			WithinLimits);

	If not AccountTradingAllowed Then
		RiskTriggered = True;

End;


If RiskTriggered Then
	AccountTradingAllowed = False;

{--------------------------------------------------
 Kill switch
--------------------------------------------------}
If not AccountTradingAllowed Then
Begin
	If IsLong Then
		Sell ("AcctStop_LX") This Bar on Close;

	If IsShort Then
		BuyToCover ("AcctStop_SX") This Bar on Close;
End;

{--------------------------------------------------
 Strategy layer
--------------------------------------------------}
If AccountTradingAllowed Then
Begin
	// Strategy here
End;