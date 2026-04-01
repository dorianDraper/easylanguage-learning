{-------------------------------------------------------------------
 Account Equity Risk Gate with Kill Switch v2.0
 
 Improvements over v1.0:
 	- Added a latch mechanism to ensure that once the risk gate is triggered, it remains off for the rest of the day.
 	- Cleaned up logic for better readability and reliability.
 	- Ensures that all open positions are closed immediately when the risk gate is triggered.

-------------------------------------------------------------------}

Inputs:
	MaxDailyLoss(5000),
	MaxDailyProfit(5000);

Vars:
	IsLong(false),
	IsShort(false),

	AccountTradingAllowed(true),
	DailyNetPL(0),

	RiskTriggered(false);   // latch to keep track of whether risk gate has been triggered during the day

{--------------------------------------------------
 Position state
--------------------------------------------------}
IsLong  = MarketPosition = 1;
IsShort = MarketPosition = -1;

{--------------------------------------------------
 Evaluate account risk (real-time only)
--------------------------------------------------}
If LastBarOnChart Then
Begin

	AccountTradingAllowed =
		AccountEquityStop_JP(
			MaxDailyLoss,
			MaxDailyProfit,
			GetAccountID,
			DailyNetPL);

	{ Latch: once triggered, remain disabled }
	If not AccountTradingAllowed Then
		RiskTriggered = True;

End;

{--------------------------------------------------
 Apply latched state
--------------------------------------------------}
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
 Strategy execution
--------------------------------------------------}
If AccountTradingAllowed Then
Begin
	// Strategy logic here
End;
