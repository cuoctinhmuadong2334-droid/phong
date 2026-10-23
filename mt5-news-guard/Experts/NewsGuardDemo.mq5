//+------------------------------------------------------------------+
//| NewsGuardDemo.mq5                                                |
//| Shows News Guard status on the chart. Does NOT place any trades. |
//+------------------------------------------------------------------+
#property version     "1.00"
#property description "Shows News Guard status on the chart. Does not trade."

#include <NewsGuard.mqh>

//+------------------------------------------------------------------+
int OnInit()
  {
   NewsGuard_Verbose = true;   // print the event list in the Experts tab
   NewsGuard_Refresh(true);
   EventSetTimer(1);           // update even when there are no ticks
   Comment(NewsGuard_Status());
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   Comment("");
  }

//+------------------------------------------------------------------+
void OnTimer()
  {
   Comment(NewsGuard_Status());
  }

//+------------------------------------------------------------------+
void OnTick()
  {
  }
//+------------------------------------------------------------------+
