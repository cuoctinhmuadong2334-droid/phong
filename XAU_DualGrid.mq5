//+------------------------------------------------------------------+
//|                                                XAU_DualGrid.mq5  |
//|  EA luoi 2 chieu cho XAUUSD, khung tin hieu M1                    |
//|                                                                   |
//|  Logic:                                                           |
//|   1. Moi nen moi: mo lenh DUNG CHIEU (0.01) theo huong cay nen    |
//|      vua dong, dat TP co dinh (mac dinh $1.5).                    |
//|   2. HEDGE khi gia giat ve: ro nao dang trong thi theo doi dinh/  |
//|      day tu luc ro trong. Gia giat nguoc >= $0.7 (bat len tu day  |
//|      -> SELL, giat xuong tu dinh -> BUY) thi mo bac 1 cua ro do.  |
//|   3. Ro DCA: gia di nguoc lenh xa nhat thi nhoi bac tiep theo.    |
//|      Mac dinh: 0.01/0.02/0.03/0.04/0.1/0.2/0.3/0.6 cach nhau $3,  |
//|      roi 1/2/4 lot cach nhau $5.                                  |
//|   4. Bac 4, 8, 12...: chi mo khi da co 3 lenh dung chieu TP       |
//|      ke tu luc mo bac DCA truoc do.                               |
//|   5. Ro co tong lot LON NHAT: TP tong khi gia vuot gia TB $4      |
//|      (lai = 4 x tong lot x 100 USC). Ro nho hon: trailing $1.     |
//|   Magic: ro DCA = Magic, lenh dung chieu = Magic + 1.             |
//|                                                                   |
//|  Bang lai lo goc trai tren: tien nap, ket qua (lai/lo da chot),   |
//|  tien rut, ngay bat dau, ket qua hom nay, lai/lo dang tha noi,    |
//|  va trang thai cac ro DCA.                                        |
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
#property version   "1.30"
#property description "Lenh dung chieu TP + hedge khi gia giat ve + ro DCA 2 chieu, TP tong $4 cho ro lon nhat"

#include <Trade\Trade.mqh>

input group "Tin hieu nen moi"
input ENUM_TIMEFRAMES InpSignalTF  = PERIOD_M1; // Khung nen tao lenh
input double          InpMinBody   = 0.0;       // Than nen toi thieu ($), 0 = moi nen

input group "Lenh dung chieu (theo huong nen, TP co dinh)"
input double InpScalpLot = 0.01; // Lot lenh dung chieu
input double InpScalpTP  = 1.5;  // TP lenh dung chieu ($)
input int    InpScalpMax = 1;    // So lenh dung chieu chua TP toi da moi chieu

input group "Hedge khi gia giat ve (mo bac 1 cua ro dang trong)"
input double InpHedgePullback = 0.7; // Gia giat nguoc tu dinh/day ($)

input group "Ro DCA"
input string InpLots           = "0.01,0.02,0.03,0.04,0.1,0.2,0.3,0.6,1,2,4"; // Day lot theo bac
input double InpLotScale       = 1.0;  // He so nhan day lot
input int    InpMaxLevels      = 11;   // So bac toi da moi ro
input double InpGridStep       = 3.0;  // Khoang cach nhoi lenh ($)
input double InpGridStep2      = 5.0;  // Khoang cach nhoi cho bac lon ($)
input int    InpStep2FromLevel = 9;    // Tu bac nay dung khoang cach lon

input group "Chan DCA: bac 4, 8, 12... can lenh dung chieu TP"
input int InpGateEvery = 4; // Chan cac bac chia het cho so nay (0 = tat)
input int InpGateTPs   = 3; // So lenh dung chieu TP can co ke tu bac truoc

input group "Chot loi ro DCA"
input double InpBigTP         = 4.0; // TP tong ro lon nhat: gia vuot gia TB ($), 0 = dung trailing
input double InpTrailStart    = 1.0; // Ro nho hon: bat trailing khi gia vuot gia TB ($)
input double InpTrailDistance = 0.4; // Ro nho hon: dong ro khi gia lui lai tu dinh ($)

input group "Quan ly rui ro"
input double InpBasketSLPercent  = 0.0; // Cat lo 1 ro khi lo >= % so du (0 = tat, giong bot goc)
input double InpDailyLossPercent = 0.0; // Dong het, dung den het ngay khi lo >= % (0 = tat, giong bot goc)
input double InpMaxSpread        = 0.5; // Spread toi da de mo lenh ($)

