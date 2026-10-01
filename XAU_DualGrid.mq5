//+------------------------------------------------------------------+
//|                                                XAU_DualGrid.mq5  |
//|  EA luoi 2 chieu cho XAUUSD, khung tin hieu M1                    |
//|                                                                   |
//|  Logic (suy ra tu lich su lenh cua bot dang theo doi):            |
//|   1. Moi khi co nen moi: mo 1 lenh "moi" (bac 1) theo huong cay   |
//|      nen vua dong, neu ro cung chieu dang trong.                  |
//|   2. Gia di nguoc lenh xa nhat cua ro >= GridStep: nhoi bac tiep  |
//|      theo voi lot lon hon (mac dinh 0.01/0.02/0.03/0.04/0.1).     |
//|   3. Ro BUY va ro SELL chay doc lap, nen thuong co lenh 2 chieu.  |
//|   4. Chot ca ro bang trailing tinh tu gia trung binh cua ro.      |
//|                                                                   |
//|  Them so voi bot goc: loc spread, thong bao ve dien thoai.        |
//|  Co san nhung MAC DINH TAT (giong bot goc): cat lo ro theo % so   |
//|  du, gioi han lo trong ngay. Goi y bat: 3% va 6%.                 |
//|                                                                   |
//|  Cai dat: chep file vao MQL5\Experts, mo MetaEditor bam F7,       |
//|  keo EA vao chart XAUUSDc, bat Algo Trading. EA chi chay tren     |
//|  MT5 may tinh hoac VPS, khong chay tren app dien thoai.           |
//|                                                                   |
//|  CANH BAO: luoi nhoi lenh thang nho thuong xuyen nhung co the     |
//|  thua lon khi gia chay mot mach. Chay demo truoc khi dung that.   |
//+------------------------------------------------------------------+
#property copyright "phong"
#property version   "1.00"
#property description "Luoi 2 chieu: lenh moi theo nen + nhoi lenh khi gia di nguoc"

#include <Trade\Trade.mqh>

input group "Tin hieu lenh moi"
input ENUM_TIMEFRAMES InpSignalTF  = PERIOD_M1; // Khung nen tao lenh moi
input double          InpMinBody   = 0.0;       // Than nen toi thieu ($), 0 = moi nen

input group "Luoi nhoi lenh"
input string InpLots      = "0.01,0.02,0.03,0.04,0.1"; // Day lot theo bac
input double InpLotScale  = 1.0;                       // He so nhan day lot
input int    InpMaxLevels = 5;                         // So bac toi da moi ro
input double InpGridStep  = 3.0;                       // Khoang cach nhoi lenh ($)

input group "Chot loi ro (trailing tu gia trung binh)"
input double InpTrailStart    = 1.0; // Bat trailing khi gia vuot gia TB ($)
input double InpTrailDistance = 0.4; // Dong ro khi gia lui lai tu dinh ($)

input group "Quan ly rui ro"
input double InpBasketSLPercent  = 0.0; // Cat lo 1 ro khi lo >= % so du (0 = tat, giong bot goc)
input double InpDailyLossPercent = 0.0; // Dong het, dung den het ngay khi lo >= % (0 = tat, giong bot goc)
input double InpMaxSpread        = 0.5; // Spread toi da de mo lenh ($)

input group "Khac"
input ulong InpMagic       = 20261001; // Magic number
input uint  InpDeviation   = 300;      // Do truot gia toi da (points)
input bool  InpPush        = true;     // Gui thong bao ve app MT5 dien thoai
input int   InpNotifyLevel = 4;        // Thong bao khi ro dat tu bac nay

struct Basket
  {
   int               count;     // so lenh
   double            volume;    // tong lot
   double            avgPrice;  // gia trung binh co trong so
   double            profit;    // lai/lo tha noi (gom swap)
   double            edgePrice; // gia vao xa nhat: thap nhat (BUY) / cao nhat (SELL)
  };

