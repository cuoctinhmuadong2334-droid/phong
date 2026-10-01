//+------------------------------------------------------------------+
//|                                                XAU_DualGrid.mq5  |
//|  EA luoi 2 chieu cho XAUUSD, khung tin hieu M1                    |
//|                                                                   |
//|  Logic:                                                           |
//|   1. Moi nen moi: mo lenh DUNG CHIEU (0.01) theo huong cay nen    |
//|      vua dong, dat TP co dinh (mac dinh $1.5). Cung luc mo lenh   |
//|      NGUOC CHIEU (0.01) lam bac 1 cua ro DCA chieu kia, neu ro    |
//|      do dang trong.                                               |
//|   2. Ro DCA: gia di nguoc lenh xa nhat thi nhoi bac tiep theo.    |
//|      Mac dinh: 0.01/0.02/0.03/0.04/0.1/0.2/0.3/0.6 cach nhau $3,  |
//|      roi 1/2/4 lot cach nhau $5.                                  |
//|   3. Bac 4, 8, 12...: chi mo khi da co 3 lenh dung chieu TP       |
//|      ke tu luc mo bac DCA truoc do.                               |
//|   4. Chot ca ro DCA bang trailing tinh tu gia trung binh cua ro.  |
//|   Magic: ro DCA = Magic, lenh dung chieu = Magic + 1.             |
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
//|  thua lon khi gia chay mot mach. Ro day 11 bac = 8.3 lot: moi $1  |
//|  gia di nguoc = 830 USC (tai khoan cent). Chay demo truoc.        |
//+------------------------------------------------------------------+
#property copyright "phong"
#property version   "1.10"
#property description "Lenh dung chieu TP co dinh + ro DCA 2 chieu, chan bac 4/8/12 theo so lenh TP"

#include <Trade\Trade.mqh>

input group "Tin hieu nen moi"
input ENUM_TIMEFRAMES InpSignalTF  = PERIOD_M1; // Khung nen tao lenh
input double          InpMinBody   = 0.0;       // Than nen toi thieu ($), 0 = moi nen

input group "Lenh dung chieu (theo huong nen, TP co dinh)"
input double InpScalpLot = 0.01; // Lot lenh dung chieu
input double InpScalpTP  = 1.5;  // TP lenh dung chieu ($)
input int    InpScalpMax = 1;    // So lenh dung chieu chua TP toi da moi chieu

input group "Ro DCA (bat dau bang lenh nguoc chieu)"
input string InpLots           = "0.01,0.02,0.03,0.04,0.1,0.2,0.3,0.6,1,2,4"; // Day lot theo bac
input double InpLotScale       = 1.0;  // He so nhan day lot
input int    InpMaxLevels      = 11;   // So bac toi da moi ro
input double InpGridStep       = 3.0;  // Khoang cach nhoi lenh ($)
input double InpGridStep2      = 5.0;  // Khoang cach nhoi cho bac lon ($)
input int    InpStep2FromLevel = 9;    // Tu bac nay dung khoang cach lon

input group "Chan DCA: bac 4, 8, 12... can lenh dung chieu TP"
input int InpGateEvery = 4; // Chan cac bac chia het cho so nay (0 = tat)
input int InpGateTPs   = 3; // So lenh dung chieu TP can co ke tu bac truoc

input group "Chot loi ro DCA (trailing tu gia trung binh)"
input double InpTrailStart    = 1.0; // Bat trailing khi gia vuot gia TB ($)
input double InpTrailDistance = 0.4; // Dong ro khi gia lui lai tu dinh ($)

input group "Quan ly rui ro"
input double InpBasketSLPercent  = 0.0; // Cat lo 1 ro khi lo >= % so du (0 = tat, giong bot goc)
input double InpDailyLossPercent = 0.0; // Dong het, dung den het ngay khi lo >= % (0 = tat, giong bot goc)
input double InpMaxSpread        = 0.5; // Spread toi da de mo lenh ($)

input group "Khac"
input ulong InpMagic       = 20261001; // Magic ro DCA (lenh dung chieu = Magic + 1)
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
   datetime          lastTime;  // thoi diem mo lenh moi nhat cua ro
  };

