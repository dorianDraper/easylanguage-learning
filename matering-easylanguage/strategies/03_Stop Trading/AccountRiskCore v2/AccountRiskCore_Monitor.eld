{-------------------------------------------------------------------
AccountRiskCore_Monitor - Indicator

Updated version of AccountRiskCore_Monitor in AccountRiskCore v1, now using AccountRiskCore_Function for core logic.
-------------------------------------------------------------------}

Inputs:
	AccountNumber(""),
	MaxDailyLoss(5000),
	MaxDailyProfit(5000);

Vars:
	DailyNetPL(0),
	WithinLimits(false),
	TradingAllowed(false);


TradingAllowed =
	AccountRiskCore_Function(
		MaxDailyLoss,
		MaxDailyProfit,
		AccountNumber,
		DailyNetPL,
		WithinLimits);


Plot1(DailyNetPL, "Daily P&L");
Plot2(-MaxDailyLoss, "Max Loss");
Plot3(MaxDailyProfit, "Max Profit");

If WithinLimits Then
	SetPlotColor(1, Green)
Else
	SetPlotColor(1, Red);