CTrade   trade;
double   g_lots[];
int      g_levels     = 0;
datetime g_lastBar    = 0;
bool     g_trailOn[2];        // [0] = BUY, [1] = SELL
double   g_peak[2];           // muc lai cao nhat ($ so voi gia TB) tu khi bat trailing
datetime g_lastOpen[2];
datetime g_pauseUntil = 0;
datetime g_day        = 0;
double   g_dayBalance = 0.0;
bool     g_halted     = false;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(!ParseLots())
     {
      Print("Day lot khong hop le: ", InpLots);
      return(INIT_PARAMETERS_INCORRECT);
     }
   g_levels = MathMin(InpMaxLevels, ArraySize(g_lots));
   if(g_levels < 1 || InpGridStep <= 0.0 || InpTrailStart <= 0.0 ||
      InpTrailDistance <= 0.0 || InpTrailDistance >= InpTrailStart)
     {
      Print("Tham so khong hop le: can MaxLevels >= 1, GridStep > 0, 0 < TrailDistance < TrailStart");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      Print("EA can tai khoan Hedging (giu BUY va SELL cung luc)");
      return(INIT_FAILED);
     }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviation);
   trade.SetTypeFillingBySymbol(_Symbol);

   for(int k = 0; k < 2; k++)
     {
      g_trailOn[k]  = false;
      g_peak[k]     = 0.0;
      g_lastOpen[k] = 0;
     }
   g_lastBar    = iTime(_Symbol, InpSignalTF, 0); // doi nen moi dau tien
   g_pauseUntil = 0;
   g_day        = 0;
   g_halted     = false;
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.bid <= 0.0)
      return;

   Basket buy, sell;
   ScanBasket(POSITION_TYPE_BUY, buy);
   ScanBasket(POSITION_TYPE_SELL, sell);

//--- 1. Gioi han lo trong ngay
   if(CheckDailyStop())
     {
      if(buy.count > 0)
         CloseBasket(POSITION_TYPE_BUY);
      if(sell.count > 0)
         CloseBasket(POSITION_TYPE_SELL);
      ShowPanel(buy, sell, tick);
      return;
     }

//--- 2. Chot loi / cat lo tung ro; neu vua dong thi doi tick sau quet lai
   bool closedBuy  = ManageExit(POSITION_TYPE_BUY, buy, tick);
   bool closedSell = ManageExit(POSITION_TYPE_SELL, sell, tick);
   if(closedBuy || closedSell)
     {
      ShowPanel(buy, sell, tick);
      return;
     }

//--- 3. Nhoi lenh khi gia di nguoc
   bool spreadOk = (tick.ask - tick.bid) <= InpMaxSpread;
   if(spreadOk)
     {
      AddLevel(POSITION_TYPE_BUY, buy, tick);
      AddLevel(POSITION_TYPE_SELL, sell, tick);
     }

//--- 4. Lenh moi khi co nen moi
   datetime bar = iTime(_Symbol, InpSignalTF, 0);
   if(bar > 0)
     {
      if(g_lastBar == 0)
         g_lastBar = bar;
      if(bar != g_lastBar)
        {
         g_lastBar = bar;
         if(spreadOk)
            OpenStarter(buy, sell);
        }
     }
   ShowPanel(buy, sell, tick);
  }

//+------------------------------------------------------------------+
//| Mo lenh bac 1 theo huong cay nen vua dong                         |
//+------------------------------------------------------------------+
void OpenStarter(const Basket &buy, const Basket &sell)
  {
   double o = iOpen(_Symbol, InpSignalTF, 1);
   double c = iClose(_Symbol, InpSignalTF, 1);
   if(o <= 0.0 || c <= 0.0)
      return;
   double body = c - o;
   if(body == 0.0 || MathAbs(body) < InpMinBody)
      return;
   if(body > 0.0 && buy.count == 0)
      OpenOrder(ORDER_TYPE_BUY, g_lots[0], 1);
   if(body < 0.0 && sell.count == 0)
      OpenOrder(ORDER_TYPE_SELL, g_lots[0], 1);
  }

//+------------------------------------------------------------------+
//| Nhoi bac tiep theo khi gia di nguoc lenh xa nhat >= GridStep      |
//+------------------------------------------------------------------+
void AddLevel(const ENUM_POSITION_TYPE type, const Basket &b, const MqlTick &tick)
  {
   if(b.count == 0 || b.count >= g_levels)
      return;
   double lot = g_lots[b.count];
   if(type == POSITION_TYPE_BUY && tick.ask <= b.edgePrice - InpGridStep)
      OpenOrder(ORDER_TYPE_BUY, lot, b.count + 1);
   else
      if(type == POSITION_TYPE_SELL && tick.bid >= b.edgePrice + InpGridStep)
         OpenOrder(ORDER_TYPE_SELL, lot, b.count + 1);
  }