CTrade   trade;               // ro DCA
CTrade   scalpTrade;          // lenh dung chieu
ulong    g_scalpMagic = 0;
double   g_lots[];
double   g_scalpLot   = 0.0;
int      g_levels     = 0;
datetime g_lastBar    = 0;
bool     g_trailOn[2];        // [0] = BUY, [1] = SELL
double   g_peak[2];           // muc lai cao nhat ($ so voi gia TB) tu khi bat trailing
datetime g_lastOpen[4];       // 0/1 = DCA BUY/SELL, 2/3 = dung chieu BUY/SELL
datetime g_pauseUntil = 0;
int      g_gateCount[2];      // so lenh dung chieu TP da dem cho ro BUY/SELL
datetime g_gateChecked[2];
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
   g_levels   = MathMin(InpMaxLevels, ArraySize(g_lots));
   g_scalpLot = (InpScalpLot > 0.0) ? NormalizeLot(InpScalpLot) : 0.0;
   if(g_levels < 1 || InpGridStep <= 0.0 || InpGridStep2 <= 0.0 || InpStep2FromLevel < 2 ||
      InpTrailStart <= 0.0 || InpTrailDistance <= 0.0 || InpTrailDistance >= InpTrailStart ||
      g_scalpLot <= 0.0 || InpScalpTP <= 0.0 || InpScalpMax < 1 ||
      InpGateEvery < 0 || InpGateTPs < 0)
     {
      Print("Tham so khong hop le: can MaxLevels >= 1, GridStep > 0, GridStep2 > 0, ",
            "Step2FromLevel >= 2, 0 < TrailDistance < TrailStart, ScalpLot > 0, ScalpTP > 0, ",
            "ScalpMax >= 1, GateEvery >= 0, GateTPs >= 0");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      Print("EA can tai khoan Hedging (giu BUY va SELL cung luc)");
      return(INIT_FAILED);
     }

   g_scalpMagic = InpMagic + 1;
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviation);
   trade.SetTypeFillingBySymbol(_Symbol);
   scalpTrade.SetExpertMagicNumber(g_scalpMagic);
   scalpTrade.SetDeviationInPoints(InpDeviation);
   scalpTrade.SetTypeFillingBySymbol(_Symbol);

   for(int k = 0; k < 2; k++)
     {
      g_trailOn[k]     = false;
      g_peak[k]        = 0.0;
      g_gateCount[k]   = 0;
      g_gateChecked[k] = 0;
     }
   for(int k = 0; k < 4; k++)
      g_lastOpen[k] = 0;
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
   int scalpBuy  = CountScalps(POSITION_TYPE_BUY);
   int scalpSell = CountScalps(POSITION_TYPE_SELL);

//--- 1. Gioi han lo trong ngay
   if(CheckDailyStop())
     {
      if(buy.count > 0)
         CloseBasket(POSITION_TYPE_BUY);
      if(sell.count > 0)
         CloseBasket(POSITION_TYPE_SELL);
      if(scalpBuy + scalpSell > 0)
         CloseScalps();
      ShowPanel(buy, sell, scalpBuy, scalpSell, tick);
      return;
     }

//--- 2. Lenh dung chieu nao chua co TP thi gan TP
   EnsureScalpTP(tick);

//--- 3. Chot loi / cat lo tung ro DCA; neu vua dong thi doi tick sau quet lai
   bool closedBuy  = ManageExit(POSITION_TYPE_BUY, buy, tick);
   bool closedSell = ManageExit(POSITION_TYPE_SELL, sell, tick);
   if(closedBuy || closedSell)
     {
      ShowPanel(buy, sell, scalpBuy, scalpSell, tick);
      return;
     }

//--- 4. Nhoi lenh DCA khi gia di nguoc
   bool spreadOk = (tick.ask - tick.bid) <= InpMaxSpread;
   if(spreadOk)
     {
      AddLevel(POSITION_TYPE_BUY, buy, tick);
      AddLevel(POSITION_TYPE_SELL, sell, tick);
     }

