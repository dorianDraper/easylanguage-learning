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
		AccountRiskCore(
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