input group "Bang lai lo (goc trai tren)"
input bool     InpPanel       = true;  // Hien bang lai lo
input bool     InpPanelEAOnly = false; // Chi tinh lenh cua EA (false = ca tai khoan)
input datetime InpStartDate   = 0;     // Ngay bat dau (1970.01.01 = tu giao dich dau tien)
input int      InpPanelX      = 10;    // Vi tri ngang (px)
input int      InpPanelY      = 25;    // Vi tri doc (px)

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
bool     g_extOn[2];          // ro trong dang theo doi dinh/day de hedge
double   g_ext[2];            // [0] = dinh (ro BUY cho gia giat xuong), [1] = day (ro SELL)

#define PNL_PREFIX "DGP_"
string   g_status[];          // cac dong trang thai EA trong o thu 3
double   g_pDeposit   = 0.0;  // tong tien nap tu ngay bat dau
double   g_pWithdraw  = 0.0;  // tong tien rut (so am)
double   g_pResult    = 0.0;  // lai/lo da chot tu ngay bat dau
double   g_pToday     = 0.0;  // lai/lo da chot hom nay
datetime g_pStart     = 0;
bool     g_pDirty     = true; // can doc lai lich su
datetime g_pLastCalc  = 0;

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
      InpGateEvery < 0 || InpGateTPs < 0 || InpHedgePullback <= 0.0 || InpBigTP < 0.0)
     {
      Print("Tham so khong hop le: can MaxLevels >= 1, GridStep > 0, GridStep2 > 0, ",
            "Step2FromLevel >= 2, 0 < TrailDistance < TrailStart, ScalpLot > 0, ScalpTP > 0, ",
            "ScalpMax >= 1, GateEvery >= 0, GateTPs >= 0, HedgePullback > 0, BigTP >= 0");
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
      g_extOn[k]       = false;
      g_ext[k]         = 0.0;
     }
   for(int k = 0; k < 4; k++)
      g_lastOpen[k] = 0;
   g_lastBar    = iTime(_Symbol, InpSignalTF, 0); // doi nen moi dau tien
   g_pauseUntil = 0;
   g_day        = 0;
   g_halted     = false;
   g_pDirty     = true;
   if(InpPanel && !MQLInfoInteger(MQL_TESTER))
      EventSetTimer(1); // cap nhat bang ca khi thi truong khong co tick
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, PNL_PREFIX);
   Comment("");
  }

//+------------------------------------------------------------------+
void OnTrade()
  {
   g_pDirty = true;
  }

//+------------------------------------------------------------------+
void OnTimer()
  {
   DrawPanel();
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
   bool closedBuy  = ManageExit(POSITION_TYPE_BUY, buy, IsBig(buy, sell), tick);
   bool closedSell = ManageExit(POSITION_TYPE_SELL, sell, IsBig(sell, buy), tick);
   if(closedBuy || closedSell)
     {
      ShowPanel(buy, sell, scalpBuy, scalpSell, tick);
      return;
     }

//--- 4. Nhoi lenh DCA khi gia di nguoc; ro trong thi hedge khi gia giat ve
   bool spreadOk = (tick.ask - tick.bid) <= InpMaxSpread;
   if(spreadOk)
     {
      AddLevel(POSITION_TYPE_BUY, buy, tick);
      AddLevel(POSITION_TYPE_SELL, sell, tick);
      CheckHedge(POSITION_TYPE_BUY, buy, tick);
      CheckHedge(POSITION_TYPE_SELL, sell, tick);
     }

//--- 5. Nen moi: lenh dung chieu
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
//| Mo lenh dung chieu theo huong nen vua dong                        |
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

   if(body > 0.0 && scalpBuy < InpScalpMax)
      OpenScalp(ORDER_TYPE_BUY);
   if(body < 0.0 && scalpSell < InpScalpMax)
      OpenScalp(ORDER_TYPE_SELL);
  }

