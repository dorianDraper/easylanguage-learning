{-------------------------------------------------------------------
 Intermarket Filtered Trend Breakout Strategy v1

 Description:
 Multi-data trend breakout strategy that trades the primary market only when 
 correlated / inversely correlated secondary markets confirm the expected regime.

 Core Features:
    - Trend filter via moving averages
    - Donchian-style breakout entries
    - Intermarket confirmation filters
    - Skip-next-signal logic after loss streak
    - Profit-based re-entry / pyramiding
    - ATR trailing stop
    - Regime-based forced exits

 Data Assumptions:
    Data1 = Primary Market (e.g. DAX / NQ)
    Data2 = Currency Filter (e.g. EURUSD)
    Data3 = Bond Filter (e.g. Bund / US20Y)
 
 Possible timeframes: 
 	> DAX --> 15MIN
 	> EURUSD --> 4H 
 	> BUND --> 1D  
-------------------------------------------------------------------}

Inputs:
	ChannelLen(20),
	StopATR(2),
	FastLen(10),
	SlowLen(50),
	BondCorr(-1),
	CurrencyCorr(-1),
	ProfitReentry(500);

Vars:
	sgLong(False),
	sgShort(False),
	filterLong(False),
	filterShort(False),
	tgLong(0),
	tgShort(0),
	flagSaltar(True),
	continuousLosses(0),
	totalTradesAnt(0),
	ATR(0),
	amountSL(0),
	stopLoss(0);

If TotalTrades > totalTradesAnt Then
Begin
	
	If PositionProfit(1) < 0 Then
		Begin
			
			continuousLosses = continuousLosses + 1;
			flagSaltar = True;
			
		End	Else
			continuousLosses = 0;
			
End;

// Guardamos el número de trades de la vela anterior
totalTradesAnt = TotalTrades;

// Calculamos precios de stops de entrada
tgLong = Highest(High, ChannelLen);
tgShort = Lowest(Low, ChannelLen);

// Calculamos las señales 
sgLong = Average(Close, FastLen) > Average(Close, SlowLen);
sgShort = Average(Close, FastLen) < Average(Close, SlowLen);

// Filtros: o bien corr = 0, o bien se cumplen las corr especificadas
filterLong = (CurrencyCorr = 0) 
			 or (Close of Data2 > Average(Close of Data2, SlowLen) and CurrencyCorr = 1) 
			 or (Close of Data2 < Average(Close of Data2, SlowLen) and CurrencyCorr = -1);

filterLong = filterLong 
			 and ((BondCorr = 0) or (Close of Data3 > Average(Close of Data3, SlowLen) and BondCorr = 1)
			 or (Close of Data3 < Average(Close of Data3, SlowLen) and BondCorr = -1));

filterShort = (CurrencyCorr = 0)
			  or (Close of Data2 < Average(Close of Data2, SlowLen) and CurrencyCorr = 1)
			  or (Close of Data2 > Average(Close of Data2, SlowLen) and CurrencyCorr = -1);

filterShort = filterShort
			  and ( (BondCorr = 0) or (Close of Data3 < Average(Close of Data3, SlowLen) and BondCorr = 1)
			  or (Close of Data3 > Average(Close of Data3, SlowLen) and BondCorr = -1));

If MarketPosition = 0 Then
Begin

	If sgLong and filterLong Then
	Begin
		
		If continuousLosses >= 3 and flagSaltar Then
		Begin
			flagSaltar = False;
		End Else
			Begin 
				Buy ("Long") Next Bar tgLong Stop;
				flagSaltar = True;
			End;
	End;
	
	If sgShort and filterShort Then
	Begin
		
		If continuousLosses >= 3 and flagSaltar Then
		Begin
			flagSaltar = False;
		End Else
			Begin
				SellShort ("Short") Next Bar tgShort Stop;
				flagSaltar = True;
			End;
	End;
	
End Else
Begin

	If OpenPositionProfit > ProfitReentry Then
	Begin
		
		If MarketPosition = 1 Then
			Buy ("LongReentry") Next Bar at Market;
		If MarketPosition = -1 Then
			SellShort ("ShortReentry") next Bar at Market;
	
	End;
	//
	If MarketPosition = 1 and filterShort Then
		Sell ("FilterLongExit") Next Bar at Market;
	
	If MarketPosition = -1 and filterLong Then
		BuyToCover ("FilterShortExit") Next Bar at Market;
	
	// Trail Stop
	ATR = AvgTrueRange(SlowLen);
	amountSL = StopATR * ATR;
	If BarsSinceEntry = 0 Then
		stopLoss = EntryPrice - MarketPosition * amountSL;
	
	If MarketPosition = 1 Then
		Begin
			stopLoss = MaxList(stopLoss, Close - amountSL);
			Sell ("LongStopLoss") Next Bar stopLoss Stop;
		End;
	
	If MarketPosition = -1 Then
		Begin
			stopLoss = MinList(stopLoss, Close + amountSL);
			BuyToCover ("ShortStopLoss") Next Bar stopLoss Stop;
		End;	

End;