//+------------------------------------------------------------------+
//| Cat lo ro theo % so du, chot loi ro bang trailing tu gia TB       |
//| Tra ve true neu da ra lenh dong ro                                |
//+------------------------------------------------------------------+
bool ManageExit(const ENUM_POSITION_TYPE type, const Basket &b, const MqlTick &tick)
  {
   int k = Idx(type);
   if(b.count == 0)
     {
      g_trailOn[k] = false;
      g_peak[k]    = 0.0;
      return(false);
     }

   if(InpBasketSLPercent > 0.0 &&
      b.profit <= -AccountInfoDouble(ACCOUNT_BALANCE) * InpBasketSLPercent / 100.0)
     {
      if(CloseBasket(type))
        {
         Notify(StringFormat("%s: CAT LO ro %s (%d lenh, %.2f lot), P/L ~ %.2f",
                             _Symbol, Side(type), b.count, b.volume, b.profit));
         g_trailOn[k] = false;
         g_peak[k]    = 0.0;
        }
      return(true);
     }

   double gain = (type == POSITION_TYPE_BUY) ? tick.bid - b.avgPrice : b.avgPrice - tick.ask;
   if(!g_trailOn[k])
     {
      if(gain >= InpTrailStart)
        {
         g_trailOn[k] = true;
         g_peak[k]    = gain;
        }
      return(false);
     }
   if(gain > g_peak[k])
      g_peak[k] = gain;
   if(gain > g_peak[k] - InpTrailDistance)
      return(false);

   if(CloseBasket(type))
     {
      if(b.count >= InpNotifyLevel)
         Notify(StringFormat("%s: chot ro %s %d lenh, P/L ~ %+.2f",
                             _Symbol, Side(type), b.count, b.profit));
      g_trailOn[k] = false;
      g_peak[k]    = 0.0;
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Lo trong ngay tinh tren Equity toan tai khoan                     |
//+------------------------------------------------------------------+
bool CheckDailyStop()
  {
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   t.hour = 0;
   t.min  = 0;
   t.sec  = 0;
   datetime today = StructToTime(t);
   if(today != g_day)
     {
      g_day        = today;
      g_dayBalance = AccountInfoDouble(ACCOUNT_BALANCE) - ClosedProfitSince(today);
      if(g_halted)
         Print("Ngay moi: EA chay lai");
      g_halted = false;
     }
   if(g_halted)
      return(true);
   if(InpDailyLossPercent <= 0.0 || g_dayBalance <= 0.0)
      return(false);

   double minEquity = g_dayBalance * (1.0 - InpDailyLossPercent / 100.0);
   if(AccountInfoDouble(ACCOUNT_EQUITY) <= minEquity)
     {
      g_halted = true;
      Notify(StringFormat("%s: lo trong ngay cham %.1f%%, dong het lenh EA va dung den het ngay",
                          _Symbol, InpDailyLossPercent));
      return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Lai/lo da dong tu thoi diem 'from' (khong tinh nap/rut)           |
//+------------------------------------------------------------------+
double ClosedProfitSince(const datetime from)
  {
   double sum = 0.0;
   if(!HistorySelect(from, TimeCurrent() + 86400))
      return(sum);
   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      long type = HistoryDealGetInteger(deal, DEAL_TYPE);
      if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
         continue;
      sum += HistoryDealGetDouble(deal, DEAL_PROFIT)
             + HistoryDealGetDouble(deal, DEAL_SWAP)
             + HistoryDealGetDouble(deal, DEAL_COMMISSION);
     }
   return(sum);
  }

//+------------------------------------------------------------------+
bool OpenOrder(const ENUM_ORDER_TYPE type, const double lot, const int level)
  {
   int      k   = (type == ORDER_TYPE_BUY) ? 0 : 1;
   datetime now = TimeCurrent();
//--- cho vi the vua mo cap nhat, va nghi sau khi loi
   if(now < g_pauseUntil || (long)(now - g_lastOpen[k]) < 2)
      return(false);

   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double margin = 0.0;
   if(!OrderCalcMargin(type, _Symbol, lot, price, margin) ||
      margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {
      Print("Khong du ky quy de mo ", DoubleToString(lot, 2), " lot");
      g_pauseUntil = now + 30;
      return(false);
     }

   string cmt  = StringFormat("DG L%d", level);
   bool   sent = (type == ORDER_TYPE_BUY) ? trade.Buy(lot, _Symbol, 0.0, 0.0, 0.0, cmt)
                 : trade.Sell(lot, _Symbol, 0.0, 0.0, 0.0, cmt);
   uint   rc   = trade.ResultRetcode();
   if(sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED))
     {
      g_lastOpen[k] = now;
      if(level >= InpNotifyLevel)
         Notify(StringFormat("%s: ro %s len bac %d (%.2f lot) @ %s", _Symbol,
                             (type == ORDER_TYPE_BUY) ? "BUY" : "SELL", level, lot,
                             DoubleToString(trade.ResultPrice(), _Digits)));
      return(true);
     }
   PrintFormat("Mo lenh loi: %u %s", rc, trade.ResultRetcodeDescription());
   g_pauseUntil = now + 10;
   return(false);
  }

//+------------------------------------------------------------------+
bool CloseBasket(const ENUM_POSITION_TYPE type)
  {
   bool ok = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!SelectOwn(i, type))
         continue;
      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      if(!trade.PositionClose(ticket) || trade.ResultRetcode() != TRADE_RETCODE_DONE)
        {
         ok = false;
         PrintFormat("Dong #%I64u loi: %u %s", ticket, trade.ResultRetcode(),
                     trade.ResultRetcodeDescription());
        }
     }
   return(ok);
  }

//+------------------------------------------------------------------+
void ScanBasket(const ENUM_POSITION_TYPE type, Basket &b)
  {
   b.count     = 0;
   b.volume    = 0.0;
   b.avgPrice  = 0.0;
   b.profit    = 0.0;
   b.edgePrice = 0.0;
   double sumPV = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!SelectOwn(i, type))
         continue;
      double vol   = PositionGetDouble(POSITION_VOLUME);
      double price = PositionGetDouble(POSITION_PRICE_OPEN);
      b.count++;
      b.volume += vol;
      sumPV    += vol * price;
      b.profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(b.count == 1)
         b.edgePrice = price;
      else
         b.edgePrice = (type == POSITION_TYPE_BUY) ? MathMin(b.edgePrice, price)
                       : MathMax(b.edgePrice, price);
     }
   if(b.volume > 0.0)
      b.avgPrice = sumPV / b.volume;
  }