//+------------------------------------------------------------------+
//| Hedge khi gia giat ve: ro trong theo doi dinh (BUY) / day (SELL)  |
//| tu luc ro trong; gia giat nguoc >= InpHedgePullback thi mo bac 1  |
//+------------------------------------------------------------------+
void CheckHedge(const ENUM_POSITION_TYPE type, const Basket &b, const MqlTick &tick)
  {
   int k = Idx(type);
   if(b.count > 0)
     {
      g_extOn[k] = false;
      return;
     }
   if(type == POSITION_TYPE_BUY)
     {
      if(!g_extOn[k] || tick.ask > g_ext[k])
         g_ext[k] = tick.ask;
      g_extOn[k] = true;
      if(tick.ask <= g_ext[k] - InpHedgePullback && OpenDca(ORDER_TYPE_BUY, g_lots[0], 1))
         g_extOn[k] = false;
     }
   else
     {
      if(!g_extOn[k] || tick.bid < g_ext[k])
         g_ext[k] = tick.bid;
      g_extOn[k] = true;
      if(tick.bid >= g_ext[k] + InpHedgePullback && OpenDca(ORDER_TYPE_SELL, g_lots[0], 1))
         g_extOn[k] = false;
     }
  }

//+------------------------------------------------------------------+
//| Ro co tong lot lon hon han ro con lai (ro kia co the trong)       |
//+------------------------------------------------------------------+
bool IsBig(const Basket &b, const Basket &other)
  {
   return(b.count > 0 && b.volume > other.volume + 1e-8);
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
bool ManageExit(const ENUM_POSITION_TYPE type, const Basket &b, const bool isBig, const MqlTick &tick)
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

//--- ro lon nhat: TP tong co dinh, khong trailing
   if(isBig && InpBigTP > 0.0)
     {
      g_trailOn[k] = false;
      g_peak[k]    = 0.0;
      if(gain < InpBigTP)
         return(false);
      if(CloseBasket(type))
         Notify(StringFormat("%s: TP tong ro %s %d lenh, %.2f lot, P/L ~ %+.2f",
                             _Symbol, Side(type), b.count, b.volume, b.profit));
      return(true);
     }

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
//--- moi dong giu duoi 63 ky tu (gioi han chu cua OBJ_LABEL)
   ArrayResize(g_status, 0);
   AddStatus(StringFormat("EA: %s | spread %s", g_halted ? "DA DUNG (lo ngay)" : "DANG CHAY",
                          DoubleToString(tick.ask - tick.bid, _Digits)));
   AddStatus(StringFormat("Lenh dung chieu: BUY %d, SELL %d (TP %.2f)", scalpBuy, scalpSell, InpScalpTP));
   BasketStatus("Ro BUY ", POSITION_TYPE_BUY, buy, IsBig(buy, sell));
   BasketStatus("Ro SELL", POSITION_TYPE_SELL, sell, IsBig(sell, buy));
   if(InpDailyLossPercent > 0.0)
      AddStatus(StringFormat("Dung khi Equity <= %.2f",
                             g_dayBalance * (1.0 - InpDailyLossPercent / 100.0)));

   if(InpPanel)
     {
      DrawPanel();
      return;
     }
   string s = "";
   for(int i = 0; i < ArraySize(g_status); i++)
      s += g_status[i] + "\n";
   Comment(s);
  }

