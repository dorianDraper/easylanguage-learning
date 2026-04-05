{-------------------------------------------------------------------	
 Breakout v2

 Description:
 - Improve legibility and semantic intention of Breakout v1
 - Prepare code for future extensions (filters, risk management, post-analysis)
-------------------------------------------------------------------}

Inputs:
	LongPrice(High),
	LongLen(8),
	ShortPrice(Low),
	ShortLen(8),
	EntryBuffer(.02);

Vars:
	LongBreakout(0),
	ShortBreakout(0);

{🧮 Cálculo de niveles de ruptura}
LongBreakout = Highest(LongPrice, LongLen) + EntryBuffer;
ShortBreakout = Lowest(ShortPrice, ShortLen) - EntryBuffer;

{🚀 Setup de entrada}
Buy ("Brk LE") Next Bar at LongBreakout Stop;
SellShort ("Brk SE") Next Bar at ShortBreakout Stop;