//+------------------------------------------------------------------+
//| Chon vi the thu 'index' neu la cua EA nay, dung symbol, dung chieu|
//+------------------------------------------------------------------+
bool SelectOwn(const int index, const ENUM_POSITION_TYPE type)
  {
   ulong ticket = PositionGetTicket(index);
   if(ticket == 0)
      return(false);
   return(PositionGetString(POSITION_SYMBOL) == _Symbol &&
          (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic &&
          (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type);
  }

//+------------------------------------------------------------------+
bool ParseLots()
  {
   string parts[];
   int n = StringSplit(InpLots, ',', parts);
   if(n < 1)
      return(false);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0.0)
      step = 0.01;
   int digits = (int)MathMax(0.0, MathRound(-MathLog10(step)));
   ArrayResize(g_lots, n);
   for(int i = 0; i < n; i++)
     {
      string s = parts[i];
      StringTrimLeft(s);
      StringTrimRight(s);
      double lot = StringToDouble(s) * InpLotScale;
      if(lot <= 0.0)
         return(false);
      lot = MathRound(lot / step) * step;
      lot = MathMax(vmin, MathMin(vmax, lot));
      g_lots[i] = NormalizeDouble(lot, digits);
     }
   return(true);
  }

//+------------------------------------------------------------------+
void ShowPanel(const Basket &buy, const Basket &sell, const MqlTick &tick)
  {
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE))
      return;
   string s = StringFormat("XAU DualGrid | spread %s | %s\n",
                           DoubleToString(tick.ask - tick.bid, _Digits),
                           g_halted ? "DA DUNG (cham lo trong ngay)" : "DANG CHAY");
   s += BasketLine("BUY ", POSITION_TYPE_BUY, buy);
   s += BasketLine("SELL", POSITION_TYPE_SELL, sell);
   if(InpDailyLossPercent > 0.0)
      s += StringFormat("Dau ngay %.2f | dung khi Equity <= %.2f\n", g_dayBalance,
                        g_dayBalance * (1.0 - InpDailyLossPercent / 100.0));
   Comment(s);
  }

//+------------------------------------------------------------------+
string BasketLine(const string name, const ENUM_POSITION_TYPE type, const Basket &b)
  {
   if(b.count == 0)
      return(name + ": trong\n");
   double next    = (type == POSITION_TYPE_BUY) ? b.edgePrice - InpGridStep : b.edgePrice + InpGridStep;
   string nextTxt = (b.count < g_levels) ? DoubleToString(next, _Digits) : "het bac";
   return(StringFormat("%s: %d/%d bac, %.2f lot, TB %s, P/L %+.2f, nhoi tiep %s%s\n",
                       name, b.count, g_levels, b.volume,
                       DoubleToString(b.avgPrice, _Digits), b.profit, nextTxt,
                       g_trailOn[Idx(type)] ? ", TRAILING" : ""));
  }

//+------------------------------------------------------------------+
void Notify(const string msg)
  {
   Print(msg);
   if(InpPush && !MQLInfoInteger(MQL_TESTER))
      SendNotification(msg);
  }

//+------------------------------------------------------------------+
int Idx(const ENUM_POSITION_TYPE type)
  {
   return((type == POSITION_TYPE_BUY) ? 0 : 1);
  }

//+------------------------------------------------------------------+
string Side(const ENUM_POSITION_TYPE type)
  {
   return((type == POSITION_TYPE_BUY) ? "BUY" : "SELL");
  }
//+------------------------------------------------------------------+
