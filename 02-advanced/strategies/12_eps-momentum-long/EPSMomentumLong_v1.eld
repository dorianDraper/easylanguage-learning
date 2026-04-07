{-------------------------------------------------------------------
    EPS Trend Up Long Entry v1

    Description:
    - Long entry strategy based on EPS trend and short-term momentum.
    - Buy when EPS is improving and the stock shows short-term bullish momentum.
    Exit rules:
    - Exit if a new earnings report is released with a negative EPS trend.
    - Exit if the stock makes a new 6-month low (26 weeks) excluding today.
    
-------------------------------------------------------------------}

Vars:
	EPSVal(0),
	EPSPrevVal(0),
	EPSReportDate(0),
	
	EPSInc(False),
	EPSDateToday(False),
	DataOK(False),
	DataOKPrev(False),
	DateDataOK(False),
	
	oErrorCode(0);

// ─── TEXT ───────────────────────────────────
DataOK = True;
DataOKPrev = True;
DateDataOK = True;

EPSInc = False;
EPSDateToday = False;

// EPS actual y validación errores
EPSVal = FundValue("SBBF", 0, oErrorCode);

If oErrorCode > 0 Then
	DataOK = False;

// EPS anterior
EPSPrevVal = FundValue("SBBF", 1, oErrorCode);

If oErrorCode > 0 Then
	DataOKPrev = False;

// Fecha último earnings report
EPSReportDate = Juliantodate(FundDate("SBBF", 0, oErrorCode) );

If oErrorCode > 0 Then
	DateDataOK = False;

// Nuevo release de report
EPSDateToday = EPSReportDate > Date[1];

// ─── TEXT ───────────────────────────────────
// EPS creciente
If EPSVal > EPSPrevVal Then
	EPSInc = True;

If DataOK and DataOKPrev and DateDataOK Then
Begin
	// Si EPS mejora y momentum alcista a corto plazo → compramos
	If EPSInc and High > High[4] and High[1] > High[5] Then
		Buy ("MO & EPS") Next Bar at Market;
	
	// Mientras estemos largos
	If MarketPosition = 1 Then
	Begin
		// Exit fundamental → nuevo earnings report negativo
		If EPSDateToday and EPSInc = False Then
			Sell ("EPSDN") This Bar on Close;
		// Exit técnico → nuevo mínimo semestral (26 semenas) sin contar hoy
		If Low < Lowest(Low, 26)[1] Then
			Sell ("LowerLow") This Bar on Close;
	End;
End;

// ─── ANALYSIS COMMENTARY ───────────────────────────────────
Commentary("Date", EPSReportDate, "Earnings", EPSVal);
Commentary("Flag", EPSInc, "PrevEarnings", EPSPrevVal);