//+------------------------------------------------------------------+
void BasketStatus(const string name, const ENUM_POSITION_TYPE type, const Basket &b, const bool isBig)
  {
   int k = Idx(type);
   if(b.count == 0)
     {
      if(g_extOn[k])
         AddStatus(StringFormat("%s: trong, hedge khi %s %s", name,
                                (type == POSITION_TYPE_BUY) ? "<=" : ">=",
                                DoubleToString((type == POSITION_TYPE_BUY) ? g_ext[k] - InpHedgePullback
                                               : g_ext[k] + InpHedgePullback, _Digits)));
      else
         AddStatus(name + ": trong");
      return;
     }
   AddStatus(StringFormat("%s: %d/%d bac, %.2f lot, TB %s, %+.2f", name, b.count, g_levels,
                          b.volume, DoubleToString(b.avgPrice, _Digits), b.profit));
   if(isBig && InpBigTP > 0.0)
     {
      double tpPrice = (type == POSITION_TYPE_BUY) ? b.avgPrice + InpBigTP : b.avgPrice - InpBigTP;
      double money   = 0.0;
      OrderCalcProfit((type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol,
                      b.volume, b.avgPrice, tpPrice, money);
      AddStatus(StringFormat("   LON NHAT: TP tong tai %s (~%+.0f)",
                             DoubleToString(tpPrice, _Digits), money));
     }
   int    level = b.count + 1;
   string next  = "het bac";
   if(b.count < g_levels)
     {
      double step  = StepFor(level);
      double price = (type == POSITION_TYPE_BUY) ? b.edgePrice - step : b.edgePrice + step;
      next = "nhoi tiep " + DoubleToString(price, _Digits);
      if(IsGated(level))
         next += StringFormat(" (can %d TP %s: %d/%d)", InpGateTPs, Side(Opposite(type)),
                              GateCount(type, b), InpGateTPs);
     }
   if(g_trailOn[Idx(type)])
      next += ", TRAILING";
   AddStatus("   " + next);
  }

//+------------------------------------------------------------------+
void AddStatus(const string line)
  {
   int n = ArraySize(g_status);
   ArrayResize(g_status, n + 1);
   g_status[n] = line;
  }

//+------------------------------------------------------------------+
//| Bang lai lo goc trai tren: 2 o so lieu + 1 o trang thai EA        |
//+------------------------------------------------------------------+
void DrawPanel()
  {
   if(!InpPanel || (MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)))
      return;
   CalcPanelHistory();
   double floating = PanelFloating();

   const color dim   = C'150,162,185';
   const color label = C'175,186,206';
   int x   = InpPanelX;
   int w   = 340;
   int row = 24;

//--- o 1: nap, ket qua, rut, ngay bat dau
   int y = InpPanelY;
   PanelBox("b1", x, y, w, 4 * row + 12);
   int ry = y + 8;
   PanelRow("r1", x, ry, w, ShortToString(0x25C6), dim, "Gia tri dau vao", label,
            FormatMoney(g_pDeposit), clrWhite);
   ry += row;
   PanelRow("r2", x, ry, w, ShortToString(0x25B2), PlColor(g_pResult), "Ket qua", C'120,220,170',
            FormatMoney(g_pResult), PlColor(g_pResult));
   ry += row;
   PanelRow("r3", x, ry, w, ShortToString(0x25A0), C'255,190,40', "Gia tri dau ra", C'255,200,90',
            FormatMoney(g_pWithdraw), C'255,90,90');
   ry += row;
   PanelRow("r4", x, ry, w, ShortToString(0x25A1), C'130,175,255', "Ngay bat dau", C'140,180,255',
            FormatDate(g_pStart), C'140,180,255');

//--- o 2: hom nay, dang tha noi
   y += 4 * row + 12 + 8;
   PanelBox("b2", x, y, w, 2 * row + 12);
   ry = y + 8;
   PanelRow("r5", x, ry, w, ShortToString(0x25B2), dim, "Ket qua hom nay", label,
            FormatMoney(g_pToday), PlColor(g_pToday));
   ry += row;
   PanelRow("r6", x, ry, w, ShortToString(0x25CF), dim, "Trang thai hien tai", label,
            FormatMoney(floating), PlColor(floating));

//--- o 3: trang thai EA
   int lines = ArraySize(g_status);
   int lh    = 16;
   y += 2 * row + 12 + 8;
   PanelBox("b3", x, y, w, lines * lh + 12);
   for(int i = 0; i < lines; i++)
      PanelText("s" + IntegerToString(i), x + 12, y + 6 + i * lh, g_status[i], C'190,200,215', 8,
                "Consolas", ANCHOR_LEFT_UPPER);
   for(int i = lines; i < 12; i++)
      ObjectDelete(0, PNL_PREFIX + "s" + IntegerToString(i));
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Doc lich su: nap, rut, lai/lo da chot (tong va hom nay).          |
//| Chi doc lai khi co giao dich moi hoac moi 30 giay                 |
//+------------------------------------------------------------------+
void CalcPanelHistory()
  {
   datetime now = TimeCurrent();
   if(!g_pDirty && (long)(now - g_pLastCalc) < 30)
      return;
   g_pDirty    = false;
   g_pLastCalc = now;
   g_pDeposit  = 0.0;
   g_pWithdraw = 0.0;
   g_pResult   = 0.0;
   g_pToday    = 0.0;
   g_pStart    = InpStartDate;
   if(!HistorySelect(InpStartDate, now + 86400))
      return;

   MqlDateTime t;
   TimeToStruct(now, t);
   t.hour = 0;
   t.min  = 0;
   t.sec  = 0;
   datetime today = StructToTime(t);

   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      long     type   = HistoryDealGetInteger(deal, DEAL_TYPE);
      datetime time   = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      double   profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
      if(InpStartDate <= 0 && (g_pStart <= 0 || time < g_pStart))
         g_pStart = time;
      if(type == DEAL_TYPE_BALANCE)
        {
         if(profit > 0.0)
            g_pDeposit += profit;
         else
            g_pWithdraw += profit;
         continue;
        }
      if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
         continue;
      if(InpPanelEAOnly)
        {
         ulong magic = (ulong)HistoryDealGetInteger(deal, DEAL_MAGIC);
         if(magic != InpMagic && magic != g_scalpMagic)
            continue;
        }
      double pl = profit + HistoryDealGetDouble(deal, DEAL_SWAP)
                  + HistoryDealGetDouble(deal, DEAL_COMMISSION);
      g_pResult += pl;
      if(time >= today)
         g_pToday += pl;
     }
  }