//--- 5. Nen moi: lenh dung chieu + lenh nguoc chieu
   datetime bar = iTime(_Symbol, InpSignalTF, 0);
   if(bar > 0)
     {
      if(g_lastBar == 0)
         g_lastBar = bar;
      if(bar != g_lastBar)
        {
         g_lastBar = bar;
         if(spreadOk)
            HandleNewBar(buy, sell, scalpBuy, scalpSell);
        }
     }
   ShowPanel(buy, sell, scalpBuy, scalpSell, tick);
  }

//+------------------------------------------------------------------+
//| Mo lenh dung chieu theo huong nen vua dong; neu mo duoc va ro DCA |
//| chieu nguoc dang trong thi mo luon lenh nguoc chieu lam bac 1     |
//+------------------------------------------------------------------+
void HandleNewBar(const Basket &buy, const Basket &sell, const int scalpBuy, const int scalpSell)
  {
   double o = iOpen(_Symbol, InpSignalTF, 1);
   double c = iClose(_Symbol, InpSignalTF, 1);
   if(o <= 0.0 || c <= 0.0)
      return;
   double body = c - o;
   if(body == 0.0 || MathAbs(body) < InpMinBody)
      return;

   if(body > 0.0)
     {
      if(scalpBuy < InpScalpMax && OpenScalp(ORDER_TYPE_BUY) && sell.count == 0)
         OpenDca(ORDER_TYPE_SELL, g_lots[0], 1);
     }
   else
     {
      if(scalpSell < InpScalpMax && OpenScalp(ORDER_TYPE_SELL) && buy.count == 0)
         OpenDca(ORDER_TYPE_BUY, g_lots[0], 1);
     }
  }

