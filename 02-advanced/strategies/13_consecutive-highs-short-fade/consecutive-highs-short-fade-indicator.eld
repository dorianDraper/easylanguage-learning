{-------------------------------------------------------------------
    Consecutive Highs Short Fade Indicator
    - Identifies when the price has made a specified number of consecutive highs.
    - Generates a "Sell" signal when the condition is met, indicating a potential short fade opportunity.
    
-------------------------------------------------------------------}

Inputs:
	Price(High),
	ConsecutiveBarsUp(3);

Vars:
	PlotTxt(""),
	UpCount(0);

If Price > Price[1] Then
	UpCount = UpCount + 1
Else
	UpCount = 0;

If UpCount >= ConsecutiveBarsUp Then 
Begin
	PlotTxt = "Sell";
	SetPlotBGColor(1, Darkred);
	SetPlotColor(1, White);
	Alert;
End 
Else
	PlotTxt = Numtostr(UpCount, 0);

Plot1(PlotTxt, "Sell");
