{-------------------------------------------------------------------
    EPS Trend Up Long Entry v2

    Description:
    - Improved version of the EPS Trend Up Long Entry strategy.
    - Added more robust data validation and clearer variable naming.

-------------------------------------------------------------------}

Input:
	StructuralLookback(26);			// Medio año bursátil (~6 meses)
	
Vars:
	EPSCurr(0),						// Último earnings report
	EPSPrev(0),						// Anterior earnings report
	EPSReleaseDate(0),				// Fecha report
	
	EPSImproving(False),			// Earnings mejoran
	NewEPSReleased(False),			// Hay nuevo report
	StructuralTrendFailure(False),	// Tendencia falla (miramos ~6 meses atrás)	
	
	FundamentalOK(False),			// Condiciones para operar
	PriceMomentum(False),
	
	ErrorEPS(0),					// Validamos calidad del dato
	ErrorEPSPrev(0),
	ErrorDate(0);

// ─── FUNDAMENTAL DATA ─────────────────────────────
EPSCurr = FundValue("SBBF", 0, ErrorEPS);
EPSPrev = FundValue("SBBF", 1, ErrorEPSPrev);
EPSReleaseDate = JulianToDate(FundDate("SBBF", 0 , ErrorDate));

// Solo operamos si todos los datos fundamentales son válidos
FundamentalOK= 	
	ErrorEPS = 0 and 
	ErrorEPSPrev = 0 and 
	ErrorDate = 0;

If FundamentalOK Then
Begin
	// Beneficios mejoran
	EPSImproving = EPSCurr > EPSPrev;
	
	// Hoy hay nuevo earnings disponible
	NewEPSReleased = EPSReleaseDate >= Date;
End;

// ─── PRICE MOMENTUM ─────────────────────────────
// El precio rompe el máximo de los últimos 5 días
PriceMomentum = 
	High > Highest(High, 5)[1];

// ─── ENTRY ──────────────────────────────────────
If MarketPosition = 0 and 
	FundamentalOK and 
	EPSImproving and 
	PriceMomentum Then
		Buy ("MO_EPS_Long") Next Bar at Market;

// ─── TRADE MANAGEMENT ───────────────────────────
// El mercado rompe la estructura alcista de largo plazo
StructuralTrendFailure = Low < Lowest(Low, StructuralLookback)[1];

// Gestión mientras estamos largos
If MarketPosition = 1 Then
Begin
	// Fundamental deterioration (earnings decepcionan)
	If NewEPSReleased and Not EPSImproving Then
		Sell ("EPS_Down") This Bar on Close;
	
	// Structural trend failure (tendencia muere)
	If StructuralTrendFailure Then 
		Sell ("6M_Low") This Bar on Close;
End;

// ─── COMMENTARY ─────────────────────────────────
Commentary("EPS", EPSCurr, "PrevEPS", EPSPrev);
Commentary("NewEPS", NewEPSReleased);
