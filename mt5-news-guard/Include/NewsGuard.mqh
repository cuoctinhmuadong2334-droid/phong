//+------------------------------------------------------------------+
//| NewsGuard.mqh                                                    |
//| Blocks new entries around high-impact news.                      |
//|                                                                  |
//| Layer 1: MT5 economic calendar (scheduled news and speeches).    |
//| Layer 2: price spike / spread guard (unscheduled shocks).        |
//|                                                                  |
//| Usage in an EA:                                                  |
//|   #include <NewsGuard.mqh>                                       |
//|   string why;                                                    |
//|   if(NewsGuard_IsBlocked(why)) { Comment(why); return; }         |
//+------------------------------------------------------------------+
#ifndef NEWS_GUARD_MQH
#define NEWS_GUARD_MQH

input bool   InpNG_Enable           = true;                       // NG: enable News Guard
input int    InpNG_MinutesBefore    = 30;                         // NG: block minutes before news
input int    InpNG_MinutesAfter     = 30;                         // NG: block minutes after news
input string InpNG_Currencies       = "USD";                      // NG: currencies (comma separated)
input ENUM_CALENDAR_EVENT_IMPORTANCE InpNG_MinImportance = CALENDAR_IMPORTANCE_HIGH; // NG: minimum importance
input string InpNG_Keywords         = "trump,president,powell,fed-chair"; // NG: keywords (block from Moderate)
input bool   InpNG_SpikeGuard       = true;                       // NG: enable price spike guard
input double InpNG_SpikeMult        = 3.0;                        // NG: spike when M1 range > X * average
input int    InpNG_MaxSpreadPts     = 0;                          // NG: max spread in points (0 = off)
input int    InpNG_SpikeCooldownMin = 15;                         // NG: block minutes after a spike

// Set to true (e.g. in OnInit) to print the event list on every refresh.
bool NewsGuard_Verbose = false;

#define NG_REFRESH_SEC   300    // reload calendar every 5 minutes
#define NG_RETRY_SEC     60     // retry after a failed load
#define NG_LOOKAHEAD_SEC 86400  // look 24 hours ahead

struct NG_Event
  {
   datetime          time;
   string            name;
   string            code;
   int               importance;
   bool              keyword;
  };

NG_Event g_ngEvents[];
datetime g_ngNextRefresh    = 0;
datetime g_ngSpikeUntil     = 0;
string   g_ngSpikeReason    = "";
bool     g_ngTesterWarned   = false;
bool     g_ngKeywordsParsed = false;
string   g_ngKeywords[];

//+------------------------------------------------------------------+
void NG_Copy(NG_Event &dst, const NG_Event &src)
  {
   dst.time       = src.time;
   dst.name       = src.name;
   dst.code       = src.code;
   dst.importance = src.importance;
   dst.keyword    = src.keyword;
  }

//+------------------------------------------------------------------+
string NG_Lower(string s)
  {
   StringToLower(s);
   return s;
  }

//+------------------------------------------------------------------+
string NG_Trim(string s)
  {
   StringTrimLeft(s);
   StringTrimRight(s);
   return s;
  }

//+------------------------------------------------------------------+
void NG_ParseKeywords()
  {
   if(g_ngKeywordsParsed)
      return;
   g_ngKeywordsParsed = true;
   ArrayResize(g_ngKeywords, 0);
   string parts[];
   int n = StringSplit(InpNG_Keywords, ',', parts);
   for(int i = 0; i < n; i++)
     {
      string k = NG_Lower(NG_Trim(parts[i]));
      if(k == "")
         continue;
      int sz = ArraySize(g_ngKeywords);
      ArrayResize(g_ngKeywords, sz + 1);
      g_ngKeywords[sz] = k;
     }
  }

//+------------------------------------------------------------------+
bool NG_MatchesKeyword(const string code, const string name)
  {
   string c  = NG_Lower(code);
   string nm = NG_Lower(name);
   for(int i = 0; i < ArraySize(g_ngKeywords); i++)
      if(StringFind(c, g_ngKeywords[i]) >= 0 || StringFind(nm, g_ngKeywords[i]) >= 0)
         return true;
   return false;
  }

