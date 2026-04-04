{-------------------------------------------------------------------
AccountEquityMonitor - Indicator
-------------------------------------------------------------------}

Inputs:
	AccountNumber(""),
	MaxDailyLoss(5000),
	MaxDailyProfit(5000);

Vars:
	BDAccountEquity(0),
	CurrentAccountEquity(0),
	DailyNetPL(0),
	WithinLimits(false);

// Equity inicio del día 
BDAccountEquity = GetBDAccountNetWorth(AccountNumber);

// Equity actual (real-time)
CurrentAccountEquity = GetRTAccountNetWorth(AccountNumber);

// P&L diario
DailyNetPL = CurrentAccountEquity - BDAccountEquity;

// Evaluación de límites
WithinLimits = 
	DailyNetPL > - MaxDailyLoss
	and DailyNetPL < MaxDailyProfit;

// Plots
Plot1(DailyNetPL, "Daily P&L");
Plot2(- MaxDailyLoss, "Max Loss");
Plot3(MaxDailyProfit, "Max Profit");
//Plot4(0, "0");

// Colores condicionales
If WithinLimits Then
	SetPlotColor(1, Green)
Else
	SetPlotColor(1, Red);  
	

{ Colores explícitos
SetPlotColor(1, Darkgreen);        // Daily P&L
SetPlotColor(2, Darkred);    // Max Loss
SetPlotColor(3, Cyan);    // Max Profit
SetPlotColor(4, Darkgray);    // Zero line  }