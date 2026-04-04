{-------------------------------------------------------------------	
 Key Reversal v1
 
 Description:
 - Identifies potential key reversal patterns in the market.
 - A key reversal occurs when the price makes a new high or low compared to the previous bar but closes in the opposite direction, indicating a potential reversal in market sentiment.

-------------------------------------------------------------------}

Input:
	LimitPoints(.05);

Vars:
	BullKeyRev(false),
	BearKeyRev(false);

BullKeyRev = Low < Low[1] and Close > Close[1];
BearKeyRev = High > High[1] and Close < Close[1];

{Setup de entrada}
If BullKeyRev Then
	Buy Next Bar at Close of This Bar - LimitPoints Limit;
If BearKeyRev Then
	SellShort Next Bar at Close of This Bar + LimitPoints Limit;