//+------------------------------------------------------------------+
string NG_ImportanceText(const int importance)
  {
   if(importance == CALENDAR_IMPORTANCE_HIGH)
      return "High";
   if(importance == CALENDAR_IMPORTANCE_MODERATE)
      return "Moderate";
   if(importance == CALENDAR_IMPORTANCE_LOW)
      return "Low";
   return "None";
  }

//+------------------------------------------------------------------+
//| Reload upcoming events from the MT5 calendar (cached).           |
//| Calendar times are trade server time.                            |
//+------------------------------------------------------------------+
void NewsGuard_Refresh(const bool force = false)
  {
   if(MQLInfoInteger(MQL_TESTER))
     {
      if(!g_ngTesterWarned)
        {
         Print("NewsGuard: economic calendar is not available in the Strategy Tester. Only the spike guard is active.");
         g_ngTesterWarned = true;
        }
      return;
     }

   datetime now = TimeTradeServer();
   if(!force && now < g_ngNextRefresh)
      return;

   NG_ParseKeywords();
   datetime from = (datetime)((long)now - InpNG_MinutesAfter * 60);
   datetime to   = (datetime)((long)now + NG_LOOKAHEAD_SEC);

   NG_Event fresh[];
   int  cnt = 0;
   bool ok  = true;

   string curs[];
   int nc = StringSplit(InpNG_Currencies, ',', curs);
   for(int c = 0; c < nc; c++)
     {
      string cur = NG_Trim(curs[c]);
      StringToUpper(cur);
      if(cur == "")
         continue;

      MqlCalendarValue vals[];
      ResetLastError();
      if(CalendarValueHistory(vals, from, to, NULL, cur) < 0)
        {
         PrintFormat("NewsGuard: cannot load calendar for %s (error %d), retrying in %d s",
                     cur, GetLastError(), NG_RETRY_SEC);
         ok = false;
         continue;
        }

      for(int i = 0; i < ArraySize(vals); i++)
        {
         MqlCalendarEvent ev;
         if(!CalendarEventById(vals[i].event_id, ev))
            continue;
         // All-day or tentative events have no exact time to block around.
         if(ev.time_mode != CALENDAR_TIMEMODE_DATETIME)
            continue;

         bool kw = NG_MatchesKeyword(ev.event_code, ev.name);
         bool important = (ev.importance >= InpNG_MinImportance) ||
                          (kw && ev.importance >= CALENDAR_IMPORTANCE_MODERATE);
         if(!important)
            continue;

         ArrayResize(fresh, cnt + 1);
         fresh[cnt].time       = vals[i].time;
         fresh[cnt].name       = ev.name;
         fresh[cnt].code       = ev.event_code;
         fresh[cnt].importance = (int)ev.importance;
         fresh[cnt].keyword    = kw;
         cnt++;
        }
     }

   if(!ok)
     {
      // Keep the previous list and try again soon.
      g_ngNextRefresh = (datetime)((long)now + NG_RETRY_SEC);
      return;
     }

   // Sort by time (insertion sort, the list is small).
   for(int i = 1; i < cnt; i++)
     {
      NG_Event key;
      NG_Copy(key, fresh[i]);
      int j = i - 1;
      while(j >= 0 && fresh[j].time > key.time)
        {
         NG_Copy(fresh[j + 1], fresh[j]);
         j--;
        }
      NG_Copy(fresh[j + 1], key);
     }

   ArrayResize(g_ngEvents, cnt);
   for(int i = 0; i < cnt; i++)
      NG_Copy(g_ngEvents[i], fresh[i]);
   g_ngNextRefresh = (datetime)((long)now + NG_REFRESH_SEC);

   if(NewsGuard_Verbose)
     {
      PrintFormat("NewsGuard: %d matching event(s), server time %s",
                  cnt, TimeToString(now, TIME_DATE | TIME_MINUTES));
      for(int i = 0; i < cnt; i++)
         PrintFormat("  %s | %-8s | %s | %s%s",
                     TimeToString(g_ngEvents[i].time, TIME_DATE | TIME_MINUTES),
                     NG_ImportanceText(g_ngEvents[i].importance),
                     g_ngEvents[i].name, g_ngEvents[i].code,
                     g_ngEvents[i].keyword ? " [keyword]" : "");
     }
  }

