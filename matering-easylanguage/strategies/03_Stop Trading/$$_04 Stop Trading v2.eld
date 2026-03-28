{-------------------------------------------------------------------
 Version: 2.0
 Account Risk Gate Controller

 Description:
 Controls whether trading is allowed based on daily account P&L.
 Acts as a wrapper around any strategy.

-------------------------------------------------------------------}

Inputs:
	MaxDailyLoss(5000),
	MaxDailyProfit(5000);

Vars:
	IsLong(false),
	IsShort(false),

	AccountTradingAllowed(true),
	DailyNetPL(0),

	RiskTriggered(false);   // latch


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

{
🧠 This is an account-level risk gate controller that can be used as a wrapper around
any trading strategy. It evaluates the daily P&L of the account in real-time and disables
all trading activity if the P&L exceeds predefined loss or profit thresholds. Once triggered,
the risk gate remains latched off for the rest of the day, ensuring that no further trades are
executed. This is a powerful tool for protecting capital and enforcing risk management rules at the account
level.
}