//+------------------------------------------------------------------+
//| Nhoi bac tiep theo khi gia di nguoc lenh xa nhat >= StepFor().    |
//| Bac bi chan (4, 8, 12...) can them InpGateTPs lenh dung chieu TP  |
//+------------------------------------------------------------------+
void AddLevel(const ENUM_POSITION_TYPE type, const Basket &b, const MqlTick &tick)
  {
   if(b.count == 0 || b.count >= g_levels)
      return;
   int    level = b.count + 1;
   double step  = StepFor(level);
   bool   due   = (type == POSITION_TYPE_BUY) ? tick.ask <= b.edgePrice - step
                  : tick.bid >= b.edgePrice + step;
   if(!due)
      return;
   if(IsGated(level) && GateCount(type, b) < InpGateTPs)
      return;
   OpenDca((type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, g_lots[b.count], level);
  }

//+------------------------------------------------------------------+
//| Khoang cach tu lenh xa nhat den bac 'level' sap mo                |
//+------------------------------------------------------------------+
double StepFor(const int level)
  {
   return((level >= InpStep2FromLevel) ? InpGridStep2 : InpGridStep);
  }

//+------------------------------------------------------------------+
bool IsGated(const int level)
  {
   return(InpGateEvery > 0 && InpGateTPs > 0 && level % InpGateEvery == 0);
  }

//+------------------------------------------------------------------+
//| So lenh dung chieu (chieu nguoc voi ro) da TP ke tu bac DCA cuoi; |
//| doc lich su toi da 1 lan moi giay cho moi ro                      |
//+------------------------------------------------------------------+
int GateCount(const ENUM_POSITION_TYPE type, const Basket &b)
  {
   int      k   = Idx(type);
   datetime now = TimeCurrent();
   if(now != g_gateChecked[k])
     {
      g_gateCount[k]   = CountScalpWinsSince(b.lastTime, Opposite(type));
      g_gateChecked[k] = now;
     }
   return(g_gateCount[k]);
  }

//+------------------------------------------------------------------+
int CountScalpWinsSince(const datetime from, const ENUM_POSITION_TYPE scalpType)
  {
   int wins = 0;
   if(from <= 0 || !HistorySelect(from, TimeCurrent() + 60))
      return(wins);
//--- dong lenh BUY tao ra deal SELL va nguoc lai
   long closeType = (scalpType == POSITION_TYPE_BUY) ? DEAL_TYPE_SELL : DEAL_TYPE_BUY;
   int  total     = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol ||
         (ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != g_scalpMagic ||
         HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT ||
         HistoryDealGetInteger(deal, DEAL_TYPE) != closeType)
         continue;
      if(HistoryDealGetDouble(deal, DEAL_PROFIT) > 0.0)
         wins++;
     }
   return(wins);
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
//| Mo lenh dung chieu kem TP co dinh                                 |
//+------------------------------------------------------------------+
bool OpenScalp(const ENUM_ORDER_TYPE type)
  {
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp    = NormalizeDouble((type == ORDER_TYPE_BUY) ? price + InpScalpTP : price - InpScalpTP, _Digits);
   int    guard = 2 + OrderIdx(type);
   if(SendMarket(scalpTrade, type, g_scalpLot, tp, "DG TP", guard))
      return(true);
//--- san khong nhan TP kem lenh: mo khong TP, EnsureScalpTP se gan sau
   if(scalpTrade.ResultRetcode() == TRADE_RETCODE_INVALID_STOPS)
      return(SendMarket(scalpTrade, type, g_scalpLot, 0.0, "DG TP", guard));
   return(false);
  }

//+------------------------------------------------------------------+
//| Mo 1 bac cua ro DCA                                               |
//+------------------------------------------------------------------+
bool OpenDca(const ENUM_ORDER_TYPE type, const double lot, const int level)
  {
   if(!SendMarket(trade, type, lot, 0.0, StringFormat("DG L%d", level), OrderIdx(type)))
      return(false);
   if(level >= InpNotifyLevel)
      Notify(StringFormat("%s: ro %s len bac %d (%.2f lot) @ %s", _Symbol,
                          (type == ORDER_TYPE_BUY) ? "BUY" : "SELL", level, lot,
                          DoubleToString(trade.ResultPrice(), _Digits)));
   return(true);
  }

//+------------------------------------------------------------------+
//| Gui lenh thi truong; 'guard' chong mo trung trong 2 giay          |
//+------------------------------------------------------------------+
bool SendMarket(CTrade &t, const ENUM_ORDER_TYPE type, const double lot, const double tp,
                const string cmt, const int guard)
  {
   datetime now = TimeCurrent();
//--- cho vi the vua mo cap nhat, va nghi sau khi loi
   if(now < g_pauseUntil || (long)(now - g_lastOpen[guard]) < 2)
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

   bool sent = (type == ORDER_TYPE_BUY) ? t.Buy(lot, _Symbol, 0.0, 0.0, tp, cmt)
               : t.Sell(lot, _Symbol, 0.0, 0.0, tp, cmt);
   uint rc   = t.ResultRetcode();
   if(sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED))
     {
      g_lastOpen[guard] = now;
      return(true);
     }
   PrintFormat("Mo lenh loi: %u %s", rc, t.ResultRetcodeDescription());
   if(rc != TRADE_RETCODE_INVALID_STOPS)
      g_pauseUntil = now + 10;
   return(false);
  }

//+------------------------------------------------------------------+
//| Gan TP cho lenh dung chieu chua co TP (toi da 1 lan moi 5 giay)   |
//+------------------------------------------------------------------+
void EnsureScalpTP(const MqlTick &tick)
  {
   static datetime lastRun = 0;
   datetime now = TimeCurrent();
   if((long)(now - lastRun) < 5)
      return;
   lastRun = now;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != g_scalpMagic ||
         PositionGetDouble(POSITION_TP) > 0.0)
         continue;
      bool   isBuy = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double tp    = NormalizeDouble(isBuy ? open + InpScalpTP : open - InpScalpTP, _Digits);
      if((isBuy && tick.bid >= tp) || (!isBuy && tick.ask <= tp))
         scalpTrade.PositionClose(ticket);
      else
         scalpTrade.PositionModify(ticket, 0.0, tp);
     }
  }

//+------------------------------------------------------------------+
bool CloseBasket(const ENUM_POSITION_TYPE type)
  {
   return(ClosePositions(InpMagic, type));
  }

//+------------------------------------------------------------------+
bool CloseScalps()
  {
   bool okBuy  = ClosePositions(g_scalpMagic, POSITION_TYPE_BUY);
   bool okSell = ClosePositions(g_scalpMagic, POSITION_TYPE_SELL);
   return(okBuy && okSell);
  }

