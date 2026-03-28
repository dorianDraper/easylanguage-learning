Inputs:
	AccountNumber(""),
	MaxDailyLoss(5000),
	MaxDailyProfit(5000);

Vars:
	BDAccountEquity(0),
	CurrentAccountEquity(0),
	DailyNetPL(0),
	WithinLimits(false);

{⚠️ Solo ejecutar en la última barra visible}
If LastBarOnChart Then
Begin
	// Equity inicio del día
	BDAccountEquity = GetBDAccountNetWorth(AccountNumber);

	// Equity actual
	CurrentAccountEquity = GetRTAccountNetWorth(AccountNumber);

	// P&L diario
	DailyNetPL = CurrentAccountEquity - BDAccountEquity;

	// Evaluación de límites
	WithinLimits =
		DailyNetPL > -MaxDailyLoss
		and DailyNetPL <  MaxDailyProfit;

	// Alerta operativa
	If not WithinLimits Then
		Alert;
End;

// Plots (estado presente)
Plot1(DailyNetPL, "Daily P&L");
Plot2(0, "Zero");
Plot3(-MaxDailyLoss, "Max Loss");
Plot4(MaxDailyProfit, "Max Profit");

// Estado crítico
If not WithinLimits Then
	SetPlotColor(1, Red);

{🎨 Colores explícitos
SetPlotColor(1, Olive);
SetPlotColor(2, Gainsboro);
SetPlotColor(3, IndianRed);
SetPlotColor(4, RoyalBlue);}