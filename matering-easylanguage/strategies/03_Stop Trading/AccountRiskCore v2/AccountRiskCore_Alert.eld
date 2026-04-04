{-------------------------------------------------------------------
AccountRiskCore_Alert - Indicator

Updated version of AccountRiskCore_Alert in AccountRiskCore v1, now using AccountRiskCore_Function for core logic.
-------------------------------------------------------------------}

Inputs:
	AccountNumber(""),
	MaxDailyLoss(5000),
	MaxDailyProfit(5000);

Vars:
	DailyNetPL(0),
	WithinLimits(false),
	TradingAllowed(false);


If LastBarOnChart Then
Begin

	TradingAllowed =
		AccountRiskCore_Function(
			MaxDailyLoss,
			MaxDailyProfit,
			AccountNumber,
			DailyNetPL,
			WithinLimits);

	If not TradingAllowed Then
		Alert;

End;


Plot1(DailyNetPL, "Daily P&L");
Plot2(0, "Zero");
Plot3(-MaxDailyLoss, "Max Loss");
Plot4(MaxDailyProfit, "Max Profit");

If not WithinLimits Then
	SetPlotColor(1, Red);