//+------------------------------------------------------------------+
//| Lai/lo dang tha noi                                               |
//+------------------------------------------------------------------+
double PanelFloating()
  {
   if(!InpPanelEAOnly)
      return(AccountInfoDouble(ACCOUNT_PROFIT));
   double sum = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
      if(magic == InpMagic || magic == g_scalpMagic)
         sum += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return(sum);
  }

//+------------------------------------------------------------------+
void PanelRow(const string key, const int x, const int y, const int w,
              const string icon, const color iconClr, const string text, const color textClr,
              const string value, const color valueClr)
  {
   PanelText(key + "i", x + 12, y + 1, icon, iconClr, 9, "Segoe UI Symbol", ANCHOR_LEFT_UPPER);
   PanelText(key + "l", x + 32, y, text, textClr, 10, "Segoe UI", ANCHOR_LEFT_UPPER);
   PanelText(key + "v", x + w - 12, y, value, valueClr, 10, "Segoe UI Semibold", ANCHOR_RIGHT_UPPER);
  }

//+------------------------------------------------------------------+
void PanelBox(const string name, const int x, const int y, const int w, const int h)
  {
   string id = PNL_PREFIX + name;
   if(ObjectFind(0, id) < 0)
     {
      ObjectCreate(0, id, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, id, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, id, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, id, OBJPROP_BGCOLOR, C'16,26,48');
      ObjectSetInteger(0, id, OBJPROP_COLOR, C'52,74,115');
      ObjectSetInteger(0, id, OBJPROP_BACK, false);
      ObjectSetInteger(0, id, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, id, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, id, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, id, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, id, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, id, OBJPROP_YSIZE, h);
  }

//+------------------------------------------------------------------+
void PanelText(const string name, const int x, const int y, const string text, const color clr,
               const int size, const string font, const ENUM_ANCHOR_POINT anchor)
  {
   string id = PNL_PREFIX + name;
   if(ObjectFind(0, id) < 0)
     {
      ObjectCreate(0, id, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, id, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, id, OBJPROP_BACK, false);
      ObjectSetInteger(0, id, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, id, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, id, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, id, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, id, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, id, OBJPROP_TEXT, text);
   ObjectSetString(0, id, OBJPROP_FONT, font);
   ObjectSetInteger(0, id, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, id, OBJPROP_COLOR, clr);
  }

//+------------------------------------------------------------------+
color PlColor(const double v)
  {
   return((v >= 0.0) ? C'40,210,120' : C'255,90,90');
  }

//+------------------------------------------------------------------+
//| 1234567.8 -> "1,234,567.80"                                       |
//+------------------------------------------------------------------+
string FormatMoney(const double v)
  {
   string s   = DoubleToString(MathAbs(v), 2);
   int    dot = StringFind(s, ".");
   string ip  = (dot >= 0) ? StringSubstr(s, 0, dot) : s;
   string fp  = (dot >= 0) ? StringSubstr(s, dot) : "";
   string out = "";
   int    len = StringLen(ip);
   for(int i = 0; i < len; i++)
     {
      if(i > 0 && (len - i) % 3 == 0)
         out += ",";
      out += StringSubstr(ip, i, 1);
     }
   return(((v <= -0.005) ? "-" : "") + out + fp);
  }

//+------------------------------------------------------------------+
string FormatDate(const datetime t)
  {
   if(t <= 0)
      return("-");
   MqlDateTime d;
   TimeToStruct(t, d);
   return(StringFormat("%02d/%02d/%04d", d.day, d.mon, d.year));
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