//+------------------------------------------------------------------+
bool ClosePositions(const ulong magic, const ENUM_POSITION_TYPE type)
  {
   bool ok = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!SelectOwn(i, magic, type))
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
   b.lastTime  = 0;
   double sumPV = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!SelectOwn(i, InpMagic, type))
         continue;
      double   vol    = PositionGetDouble(POSITION_VOLUME);
      double   price  = PositionGetDouble(POSITION_PRICE_OPEN);
      datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      b.count++;
      b.volume += vol;
      sumPV    += vol * price;
      b.profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(opened > b.lastTime)
         b.lastTime = opened;
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
int CountScalps(const ENUM_POSITION_TYPE type)
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(SelectOwn(i, g_scalpMagic, type))
         n++;
   return(n);
  }

//+------------------------------------------------------------------+
//| Chon vi the thu 'index' neu dung symbol, dung magic, dung chieu   |
//+------------------------------------------------------------------+
bool SelectOwn(const int index, const ulong magic, const ENUM_POSITION_TYPE type)
  {
   ulong ticket = PositionGetTicket(index);
   if(ticket == 0)
      return(false);
   return(PositionGetString(POSITION_SYMBOL) == _Symbol &&
          (ulong)PositionGetInteger(POSITION_MAGIC) == magic &&
          (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type);
  }

//+------------------------------------------------------------------+
bool ParseLots()
  {
   string parts[];
   int n = StringSplit(InpLots, ',', parts);
   if(n < 1)
      return(false);
   ArrayResize(g_lots, n);
   for(int i = 0; i < n; i++)
     {
      string s = parts[i];
      StringTrimLeft(s);
      StringTrimRight(s);
      double lot = StringToDouble(s) * InpLotScale;
      if(lot <= 0.0)
         return(false);
      g_lots[i] = NormalizeLot(lot);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Lam tron lot theo buoc khoi luong cua san                         |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0.0)
      step = 0.01;
   int digits = (int)MathMax(0.0, MathRound(-MathLog10(step)));
   lot = MathRound(lot / step) * step;
   lot = MathMax(vmin, MathMin(vmax, lot));
   return(NormalizeDouble(lot, digits));
  }

//+------------------------------------------------------------------+
void ShowPanel(const Basket &buy, const Basket &sell, const int scalpBuy, const int scalpSell,
               const MqlTick &tick)
  {
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE))
      return;
   string s = StringFormat("XAU DualGrid | spread %s | %s\n",
                           DoubleToString(tick.ask - tick.bid, _Digits),
                           g_halted ? "DA DUNG (cham lo trong ngay)" : "DANG CHAY");
   s += StringFormat("Lenh dung chieu (TP %.2f): BUY %d, SELL %d\n", InpScalpTP, scalpBuy, scalpSell);
   s += BasketLine("Ro BUY ", POSITION_TYPE_BUY, buy);
   s += BasketLine("Ro SELL", POSITION_TYPE_SELL, sell);
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
   int    level   = b.count + 1;
   double step    = StepFor(level);
   double next    = (type == POSITION_TYPE_BUY) ? b.edgePrice - step : b.edgePrice + step;
   string nextTxt = (b.count < g_levels) ? DoubleToString(next, _Digits) : "het bac";
   if(b.count < g_levels && IsGated(level))
      nextTxt += StringFormat(" (can %d TP %s: %d/%d)", InpGateTPs, Side(Opposite(type)),
                              GateCount(type, b), InpGateTPs);
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
int OrderIdx(const ENUM_ORDER_TYPE type)
  {
   return((type == ORDER_TYPE_BUY) ? 0 : 1);
  }

//+------------------------------------------------------------------+
ENUM_POSITION_TYPE Opposite(const ENUM_POSITION_TYPE type)
  {
   return((type == POSITION_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY);
  }

//+------------------------------------------------------------------+
string Side(const ENUM_POSITION_TYPE type)
  {
   return((type == POSITION_TYPE_BUY) ? "BUY" : "SELL");
  }
//+------------------------------------------------------------------+