//+------------------------------------------------------------------+
//| Detect abnormal M1 range or spread on the chart symbol.          |
//+------------------------------------------------------------------+
void NG_CheckSpike()
  {
   if(!InpNG_SpikeGuard)
      return;

   datetime now   = TimeTradeServer();
   string   cause = "";

   if(InpNG_MaxSpreadPts > 0)
     {
      int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > InpNG_MaxSpreadPts)
         cause = StringFormat("spread %d > %d pts", spread, InpNG_MaxSpreadPts);
     }

   if(cause == "" && InpNG_SpikeMult > 0)
     {
      MqlRates r[];
      ArraySetAsSeries(r, true);
      int got = CopyRates(_Symbol, PERIOD_M1, 0, 61, r);
      if(got >= 21)
        {
         // Average range of older bars, excluding the current and last closed bar.
         double sum = 0;
         for(int i = 2; i < got; i++)
            sum += r[i].high - r[i].low;
         double avg = sum / (got - 2);
         double cur = MathMax(r[0].high - r[0].low, r[1].high - r[1].low);
         if(avg > 0 && cur > InpNG_SpikeMult * avg)
            cause = StringFormat("M1 range %.1fx average", cur / avg);
        }
     }

   if(cause == "")
      return;

   if(now >= g_ngSpikeUntil)
      PrintFormat("NewsGuard: %s on %s, blocking new entries for %d min",
                  cause, _Symbol, InpNG_SpikeCooldownMin);
   g_ngSpikeUntil  = (datetime)((long)now + InpNG_SpikeCooldownMin * 60);
   g_ngSpikeReason = cause;
  }

//+------------------------------------------------------------------+
//| True when new entries should be blocked. `reason` says why.      |
//+------------------------------------------------------------------+
bool NewsGuard_IsBlocked(string &reason)
  {
   reason = "";
   if(!InpNG_Enable)
      return false;

   NewsGuard_Refresh();
   NG_CheckSpike();

   datetime now = TimeTradeServer();
   for(int i = 0; i < ArraySize(g_ngEvents); i++)
     {
      long dt = (long)g_ngEvents[i].time - (long)now;
      if(dt <= InpNG_MinutesBefore * 60 && -dt <= InpNG_MinutesAfter * 60)
        {
         string when = dt >= 0 ? StringFormat("in %d min", (int)(dt / 60))
                               : StringFormat("%d min ago", (int)(-dt / 60));
         reason = StringFormat("NEWS: %s at %s (%s)", g_ngEvents[i].name,
                               TimeToString(g_ngEvents[i].time, TIME_MINUTES), when);
         return true;
        }
     }

   if(now < g_ngSpikeUntil)
     {
      reason = StringFormat("SPIKE: %s, paused until %s", g_ngSpikeReason,
                            TimeToString(g_ngSpikeUntil, TIME_MINUTES));
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| One-line status for Comment() on the chart.                      |
//+------------------------------------------------------------------+
string NewsGuard_Status()
  {
   if(!InpNG_Enable)
      return "NewsGuard: OFF";

   string why;
   if(NewsGuard_IsBlocked(why))
      return "NewsGuard: BLOCKED - " + why;

   if(MQLInfoInteger(MQL_TESTER))
      return "NewsGuard: OK (tester: calendar off, spike guard only)";

   datetime now = TimeTradeServer();
   for(int i = 0; i < ArraySize(g_ngEvents); i++)
      if(g_ngEvents[i].time > now)
         return StringFormat("NewsGuard: OK - next: %s at %s", g_ngEvents[i].name,
                             TimeToString(g_ngEvents[i].time, TIME_DATE | TIME_MINUTES));
   return "NewsGuard: OK - no matching news in the next 24h";
  }

#endif // NEWS_GUARD_MQH
//+------------------------------------------------------------------+
