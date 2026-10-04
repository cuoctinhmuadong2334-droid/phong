//+------------------------------------------------------------------+
//|                                  Can_Cu_Bu_Sieng_Nang_v4_0_3.mq5 |
//|  EA vao lenh bang cap Buy Stop / Sell Stop, DCA theo he so lot   |
//|  tuy chinh, chot basket theo so PIP tinh tu gia trung binh, sau  |
//|  do dat lai cap Stop moi de tiep tuc chu ky.                     |
//|                                                                  |
//|  v4.0.2: chong don 2 lenh vao 1 diem                             |
//|   - DCA tinh khoang cach tu gia XA NHAT cua basket, co cong thoi  |
//|     gian va cho lenh vua gui hien ra truoc khi DCA tiep           |
//|   - Khong dat trung Buy/Sell Stop, xoa Stop thua, huy Stop ngay   |
//|     khi 1 lenh vao khop (OnTradeTransaction)                      |
//|   - Lenh nguoc chieu lo khop van duoc dat TP va tu chot           |
//|   - Khoa: chi 1 EA cung magic tren cung symbol                    |
//|                                                                  |
//|  v4.0.3: chay them ma khac (vd USTEC)                            |
//|   - TP kieu TIEN/LOT: chot khi loi >= InpTPPerLot x (lot / 0.01)  |
//|     (mac dinh 3.5 -> tren vang cent = gia chay $3.5)              |
//|   - Tu quy doi moi khoang cach gia theo ATR ngay so voi vang:     |
//|     nhap so kieu vang, EA nhan he so cho ma dang chay             |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "4.03"
#property strict

#include <Trade\Trade.mqh>

//--- Kieu tang lot cho cac lenh DCA -----------------------------------
enum ELotMode
  {
   LOT_MODE_DOUBLE = 0,  // Nhan doi moi 2 lenh (0.01,0.01,0.02,0.02,0.04,0.04...)
   LOT_MODE_FIXED,       // Co dinh - moi lenh deu bang InpInitialLot
   LOT_MODE_LINEAR,      // Tang deu - moi lenh cong them InpLotLinearStep
   LOT_MODE_MULTIPLY     // Phan tang - moi lenh nhan InpLotMultiplier (vd x2.5)
  };

//--- Cach tinh muc chot loi basket --------------------------------------
enum ETPMode
  {
   TP_MODE_PRICE = 0,    // Theo don vi gia (cach gia trung binh InpTPPrice)
   TP_MODE_MONEY,        // Theo tien loi ca basket (InpTPMoney)
   TP_MODE_PER_LOT       // Theo tien moi 0.01 lot (InpTPPerLot x tong lot / 0.01)
  };

//--- Input parameters -------------------------------------------------
input group "== Vao lenh ban dau (Buy Stop / Sell Stop) =="
input double InpInitialDistance   = 0.8;     // Khoang cach dat Buy Stop / Sell Stop so voi gia hien tai (don vi gia)
input double InpInitialLot        = 0.01;    // Khoi luong lenh dau tien

input group "== DCA (nap them lenh cung chieu) =="
input double   InpDCADistance     = 25.0;    // Khoang cach giua cac lenh DCA cung chieu (don vi gia)
input int      InpMaxDCAOrders    = 10;      // So lenh toi da trong 1 basket (an toan)
input ELotMode InpLotMode         = LOT_MODE_MULTIPLY; // Kieu tang lot cho cac lenh DCA
input double   InpLotMultiplier   = 2.5;     // Chi dung cho kieu PHAN TANG: lot lenh sau = lot lenh truoc x he so nay
input double   InpLotLinearStep   = 0.01;    // Chi dung cho kieu TANG DEU: moi lenh cong them bao nhieu lot
input double   InpMaxLotPerOrder  = 4.5;     // Lot toi da cho phep cho 1 lenh (chan tran)
input double   InpMaxTotalLot     = 10.0;    // Tong lot toi da cho toan bo basket; dat muc nay se ngung DCA them (van giu lenh cu cho TP)

input group "== Tam dung DCA khi gia bien dong manh =="
input bool   InpUseVolatilityPause     = true;  // Bat tam dung DCA khi gia truot qua nhanh
input int    InpVolatilityWindowSecs   = 60;    // Cua so theo doi bien do gia (giay)
input double InpMaxPriceMoveInWindow   = 5.0;   // Bien do gia toi da cho phep trong cua so (don vi gia); vuot qua -> tam dung DCA

input group "== Tam dung DCA theo cau truc nen (chong nhoi lenh 1 vung) =="
input bool            InpUseCandleFilter   = true;           // Bat: cam DCA khi co nhieu nen lien tiep chay nguoc
input ENUM_TIMEFRAMES InpCandleTimeframe   = PERIOD_CURRENT; // Khung dem nen (PERIOD_CURRENT = khung cua bieu do)
input int             InpMaxAgainstCandles = 3;              // So nen nguoc lien tiep thi cam DCA; mo lai khi 1 nen dao chieu dong lai

input group "== Loc ADX (chi vao lenh theo xu huong) =="
input bool            InpUseADXFilter  = false;      // Bat loc ADX cho lenh vao DAU TIEN (khong anh huong DCA)
input ENUM_TIMEFRAMES InpADXTimeframe  = PERIOD_M15; // Khung tinh ADX
input int             InpADXPeriod     = 14;         // Chu ky ADX
input double          InpADXLevel      = 25.0;       // ADX >= muc nay moi vao; +DI > -DI chi Buy Stop, -DI > +DI chi Sell Stop

input group "== Cat lo khi gia chay nguoc qua nhanh =="
input bool   InpUseFastMoveSL       = false; // Bat: dong ca basket khi gia chay nguoc qua nhanh
input int    InpFastMoveWindowSecs  = 300;   // Cua so theo doi (giay), 300 = 5 phut
input double InpFastMoveDistance    = 15.0;  // Gia chay NGUOC chieu basket >= muc nay trong cua so -> cat lo (don vi gia)
input int    InpPauseAfterSLMinutes = 30;    // Sau khi cat lo, nghi vao lenh moi bao nhieu phut

input group "== Chot loi basket =="
input ETPMode InpTPMode           = TP_MODE_PER_LOT; // Cach tinh chot loi basket
input double  InpTPPrice          = 0.40;    // Kieu GIA: chot khi gia cach gia trung binh bao nhieu (don vi gia, cung don vi voi DCA/cat lo)
input double  InpTPMoney          = 100.0;   // Kieu TIEN: chot khi loi ca basket dat bao nhieu (tien te tai khoan, vd USC)
input double  InpTPPerLot         = 3.5;     // Kieu TIEN/LOT: chot khi loi >= so nay x (tong lot / 0.01), vd 0.05 lot -> 17.5

input group "== Khac =="
input ulong  InpMagicNumber       = 20260924; // Magic number
input int    InpSlippagePoints    = 20;       // Truot gia cho phep (points)
input int    InpRefreshSeconds    = 15;       // Chu ky lam moi gia tham chieu Buy/Sell Stop (giay), chi ap dung khi dang cho vao lenh

input group "== Quy doi sang ma khac (vd USTEC) =="
input double InpPriceScale     = 0.0;       // He so nhan moi khoang cach gia: 0 = tu tinh ATR ngay so voi vang, 1 = giu nguyen
input string InpScaleRefSymbol = "XAUUSDc"; // Ma vang tham chieu (dung ten ma vang tren san)

input group "== Chong don lenh vao 1 diem =="
input int    InpMinSecondsBetweenOrders = 5;    // Toi thieu bao nhieu giay giua 2 lenh cung chieu (ca lenh cho va DCA)
input bool   InpSingleInstance          = true; // Chi cho 1 EA cung magic chay tren cung symbol (chan gan trung 2 chart)

input group "== Hien thi tren bieu do =="
input bool   InpShowDailyProfit   = true;     // Hien thi Net Profit Today tren bieu do
input bool   InpShowTPLine        = true;     // Hien thi duong ke gia TP cua basket, tu cap nhat khi co lenh DCA moi
input bool   InpShowMonthlyPanel  = true;     // Hien thi bao cao lai lo THEO THANG (von dau ky, da rut, lai/lo, hom nay, dang mo)

input group "== TP dat len SAN (bao ve khi MT5 offline) =="
input bool   InpUseBrokerTP       = true;     // Dat TP that len san cho tung lenh; van chot duoc khi MT5 tat/mat mang
input bool   InpLogBrokerTPErrors = true;     // In loi dong bo TP ra tab Experts (tat neu thay on)

input group "== Loc tin tuc bien dong manh =="
input bool   InpUseNewsFilter     = true;     // Bat tu dong tam dung truoc/sau tin quan trong
input ENUM_CALENDAR_EVENT_IMPORTANCE InpNewsImportance = CALENDAR_IMPORTANCE_HIGH; // Muc do tin can loc (Cao)
input int    InpNewsBeforeMinutes = 15;       // Tam dung truoc tin bao nhieu phut
input int    InpNewsAfterMinutes  = 15;       // Tam dung sau tin bao nhieu phut

input group "== Tat/bat theo khung gio (gio SERVER cua san) =="
input bool InpUseTimeFilter   = false;  // Bat gioi han khung gio giao dich
input int  InpStartHour       = 8;      // Gio bat dau (0-23), gio server
input int  InpStartMinute     = 0;      // Phut bat dau
input int  InpEndHour         = 22;     // Gio ket thuc (0-23), gio server
input int  InpEndMinute       = 0;      // Phut ket thuc
input bool InpCloseOutsideHrs = false;  // true = DONG HET khi het gio; false = chi ngung vao lenh moi, giu basket cho TP
input bool InpTradeMonday     = true;   // Thu 2
input bool InpTradeTuesday    = true;   // Thu 3
input bool InpTradeWednesday  = true;   // Thu 4
input bool InpTradeThursday   = true;   // Thu 5
input bool InpTradeFriday     = true;   // Thu 6

input group "== Telegram thong bao =="
input bool   InpUseTelegram       = false;    // Bat gui thong bao qua Telegram
input string InpTelegramBotToken  = "";       // Bot Token (lay tu @BotFather)
input string InpTelegramChatID    = "";       // Chat ID nhan thong bao (lay tu @userinfobot)
input bool   InpTelegramControl   = false;    // Cho phep dieu khien EA tu Telegram (/stop, /start, /status)

//--- Global -------------------------------------------------------------
CTrade trade;

enum EBasketState
  {
   STATE_IDLE = 0,   // chua co lenh nao, dang cho cap Stop
   STATE_BUY,        // dang chay basket BUY
   STATE_SELL        // dang chay basket SELL
  };

EBasketState g_state = STATE_IDLE;
string g_profitLabel = "CCBSN_NetProfitToday";
string g_newsLabel   = "CCBSN_NewsStatus";
string g_dcaLabel    = "CCBSN_DCAStatus";
string g_tpLine      = "CCBSN_TPLine";
string g_monthPrefix = "CCBSN_Month";   // tien to ten cac object cua panel bao cao thang

//--- Kich thuoc/vi tri panel Bao Cao Thang (tinh tu goc TREN-TRAI bieu do,
// de khong che nen gia o ben phai)
const int MonthPanelInset  = 10;   // khoang cach tu canh trai chart den canh trai panel
const int MonthPanelWidth  = 270;  // chieu rong panel
const int MonthPanelY      = 28;   // canh tren panel, tinh tu dinh chart (duoi dong ten symbol)
const int MonthPanelRowH   = 22;   // chieu cao 1 dong du lieu
const int MonthPanelPad    = 7;    // le trong tren/duoi moi khung
const int MonthPanelGap    = 8;    // khoang cach giua 2 khung
const int MonthPanelRows   = 6;    // so dong du lieu (4 dong khung tren + 2 dong khung duoi)
const int MonthPanelTopRows = 4;   // so dong cua khung tren

//--- Theo doi trang thai truoc do de phat hien su kien can bao Telegram
EBasketState g_prevNotifyState = STATE_IDLE;
int  g_prevBuyCount      = 0;
int  g_prevSellCount     = 0;
bool g_prevNewsBlackout  = false;

//--- Bo dem mau gia de do bien do trong cua so thoi gian (tam dung DCA khi gia truot nhanh)
datetime g_priceSampleTime[];
double   g_priceSampleValue[];
datetime g_lastSampleTime = 0;

//--- Cong tac mem: dieu khien tu Telegram (/stop, /start, /pause)
bool     g_eaEnabled      = true;   // false = EA ngung hoan toan viec vao lenh
long     g_telegramOffset = 0;      // update_id cuoi cung da xu ly, tranh doc lai tin cu
datetime g_pauseUntil     = 0;      // tam dung den thoi diem nay (lenh /pause <phut>)
bool     g_telegramFirstPoll = true; // lan doc dau tien chi bo qua tin cu, khong thuc thi

//--- Theo doi lan dong bo TP len san gan nhat, tranh goi PositionModify moi tick
double   g_lastSyncedTP    = 0.0;
int      g_lastSyncedCount = 0;
datetime g_lastTPWarnTime  = 0;
datetime g_lastStopWarnTime = 0;   // gioi han tan so log loi dat lenh cho
datetime g_lastTPSyncTime  = 0;    // lan cuoi goi dong bo TP (throttle 1 giay)
int      g_tpFailCount     = 0;    // dem so lan dat TP that bai, de log bat buoc
bool     g_prevInHours    = true;   // trang thai khung gio lan truoc, de bao Telegram 1 lan
int      g_adxHandle      = INVALID_HANDLE; // handle chi bao ADX
datetime g_lastUITime     = 0;      // lan cuoi cap nhat hien thi trong OnTick (throttle 1 giay)
datetime g_newsCheckTime  = 0;      // lan cuoi truy van lich tin tuc (cache 60 giay)
bool     g_newsCached     = false;  // ket qua truy van tin tuc gan nhat

//--- Chong don lenh: [0] = chieu BUY, [1] = chieu SELL
datetime g_lastOrderTime[2] = {0, 0};  // lan cuoi gui lenh (cho hoac DCA) thanh cong moi chieu
int      g_expectCount[2]   = {0, 0};  // so lenh basket ky vong sau lan DCA vua gui
datetime g_expectUntil[2]   = {0, 0};  // het han cho lenh DCA vua gui hien ra

//--- Quy doi khoang cach gia sang ma khac (vd USTEC): moi khoang cach = input x g_scale
double   g_scale        = 1.0;
bool     g_scaleReady   = false;   // false = chua tinh duoc he so -> khong mo lenh moi
bool     g_scaleFromATR = false;   // false = dang tam dung ti le gia, cho du lieu ATR
datetime g_scaleDay     = 0;       // ngay (D1) da tinh he so tu ATR
int      g_atrSelf      = INVALID_HANDLE;
int      g_atrRef       = INVALID_HANDLE;

//--- Khoa 1 EA / symbol / magic (GlobalVariable cua terminal)
string   g_lockName   = "";
string   g_lockHBName = "";
double   g_lockToken  = 0.0;
bool     g_lockOwned  = false;

//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);

   //--- Chan doan cau hinh Telegram, in ra tab Experts de de tim loi
   Print("=== Can Cu Bu Sieng Nang v4.0.3 khoi dong tren ", _Symbol,
         " | gio server: ", TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), " ===");
   Print("[Telegram] Bat gui thong bao : ", (InpUseTelegram ? "true" : "FALSE <-- phai bat"));
   Print("[Telegram] Cho dieu khien    : ", (InpTelegramControl ? "true" : "FALSE <-- phai bat de dung /stop /start /status"));
   Print("[Telegram] Bot Token         : ", (InpTelegramBotToken == "" ? "TRONG <-- phai dien" :
         "da dien (" + IntegerToString(StringLen(InpTelegramBotToken)) + " ky tu)"));
   Print("[Telegram] Chat ID           : ", (InpTelegramChatID == "" ? "TRONG <-- phai dien" : InpTelegramChatID));

   if(InpUseTelegram && InpTelegramBotToken != "" && InpTelegramChatID != "")
      SendTelegramMessage(StringFormat(
         "EA da khoi dong tren %s\nGio server: %s\nDieu khien: %s\nGo /status de xem trang thai.",
         _Symbol, TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
         (InpTelegramControl ? "BAT" : "TAT")));

   if(InpUseADXFilter)
     {
      g_adxHandle = iADX(_Symbol, InpADXTimeframe, InpADXPeriod);
      if(g_adxHandle == INVALID_HANDLE)
        {
         Print("[ADX] Khong tao duoc chi bao ADX, ma loi ", GetLastError());
         return(INIT_FAILED);
        }
     }

   if(!InitPriceScale())
      return(INIT_PARAMETERS_INCORRECT);

   g_state = DetectCurrentState();

   // Khoa: neu da co EA cung magic dang chay tren symbol nay thi EA nay DUNG CHO
   if(!AcquireInstanceLock())
     {
      string msg = StringFormat("[Khoa] Da co 1 EA cung magic %I64u dang chay tren %s o chart khac. "
                                "EA nay DUNG CHO (khong vao lenh) den khi EA kia tat.",
                                InpMagicNumber, _Symbol);
      Print(msg);
      Alert(msg);
     }

   if(CanTrade())
     {
      // PlaceInitialPair tu kiem tra tung ben, nen goi thang (khong dung phep OR)
      if(g_state == STATE_IDLE)
         PlaceInitialPair();

      // Neu dang co basket san (EA vua gan lai / MT5 vua mo lai) -> dat TP len san ngay
      if(g_state == STATE_BUY)
         SyncBasketTPToBroker(POSITION_TYPE_BUY);
      else if(g_state == STATE_SELL)
         SyncBasketTPToBroker(POSITION_TYPE_SELL);
     }

   if(InpShowDailyProfit)
     {
      CreateProfitLabel();
      UpdateProfitLabel();
     }

   if(InpShowMonthlyPanel)
     {
      CreateMonthlyLabel();
      UpdateMonthlyLabel();
     }

   if(InpUseNewsFilter)
     {
      CreateNewsLabel();
      UpdateNewsLabel();
     }

   CreateDCALabel();
   UpdateDCALabel();

   g_prevNotifyState = g_state;
   g_prevBuyCount     = CountPositions(POSITION_TYPE_BUY);
   g_prevSellCount    = CountPositions(POSITION_TYPE_SELL);
   g_prevNewsBlackout = InpUseNewsFilter && IsNewsBlackout();

   EventSetTimer(InpRefreshSeconds);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ReleaseInstanceLock();
   if(g_atrSelf != INVALID_HANDLE)
      IndicatorRelease(g_atrSelf);
   if(g_atrRef != INVALID_HANDLE)
      IndicatorRelease(g_atrRef);
   if(g_adxHandle != INVALID_HANDLE)
      IndicatorRelease(g_adxHandle);
   ObjectDelete(0, g_profitLabel);
   ObjectDelete(0, g_newsLabel);
   ObjectDelete(0, g_dcaLabel);
   ObjectDelete(0, g_tpLine);
   ObjectsDeleteAll(0, g_monthPrefix);
  }

//+------------------------------------------------------------------+
//| Cu moi InpRefreshSeconds giay: neu dang cho vao lenh (IDLE) thi   |
//| huy 2 lenh Buy Stop / Sell Stop cu va dat lai theo gia hien tai   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   // Giu khoa (nhip tim) hoac thu nhan khoa neu EA kia da tat; dang DUNG CHO thi khong lam gi
   if(!InstanceHeartbeat())
      return;

   UpdatePriceScale();     // thu lai den khi co ATR, sau do moi ngay 1 lan
   PollTelegramCommands(); // doc lenh dieu khien tu Telegram truoc

   g_state = DetectCurrentState();
   bool newsBlackout = InpUseNewsFilter && IsNewsBlackout();
   bool canOpen      = CanOpenNew(newsBlackout);

   // Het gio giao dich + da chon dong het -> dong toan bo basket va lenh cho
   if(InpUseTimeFilter && InpCloseOutsideHrs && !IsWithinTradingHours()
      && (g_state == STATE_BUY || g_state == STATE_SELL))
     {
      CloseEverything();
      if(InpUseTelegram)
         SendTelegramMessage(StringFormat("Het khung gio giao dich [%s] - da dong toan bo lenh.", _Symbol));
     }

   if(g_state == STATE_IDLE)
     {
      RemoveDuplicatePendings();
      if(canOpen)
         RefreshInitialPair();
      else
        {
         CancelOppositePending(ORDER_TYPE_BUY_STOP);
         CancelOppositePending(ORDER_TYPE_SELL_STOP);
        }
     }

   // Bao Telegram 1 lan khi ra/vao khung gio
   bool inHours = IsWithinTradingHours();
   if(InpUseTimeFilter && InpUseTelegram && inHours != g_prevInHours)
     {
      SendTelegramMessage(inHours
         ? StringFormat("Vao khung gio giao dich [%s] - EA tiep tuc.", _Symbol)
         : StringFormat("Ngoai khung gio giao dich [%s] - EA ngung vao lenh moi.", _Symbol));
     }
   g_prevInHours = inHours;

   if(InpShowDailyProfit)
      UpdateProfitLabel();
   if(InpShowMonthlyPanel)
      UpdateMonthlyLabel();
   if(InpUseNewsFilter)
      UpdateNewsLabel();
   UpdateDCALabel();   // luon hien: trang thai EA + khung gio + DCA
   if(InpShowTPLine)
      UpdateTPLine();
   if(InpUseTelegram)
      CheckAndNotifyEvents(newsBlackout);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   UpdatePriceSamples();

   // Dang DUNG CHO vi co EA khac cung magic tren symbol nay -> khong giao dich
   if(!CanTrade())
      return;

   g_state = DetectCurrentState();
   bool newsBlackout = InpUseNewsFilter && IsNewsBlackout();
   bool canOpen      = CanOpenNew(newsBlackout);

   switch(g_state)
     {
      case STATE_IDLE:
         // Goi thang PlaceInitialPair: ham nay tu kiem tra TUNG BEN va chi dat
         // ben nao con thieu. Truoc day dung !HasAnyPendingOrder() (phep OR) nen
         // khi chi mat 1 ben, EA bo qua luon va khong dat bu -> mat lenh Buy Stop.
         g_expectCount[0] = 0;   // basket da dong het -> bo cho lenh DCA cu
         g_expectCount[1] = 0;
         RemoveDuplicatePendings();
         if(canOpen)
            PlaceInitialPair();
         else if(HasAnyPendingOrder())
           {
            CancelOppositePending(ORDER_TYPE_BUY_STOP);
            CancelOppositePending(ORDER_TYPE_SELL_STOP);
           }
         break;

      case STATE_BUY:
         // Basket dang chay: khong duoc con lenh Stop nao (ca 2 chieu), tranh khop them vao 1 diem
         CancelOppositePending(ORDER_TYPE_SELL_STOP);
         CancelOppositePending(ORDER_TYPE_BUY_STOP);
         if(CheckFastMoveStopLoss(POSITION_TYPE_BUY))
            break;                                // da cat lo ca basket
         if(canOpen)
            CheckDCA(POSITION_TYPE_BUY);
         SyncBasketTPToBroker(POSITION_TYPE_BUY); // dam bao TP tren san luon dung
         CheckBasketTP(POSITION_TYPE_BUY);        // luon cho phep chot loi
         ManageStrayPositions(POSITION_TYPE_SELL); // lenh SELL lo khop cung luc: dat TP, tu chot
         break;

      case STATE_SELL:
         CancelOppositePending(ORDER_TYPE_BUY_STOP);
         CancelOppositePending(ORDER_TYPE_SELL_STOP);
         if(CheckFastMoveStopLoss(POSITION_TYPE_SELL))
            break;
         if(canOpen)
            CheckDCA(POSITION_TYPE_SELL);
         SyncBasketTPToBroker(POSITION_TYPE_SELL);
         CheckBasketTP(POSITION_TYPE_SELL);
         break;
     }

   // Hien thi chi can cap nhat 1 lan/giay (doc lich su thang, lai hom nay...
   // kha ton may). Logic giao dich o tren van chay MOI tick.
   datetime nowT = TimeCurrent();
   if(nowT != g_lastUITime)
     {
      g_lastUITime = nowT;
      if(InpShowDailyProfit)
         UpdateProfitLabel();
      if(InpShowMonthlyPanel)
         UpdateMonthlyLabel();
      if(InpUseNewsFilter)
         UpdateNewsLabel();
      UpdateDCALabel();   // luon hien: trang thai EA + khung gio + DCA
      if(InpShowTPLine)
         UpdateTPLine();
     }
   if(InpUseTelegram)
      CheckAndNotifyEvents(newsBlackout);
  }

//+------------------------------------------------------------------+
//| Dang trong khung gio giao dich cho phep hay khong?                |
//| Dung GIO SERVER (TimeCurrent) - trung voi gio hien tren bieu do.  |
//| Ho tro khung gio vat qua nua dem (vd 22:00 -> 06:00).             |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
  {
   if(!InpUseTimeFilter)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   bool dayOK = false;
   switch(dt.day_of_week)
     {
      case 1: dayOK = InpTradeMonday;    break;
      case 2: dayOK = InpTradeTuesday;   break;
      case 3: dayOK = InpTradeWednesday; break;
      case 4: dayOK = InpTradeThursday;  break;
      case 5: dayOK = InpTradeFriday;    break;
      default: dayOK = false;            break; // Thu 7, Chu nhat
     }
   if(!dayOK)
      return false;

   int now   = dt.hour * 60 + dt.min;
   int start = InpStartHour * 60 + InpStartMinute;
   int end   = InpEndHour   * 60 + InpEndMinute;

   if(start == end)
      return true;                       // trung nhau = chay ca ngay
   if(start < end)
      return (now >= start && now < end);
   return (now >= start || now < end);   // khung gio vat qua nua dem
  }

//+------------------------------------------------------------------+
//| Dang bi tam dung boi lenh /pause tu Telegram?                     |
//+------------------------------------------------------------------+
bool IsManualPaused()
  {
   return (g_pauseUntil > 0 && TimeCurrent() < g_pauseUntil);
  }

//+------------------------------------------------------------------+
//| Cong tong hop: co duoc phep MO LENH MOI (ke ca DCA) khong?        |
//+------------------------------------------------------------------+
bool CanOpenNew(bool newsBlackout)
  {
   if(!g_eaEnabled)          return false;  // /stop tu Telegram
   if(IsManualPaused())      return false;  // /pause <phut>
   if(newsBlackout)          return false;  // sap co tin quan trong
   if(!IsWithinTradingHours()) return false; // ngoai khung gio da chon
   if(!g_scaleReady)         return false;  // chua quy doi duoc khoang cach cho ma nay
   return true;
  }

//+------------------------------------------------------------------+
//| Xac dinh trang thai hien tai dua tren vi the dang mo             |
//+------------------------------------------------------------------+
EBasketState DetectCurrentState()
  {
   int buyCount  = CountPositions(POSITION_TYPE_BUY);
   int sellCount = CountPositions(POSITION_TYPE_SELL);

   if(buyCount > 0)
      return STATE_BUY;
   if(sellCount > 0)
      return STATE_SELL;
   return STATE_IDLE;
  }

//+------------------------------------------------------------------+
//| Dat cap Buy Stop + Sell Stop quanh gia hien tai                   |
//+------------------------------------------------------------------+
void PlaceInitialPair()
  {
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // San yeu cau lenh cho phai cach gia thi truong toi thieu STOPS_LEVEL.
   // Neu InpInitialDistance nho hon muc nay, san se tu choi lenh -> phai noi ra.
   double stopsLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double dist       = DistInit();
   if(dist <= stopsLevel)
     {
      dist = stopsLevel + point;
      if(TimeCurrent() - g_lastStopWarnTime > 300)
        {
         g_lastStopWarnTime = TimeCurrent();
         Print("[Lenh cho] Khoang cach lenh cho=", DoubleToString(DistInit(), digits),
               " nho hon muc toi thieu cua san (", DoubleToString(stopsLevel, digits),
               "). Da tu dong noi ra ", DoubleToString(dist, digits), ".");
        }
     }

   double buyStopPrice  = NormalizeDouble(ask + dist, digits);
   double sellStopPrice = NormalizeDouble(bid - dist, digits);
   double initLot       = NormalizeLot(InpInitialLot);

   // Loc ADX: ben nao khong hop xu huong thi huy lenh cho (neu co) va khong dat
   bool allowBuy, allowSell;
   GetADXAllowedSides(allowBuy, allowSell);
   if(!allowBuy)
      CancelOppositePending(ORDER_TYPE_BUY_STOP);
   if(!allowSell)
      CancelOppositePending(ORDER_TYPE_SELL_STOP);

   // Chong dat trung: ben nao vua gui lenh trong InpMinSecondsBetweenOrders giay
   // thi bo qua (danh sach lenh cho cua terminal co the chua kip cap nhat)
   if(allowBuy && !HasPendingOrderOfType(ORDER_TYPE_BUY_STOP) && !RecentlySent(0))
     {
      if(trade.BuyStop(initLot, buyStopPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "Init BuyStop") && TradeOK())
         g_lastOrderTime[0] = TimeCurrent();
      else if(TimeCurrent() - g_lastStopWarnTime > 60)
        {
         g_lastStopWarnTime = TimeCurrent();
         Print("[Lenh cho] Dat BUY STOP that bai tai ", DoubleToString(buyStopPrice, digits),
               " - ma loi ", trade.ResultRetcode(), " (", trade.ResultRetcodeDescription(), ")");
        }
     }

   if(allowSell && !HasPendingOrderOfType(ORDER_TYPE_SELL_STOP) && !RecentlySent(1))
     {
      if(trade.SellStop(initLot, sellStopPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "Init SellStop") && TradeOK())
         g_lastOrderTime[1] = TimeCurrent();
      else if(TimeCurrent() - g_lastStopWarnTime > 60)
        {
         g_lastStopWarnTime = TimeCurrent();
         Print("[Lenh cho] Dat SELL STOP that bai tai ", DoubleToString(sellStopPrice, digits),
               " - ma loi ", trade.ResultRetcode(), " (", trade.ResultRetcodeDescription(), ")");
        }
     }
  }

//+------------------------------------------------------------------+
//| Huy cap Buy Stop/Sell Stop cu, dat lai theo gia hien tai          |
//+------------------------------------------------------------------+
void RefreshInitialPair()
  {
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   double stopsLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double dist       = DistInit();
   if(dist <= stopsLevel)
      dist = stopsLevel + point;

   double buyStopPrice  = NormalizeDouble(ask + dist, digits);
   double sellStopPrice = NormalizeDouble(bid - dist, digits);

   // DOI GIA lenh dang co (OrderModify) thay vi xoa roi dat lai.
   // Xoa roi dat lai gay race: server chua xu ly xong viec xoa thi
   // HasPendingOrderOfType() van thay lenh cu -> bo qua viec dat lai -> MAT LENH.
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != (long)InpMagicNumber)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;

      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      double target = 0.0;
      if(t == ORDER_TYPE_BUY_STOP)       target = buyStopPrice;
      else if(t == ORDER_TYPE_SELL_STOP) target = sellStopPrice;
      else continue;

      // Chi doi khi gia lech dang ke, tranh goi modify moi chu ky vo ich
      if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - target) < point)
         continue;

      trade.OrderModify(ticket, target, 0, 0, ORDER_TIME_GTC, 0);
     }

   // Dat bu ben nao con thieu (ham nay tu kiem tra tung ben)
   PlaceInitialPair();
  }

//+------------------------------------------------------------------+
//| Huy lenh cho (pending) o phia doi dien khi 1 ben da khop          |
//+------------------------------------------------------------------+
void CancelOppositePending(ENUM_ORDER_TYPE oppositeType)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != (long)InpMagicNumber)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) == oppositeType)
         trade.OrderDelete(ticket);
     }
  }

//+------------------------------------------------------------------+
//| Luu mau gia hien tai (moi giay 1 mau), loai bo mau qua cu         |
//+------------------------------------------------------------------+
void UpdatePriceSamples()
  {
   datetime now = TimeCurrent();
   if(now == g_lastSampleTime)
      return; // moi giay chi lay 1 mau
   g_lastSampleTime = now;

   double mid = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;

   int size = ArraySize(g_priceSampleTime);
   ArrayResize(g_priceSampleTime, size + 1);
   ArrayResize(g_priceSampleValue, size + 1);
   g_priceSampleTime[size]  = now;
   g_priceSampleValue[size] = mid;

   // Loai bo cac mau nam ngoai cua so theo doi (giu du dai cho ca cua so cat lo nhanh)
   int keepSecs = InpVolatilityWindowSecs;
   if(InpUseFastMoveSL && InpFastMoveWindowSecs > keepSecs)
      keepSecs = InpFastMoveWindowSecs;
   datetime cutoff = now - keepSecs;
   int firstValid = 0;
   size = ArraySize(g_priceSampleTime);
   while(firstValid < size && g_priceSampleTime[firstValid] < cutoff)
      firstValid++;

   if(firstValid > 0)
     {
      int remain = size - firstValid;
      for(int i = 0; i < remain; i++)
        {
         g_priceSampleTime[i]  = g_priceSampleTime[i + firstValid];
         g_priceSampleValue[i] = g_priceSampleValue[i + firstValid];
        }
      ArrayResize(g_priceSampleTime, remain);
      ArrayResize(g_priceSampleValue, remain);
     }
  }

//+------------------------------------------------------------------+
//| Kiem tra bien do gia trong cua so vua qua co vuot nguong khong    |
//| True = gia dang truot qua nhanh -> tam dung DCA cho on dinh       |
//+------------------------------------------------------------------+
bool IsPriceMovingTooFast()
  {
   if(!InpUseVolatilityPause)
      return false;

   int size = ArraySize(g_priceSampleValue);
   if(size < 2)
      return false;

   // Bo dem co the dai hon cua so nay (do cat lo nhanh can 5 phut) -> chi xet mau trong cua so
   datetime from    = TimeCurrent() - InpVolatilityWindowSecs;
   double   highest = g_priceSampleValue[size - 1];
   double   lowest  = g_priceSampleValue[size - 1];
   for(int i = 0; i < size; i++)
     {
      if(g_priceSampleTime[i] < from)
         continue;
      if(g_priceSampleValue[i] > highest)
         highest = g_priceSampleValue[i];
      if(g_priceSampleValue[i] < lowest)
         lowest = g_priceSampleValue[i];
     }

   return ((highest - lowest) >= DistVolMove());
  }

//+------------------------------------------------------------------+
//| Lai/lo dang mo (profit + swap) cua cac lenh trong basket           |
//+------------------------------------------------------------------+
double GetBasketFloating(ENUM_POSITION_TYPE type)
  {
   double floating = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type)
         continue;
      floating += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return floating;
  }

//+------------------------------------------------------------------+
//| Thoi diem mo lenh DAU TIEN cua basket (lenh cu nhat)               |
//+------------------------------------------------------------------+
datetime GetBasketOpenTime(ENUM_POSITION_TYPE type)
  {
   datetime first = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type)
         continue;

      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(first == 0 || t < first)
         first = t;
     }
   return first;
  }

//+------------------------------------------------------------------+
//| Cat lo ca basket khi gia chay NGUOC chieu qua nhanh:              |
//|  - Basket BUY : dinh cao nhat trong cua so - gia hien tai >= muc  |
//|  - Basket SELL: gia hien tai - day thap nhat trong cua so >= muc  |
//| Chi xet tu luc basket mo lenh dau tien, de cu giat truoc khi vao  |
//| lenh khong lam cat nham. Cat xong: nghi InpPauseAfterSLMinutes.   |
//| Tra ve true neu da cat lo.                                        |
//+------------------------------------------------------------------+
bool CheckFastMoveStopLoss(ENUM_POSITION_TYPE type)
  {
   if(!InpUseFastMoveSL)
      return false;

   int size = ArraySize(g_priceSampleValue);
   if(size == 0)
      return false;

   datetime from      = TimeCurrent() - InpFastMoveWindowSecs;
   datetime basketT   = GetBasketOpenTime(type);
   if(basketT > from)
      from = basketT;

   double mid     = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
   double extreme = mid;
   for(int i = 0; i < size; i++)
     {
      if(g_priceSampleTime[i] < from)
         continue;
      if(type == POSITION_TYPE_BUY && g_priceSampleValue[i] > extreme)
         extreme = g_priceSampleValue[i];
      if(type == POSITION_TYPE_SELL && g_priceSampleValue[i] < extreme)
         extreme = g_priceSampleValue[i];
     }

   double against = (type == POSITION_TYPE_BUY) ? (extreme - mid) : (mid - extreme);
   if(against < DistFastMove())
      return false;

   int    digits   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int    count    = CountPositions(type);
   double floating = GetBasketFloating(type);

   CloseAllPositions(type);
   CancelOppositePending(ORDER_TYPE_BUY_STOP);
   CancelOppositePending(ORDER_TYPE_SELL_STOP);
   g_lastSyncedTP    = 0.0;
   g_lastSyncedCount = 0;
   g_pauseUntil      = TimeCurrent() + InpPauseAfterSLMinutes * 60;

   string msg = StringFormat("CAT LO NHANH [%s]: gia chay nguoc %s trong %d giay -> dong %d lenh %s, lai/lo ~%.2f %s. Nghi den %s.",
                             _Symbol, DoubleToString(against, digits), InpFastMoveWindowSecs, count,
                             (type == POSITION_TYPE_BUY ? "BUY" : "SELL"), floating,
                             AccountInfoString(ACCOUNT_CURRENCY), TimeToString(g_pauseUntil, TIME_MINUTES));
   Print(msg);
   if(InpUseTelegram)
      SendTelegramMessage(msg);

   // Cap nhat trang thai ngay de CheckAndNotifyEvents khong bao nham "da chot loi"
   g_state           = DetectCurrentState();
   g_prevNotifyState = g_state;
   g_prevBuyCount    = CountPositions(POSITION_TYPE_BUY);
   g_prevSellCount   = CountPositions(POSITION_TYPE_SELL);
   return true;
  }

//+------------------------------------------------------------------+
//| Doc ADX, +DI, -DI cua nen DA DONG gan nhat. False = chua co du lieu|
//+------------------------------------------------------------------+
bool GetADXValues(double &adx, double &plusDI, double &minusDI)
  {
   if(g_adxHandle == INVALID_HANDLE)
      return false;

   double a[1], p[1], m[1];
   if(CopyBuffer(g_adxHandle, 0, 1, 1, a) != 1 ||
      CopyBuffer(g_adxHandle, 1, 1, 1, p) != 1 ||
      CopyBuffer(g_adxHandle, 2, 1, 1, m) != 1)
      return false;

   adx     = a[0];
   plusDI  = p[0];
   minusDI = m[0];
   return true;
  }

//+------------------------------------------------------------------+
//| Loc ADX theo xu huong cho lenh vao dau tien:                      |
//|  ADX < InpADXLevel      -> khong vao ben nao                      |
//|  ADX >= muc, +DI > -DI  -> chi Buy Stop                           |
//|  ADX >= muc, -DI > +DI  -> chi Sell Stop                          |
//+------------------------------------------------------------------+
void GetADXAllowedSides(bool &allowBuy, bool &allowSell)
  {
   allowBuy  = true;
   allowSell = true;
   if(!InpUseADXFilter)
      return;

   double adx, plusDI, minusDI;
   if(!GetADXValues(adx, plusDI, minusDI) || adx < InpADXLevel)
     {
      allowBuy  = false;
      allowSell = false;
      return;
     }

   allowBuy  = (plusDI > minusDI);
   allowSell = (minusDI > plusDI);
  }

//+------------------------------------------------------------------+
//| Tinh tong lot hien tai cua basket                                  |
//+------------------------------------------------------------------+
double GetBasketTotalLot(ENUM_POSITION_TYPE type)
  {
   double total = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type)
         continue;

      total += PositionGetDouble(POSITION_VOLUME);
     }
   return total;
  }

//+------------------------------------------------------------------+
//| Dem so nen NGUOC chieu basket lien tiep, tinh tu nen da dong gan |
//| nhat (shift 1) lui ve qua khu. Nen dang hinh thanh (shift 0) bi   |
//| bo qua vi chua chot, tranh tin hieu nhay lien tuc.                |
//|  - Basket BUY  : nen nguoc = nen giam (close < open)              |
//|  - Basket SELL : nen nguoc = nen tang (close > open)              |
//| Gap nen dao chieu hoac nen doji -> dung dem (chuoi bi pha).       |
//+------------------------------------------------------------------+
int CountAgainstCandles(ENUM_POSITION_TYPE type)
  {
   int maxScan = InpMaxAgainstCandles + 2; // chi can quet du de biet co vuot nguong
   int streak  = 0;

   for(int shift = 1; shift <= maxScan; shift++)
     {
      double o = iOpen(_Symbol, InpCandleTimeframe, shift);
      double c = iClose(_Symbol, InpCandleTimeframe, shift);
      if(o == 0.0 || c == 0.0)
         break; // chua co du du lieu nen

      bool against = (type == POSITION_TYPE_BUY) ? (c < o) : (c > o);
      if(!against)
         break; // nen dao chieu hoac doji -> chuoi ket thuc

      streak++;
     }

   return streak;
  }

//+------------------------------------------------------------------+
//| True = dang bi cam DCA vi gia chay nguoc lien tuc theo cau truc  |
//| nen. Chi mo lai khi xuat hien 1 nen dao chieu da dong (luc do     |
//| chuoi nen nguoc bi pha ve 0, ham nay tra ve false).               |
//+------------------------------------------------------------------+
bool IsCandleTrendAgainst(ENUM_POSITION_TYPE type)
  {
   if(!InpUseCandleFilter || InpMaxAgainstCandles <= 0)
      return false;

   return (CountAgainstCandles(type) >= InpMaxAgainstCandles);
  }

//+------------------------------------------------------------------+
//| Tinh truoc gia TP cua basket SAU KHI them 1 lenh moi (chua mo).   |
//| Dung de dat TP ngay tu luc mo lenh DCA, thay vi cho dong bo sau.  |
//+------------------------------------------------------------------+
double PredictBasketTP(ENUM_POSITION_TYPE type, double newLot, double newPrice)
  {
   double oldLot = GetBasketTotalLot(type);
   double oldAvg = GetBasketAveragePrice(type);
   double totLot = oldLot + newLot;
   if(totLot <= 0.0)
      return 0.0;

   double newAvg = (oldAvg * oldLot + newPrice * newLot) / totLot;
   double dist   = GetTPDistance(totLot);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double tp = (type == POSITION_TYPE_BUY) ? newAvg + dist
                                           : newAvg - dist;
   return NormalizeDouble(tp, digits);
  }

//+------------------------------------------------------------------+
//| Kiem tra dieu kien va nap them lenh DCA cung chieu                |
//| Lot lay tu CalcNextLot() theo kieu chon o InpLotMode, chan tran   |
//| boi InpMaxLotPerOrder va tong basket boi InpMaxTotalLot.          |
//| Tam dung DCA khi gia truot qua nhanh hoac nhieu nen chay nguoc.   |
//+------------------------------------------------------------------+
void CheckDCA(ENUM_POSITION_TYPE type)
  {
   int side  = (type == POSITION_TYPE_BUY) ? 0 : 1;
   int count = CountPositions(type);
   if(count == 0 || count >= InpMaxDCAOrders)
      return;

   // Chong don lenh 1: lenh DCA vua gui chua hien trong danh sach vi the
   // -> cho no hien ra (toi da 30 giay), KHONG gui them lenh thu 2 cung gia
   if(count < g_expectCount[side] && TimeCurrent() < g_expectUntil[side])
      return;
   g_expectCount[side] = 0;

   // Chong don lenh 2: vua gui lenh cung chieu trong vai giay -> cho
   if(RecentlySent(side))
      return;

   // Gia dang truot qua nhanh -> tam dung DCA, cho gia on dinh lai
   if(IsPriceMovingTooFast())
      return;

   // Gia chay nguoc lien tuc (>= InpMaxAgainstCandles nen) -> cam DCA,
   // cho 1 nen dao chieu dong lai moi cho nap them, tranh nhoi lenh 1 vung
   if(IsCandleTrendAgainst(type))
      return;

   // Chong don lenh 3: khoang cach DCA tinh tu gia XA NHAT cua basket
   // (BUY: gia mo thap nhat, SELL: gia mo cao nhat), khong phai lenh moi nhat
   // theo thoi gian -> 2 lenh khong bao gio nam trong cung 1 khoang DCA
   double lastPrice;
   if(!GetBasketEdgePrice(type, lastPrice))
      return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // Lot cho lenh tiep theo, theo kieu da chon o InpLotMode
   double nextLot = CalcNextLot(count);

   // Neu vao them lenh nay se lam tong lot basket vuot InpMaxTotalLot -> dung DCA, giu lenh cu cho TP
   double currentTotalLot = GetBasketTotalLot(type);
   if(currentTotalLot + nextLot > InpMaxTotalLot)
      return;

   if(type == POSITION_TYPE_BUY)
     {
      // Gia di nguoc (giam) InpDCADistance so voi lenh xa nhat -> mua them
      if(ask <= NormalizeDouble(lastPrice - DistDCA(), digits))
        {
         // Dat TP ngay tu luc mo: tinh truoc gia TB sau khi co lenh nay
         double tpNew = InpUseBrokerTP ? PredictBasketTP(POSITION_TYPE_BUY, nextLot, ask) : 0.0;
         if(trade.Buy(nextLot, _Symbol, ask, 0, tpNew, "DCA Buy") && TradeOK())
           {
            MarkDCASent(side, count);
            SyncBasketTPToBroker(POSITION_TYPE_BUY); // dong bo lai TP cho CA cac lenh cu
           }
        }
     }
   else // POSITION_TYPE_SELL
     {
      // Gia di nguoc (tang) InpDCADistance so voi lenh xa nhat -> ban them
      if(bid >= NormalizeDouble(lastPrice + DistDCA(), digits))
        {
         double tpNew = InpUseBrokerTP ? PredictBasketTP(POSITION_TYPE_SELL, nextLot, bid) : 0.0;
         if(trade.Sell(nextLot, _Symbol, bid, 0, tpNew, "DCA Sell") && TradeOK())
           {
            MarkDCASent(side, count);
            SyncBasketTPToBroker(POSITION_TYPE_SELL);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Lam tron lot ve dung buoc khoi luong cua san (VOLUME_STEP), va    |
//| kep trong [VOLUME_MIN, VOLUME_MAX]. Tranh loi "invalid volume".   |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0.0)
      step = 0.01;

   lot = MathFloor(lot / step + 0.0000001) * step;
   if(lot < vmin) lot = vmin;
   if(vmax > 0.0 && lot > vmax) lot = vmax;

   int d = (int)MathMax(0.0, MathCeil(-MathLog10(step)));
   return NormalizeDouble(lot, d);
  }

//+------------------------------------------------------------------+
//| Tinh lot cho lenh DCA tiep theo theo kieu da chon.                |
//| count = so lenh DANG CO trong basket (lenh sap vao la thu count+1)|
//+------------------------------------------------------------------+
double CalcNextLot(int count)
  {
   double raw;

   switch(InpLotMode)
     {
      case LOT_MODE_FIXED:
         // Moi lenh deu bang lot ban dau
         raw = InpInitialLot;
         break;

      case LOT_MODE_LINEAR:
         // Tang deu: lenh thu n = InpInitialLot + (n-1) * buoc
         raw = InpInitialLot + count * InpLotLinearStep;
         break;

      case LOT_MODE_MULTIPLY:
         // Phan tang: lenh thu n = InpInitialLot * he so^(n-1), vd 0.05, 0.125, 0.3125...
         // Tinh tu lot goc (khong tu lot da lam tron) de sai so lam tron khong bi cong don
         raw = InpInitialLot * MathPow(InpLotMultiplier, count);
         break;

      default: // LOT_MODE_DOUBLE
         // Lap lai 1 lan roi nhan doi: 0.01,0.01,0.02,0.02,0.04,0.04...
         raw = InpInitialLot * MathPow(2.0, MathFloor(count / 2.0));
         break;
     }

   if(raw > InpMaxLotPerOrder)
      raw = InpMaxLotPerOrder;

   return NormalizeLot(raw);
  }

//+------------------------------------------------------------------+
//| Tinh gia trung binh (weighted by lot) cua basket                  |
//+------------------------------------------------------------------+
double GetBasketAveragePrice(ENUM_POSITION_TYPE type)
  {
   double sumPriceLot = 0.0;
   double sumLot = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type)
         continue;

      double lot = PositionGetDouble(POSITION_VOLUME);
      sumPriceLot += PositionGetDouble(POSITION_PRICE_OPEN) * lot;
      sumLot += lot;
     }

   if(sumLot <= 0.0)
      return 0.0;
   return sumPriceLot / sumLot;
  }

//+------------------------------------------------------------------+
//| Khoang cach (don vi gia) tu gia trung binh den muc TP cua basket. |
//|  - Kieu GIA : = InpTPPrice x he so quy doi                         |
//|  - Kieu TIEN/LOT: loi InpTPPerLot moi 0.01 lot                    |
//|    -> khoang gia = InpTPPerLot / (0.01 x gia tri 1 don vi gia)    |
//|  - Kieu TIEN: khoang gia can di de basket (totalLot) loi du       |
//|    InpTPMoney = tien / (lot * gia tri 1 don vi gia cua 1 lot)     |
//+------------------------------------------------------------------+
double GetTPDistance(double totalLot)
  {
   if(InpTPMode == TP_MODE_PRICE)
      return DistTPPrice();

   double perUnit = MoneyPerPriceUnit();   // tien cua 1 lot khi gia chay 1 don vi
   if(totalLot <= 0.0 || perUnit <= 0.0)
      return DistTPPrice(); // thieu du lieu san -> tam dung kieu gia

   // Kieu TIEN/LOT: loi InpTPPerLot cho moi 0.01 lot -> khoang gia khong phu thuoc tong lot
   if(InpTPMode == TP_MODE_PER_LOT)
      return InpTPPerLot / (0.01 * perUnit);

   return InpTPMoney / (totalLot * perUnit);
  }

//+------------------------------------------------------------------+
//| Dat TP THAT len san cho tung lenh trong basket, tai dung muc TP   |
//| cua ca basket (gia trung binh +/- GetTPDistance).                 |
//| Tu dong bo lai moi khi co lenh DCA moi (gia trung binh thay doi). |
//| Muc dich: neu MT5 tat / mat mang, SAN van tu dong basket khi cham.|
//+------------------------------------------------------------------+
void SyncBasketTPToBroker(ENUM_POSITION_TYPE type)
  {
   if(!InpUseBrokerTP)
      return;

   int count = CountPositions(type);
   if(count == 0)
     {
      g_lastSyncedTP    = 0.0;   // basket da dong -> reset bo nho dong bo
      g_lastSyncedCount = 0;
      return;
     }

   double avg = GetBasketAveragePrice(type);
   if(avg <= 0.0)
      return;

   int    digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double dist    = GetTPDistance(GetBasketTotalLot(type));

   double targetTP = (type == POSITION_TYPE_BUY) ? avg + dist
                                                 : avg - dist;
   targetTP = NormalizeDouble(targetTP, digits);

   // Throttle theo THOI GIAN (toi da 1 lan/giay) thay vi cache ket qua.
   // Cache cu chi cap nhat khi modify thanh cong -> neu san tu choi 1 lan,
   // TP se ket vinh vien o gia tri cu. Gio luon quet lai tung lenh.
   // Throttle tach rieng tung chieu, de khi lo co ca BUY va SELL thi ca 2 chieu deu duoc dong bo
   static datetime syncTimeSide[2]  = {0, 0};
   static int      syncCountSide[2] = {0, 0};
   int side = (type == POSITION_TYPE_BUY) ? 0 : 1;
   if(TimeCurrent() == syncTimeSide[side] && count == syncCountSide[side])
      return;
   syncTimeSide[side]  = TimeCurrent();
   syncCountSide[side] = count;
   g_lastTPSyncTime    = TimeCurrent();
   g_lastSyncedCount   = count;

   // San yeu cau TP cach gia thi truong toi thieu STOPS_LEVEL
   double stopsLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   bool tooClose = (type == POSITION_TYPE_BUY) ? (targetTP - bid <= stopsLevel)
                                               : (ask - targetTP <= stopsLevel);
   if(tooClose)
     {
      // Gia da sat TP roi - de CheckBasketTP() trong EA tu dong ngay tick toi.
      if(InpLogBrokerTPErrors && TimeCurrent() - g_lastTPWarnTime > 300)
        {
         g_lastTPWarnTime = TimeCurrent();
         Print("[TP san] Gia da qua sat TP (", DoubleToString(targetTP, digits),
               "), san khong cho dat. EA se tu dong basket khi cham.");
        }
      return;
     }

   int modified = 0, failed = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type)
         continue;

      double curTP = PositionGetDouble(POSITION_TP);
      double curSL = PositionGetDouble(POSITION_SL);

      if(MathAbs(curTP - targetTP) < point * 0.5)
         continue;   // lenh nay da dung TP roi

      if(trade.PositionModify(ticket, curSL, targetTP))
         modified++;
      else
        {
         failed++;
         g_tpFailCount++;
         // 20 lan dau LUON in ra, du InpLogBrokerTPErrors = false,
         // de loi dong bo TP khong con bi giau nhu truoc
         if(InpLogBrokerTPErrors || g_tpFailCount <= 20)
            Print("[TP san] Khong dat duoc TP ", DoubleToString(targetTP, digits),
                  " cho ticket ", ticket, " (gia TB ", DoubleToString(avg, digits),
                  ", ", count, " lenh) - ma loi ", trade.ResultRetcode(),
                  " (", trade.ResultRetcodeDescription(), ")");
        }
     }

   if(modified > 0)
     {
      g_lastSyncedTP = targetTP;
      if(InpLogBrokerTPErrors)
         Print("[TP san] Da dong bo TP = ", DoubleToString(targetTP, digits),
               " cho ", modified, "/", count, " lenh", (failed > 0 ? StringFormat(" (%d loi)", failed) : ""));
     }
  }

//+------------------------------------------------------------------+
//| Chot loi phia EA (nhanh hon, va du phong khi san khong nhan TP).  |
//| Chay song song voi TP dat tren san: cai nao cham truoc thi dong.  |
//+------------------------------------------------------------------+
void CheckBasketTP(ENUM_POSITION_TYPE type)
  {
   double avgPrice = GetBasketAveragePrice(type);
   if(avgPrice <= 0.0)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   bool hit = false;

   if(InpTPMode == TP_MODE_MONEY)
     {
      // Kieu TIEN: so thang loi thuc cua basket (da gom swap), chinh xac hon quy doi ra gia
      hit = (GetBasketFloating(type) >= InpTPMoney);
     }
   else if(InpTPMode == TP_MODE_PER_LOT)
     {
      // Kieu TIEN/LOT: loi >= InpTPPerLot x (tong lot / 0.01), da gom swap
      hit = (GetBasketFloating(type) >= InpTPPerLot * GetBasketTotalLot(type) / 0.01);
     }
   else if(type == POSITION_TYPE_BUY)
     {
      double target = avgPrice + DistTPPrice();
      if(bid >= target)
         hit = true;
     }
   else // POSITION_TYPE_SELL
     {
      double target = avgPrice - DistTPPrice();
      if(ask <= target)
         hit = true;
     }

   if(hit)
     {
      CloseAllPositions(type);
      g_lastSyncedTP    = 0.0;   // reset bo nho dong bo TP cho chu ky sau
      g_lastSyncedCount = 0;
      // KHONG dat lai cap Stop ngay trong tick nay: neu lenh chua dong het, Stop moi
      // se khop chong vao basket cu. Nhanh IDLE cua OnTick se dat lai o tick sau,
      // khi da chac chan khong con lenh nao mo.
     }
  }

//+------------------------------------------------------------------+
//| Dong toan bo vi the cua 1 chieu (basket)                          |
//+------------------------------------------------------------------+
void CloseAllPositions(ENUM_POSITION_TYPE type)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type)
         continue;

      trade.PositionClose(ticket);
     }
  }

//+------------------------------------------------------------------+
//| Tao nhan hien thi Net Profit Today (chi tao 1 lan)                |
//+------------------------------------------------------------------+
void CreateProfitLabel()
  {
   if(ObjectFind(0, g_profitLabel) >= 0)
      return;

   ObjectCreate(0, g_profitLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_profitLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, g_profitLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, g_profitLabel, OBJPROP_XDISTANCE, 85);
   ObjectSetInteger(0, g_profitLabel, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, g_profitLabel, OBJPROP_FONTSIZE, 11);
   ObjectSetString(0, g_profitLabel, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, g_profitLabel, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, g_profitLabel, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_profitLabel, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, g_profitLabel, OBJPROP_BACK, false);
  }

//+------------------------------------------------------------------+
//| Tinh lai/lo rong trong ngay: da chot (history) + dang mo (floating)|
//+------------------------------------------------------------------+
void CalculateNetProfitToday(double &netProfit, double &percent)
  {
   datetime dayStart = iTime(_Symbol, PERIOD_D1, 0);
   double realizedToday = 0.0;

   HistorySelect(dayStart, TimeCurrent());
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
     {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0)
         continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != (long)InpMagicNumber)
         continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol)
         continue;

      realizedToday += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                      + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION)
                      + HistoryDealGetDouble(dealTicket, DEAL_SWAP);
     }

   double floatingNow = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      floatingNow += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }

   netProfit = realizedToday + floatingNow;

   double currentBalance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double dayStartBalance = currentBalance - realizedToday;

   percent = (dayStartBalance != 0.0) ? (netProfit / dayStartBalance * 100.0) : 0.0;
  }

//+------------------------------------------------------------------+
//| Cap nhat noi dung nhan Net Profit Today                           |
//+------------------------------------------------------------------+
void UpdateProfitLabel()
  {
   if(ObjectFind(0, g_profitLabel) < 0)
      CreateProfitLabel();

   double netProfit, percent;
   CalculateNetProfitToday(netProfit, percent);

   string sign = (netProfit >= 0) ? "+" : "";
   string text = StringFormat("Net Profit Today: %s%.2f %s | %s%.2f%%",
                               sign, netProfit, AccountInfoString(ACCOUNT_CURRENCY),
                               sign, percent);

   color clr = (netProfit >= 0) ? clrLime : clrRed;

   ObjectSetString(0, g_profitLabel, OBJPROP_TEXT, text);
   ObjectSetInteger(0, g_profitLabel, OBJPROP_COLOR, clr);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Tao 1 khung nen (rectangle label) cho panel, tinh tu goc tren-trai|
//+------------------------------------------------------------------+
void CreatePanelBox(const string name, int y, int height)
  {
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, MonthPanelInset);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, MonthPanelWidth);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'22,30,52');
   ObjectSetInteger(0, name, OBJPROP_COLOR, C'45,60,95');
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
  }

//+------------------------------------------------------------------+
//| Tao 1 nhan chu cho panel                                          |
//+------------------------------------------------------------------+
void CreatePanelText(const string name, int x, int y, ENUM_ANCHOR_POINT anchor,
                     int fontSize, const string font, color clr)
  {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
  }

//+------------------------------------------------------------------+
//| Toa do Y (tinh tu dinh chart) cua dong du lieu thu i              |
//| 4 dong dau nam o khung tren, 2 dong sau nam o khung duoi.         |
//+------------------------------------------------------------------+
int PanelRowY(int i)
  {
   int topBoxH = MonthPanelTopRows * MonthPanelRowH + 2 * MonthPanelPad;
   if(i < MonthPanelTopRows)
      return MonthPanelY + MonthPanelPad + i * MonthPanelRowH + 3;
   return MonthPanelY + topBoxH + MonthPanelGap + MonthPanelPad
          + (i - MonthPanelTopRows) * MonthPanelRowH + 3;
  }

//+------------------------------------------------------------------+
//| Tao PANEL BAO CAO kieu 2 khung (giong mau):                        |
//|  Khung tren : Gia tri dau vao / Ket qua / Lai/lo /                 |
//|               Ngay bat dau                                         |
//|  Khung duoi : Ket qua hom nay / Trang thai hien tai                |
//| Moi dong gom: icon (trai) + ten (trai) + gia tri (phai).           |
//| Chi tao 1 lan; goi lai sau do chi cap nhat noi dung (Update...).  |
//+------------------------------------------------------------------+
void CreateMonthlyLabel()
  {
   string bgName = g_monthPrefix + "Bg";
   if(ObjectFind(0, bgName) >= 0)
      return; // da tao roi

   int topBoxH    = MonthPanelTopRows * MonthPanelRowH + 2 * MonthPanelPad;
   int bottomRows = MonthPanelRows - MonthPanelTopRows;
   int bottomBoxH = bottomRows * MonthPanelRowH + 2 * MonthPanelPad;

   CreatePanelBox(bgName, MonthPanelY, topBoxH);
   CreatePanelBox(g_monthPrefix + "Bg2", MonthPanelY + topBoxH + MonthPanelGap, bottomBoxH);

   //--- Icon, mau icon va mau ten cho tung dong (giong anh mau)
   ushort iconCode[6]  = {0x25C6, 0x25B2, 0x25A0, 0x25A1, 0x25B2, 0x25CF}; // kim cuong, tam giac, vuong dac, vuong rong, tam giac, cham tron
   color  iconColor[6] = {C'150,160,185', C'70,200,130', C'235,190,50',
                          C'100,150,235', C'70,200,130', C'150,160,185'};
   color  nameColor[6] = {C'170,180,200', C'140,220,195', C'235,200,90',
                          C'110,160,240', C'170,180,200', C'170,180,200'};

   int leftX  = MonthPanelInset + 10;                   // mep trai noi dung
   int rightX = MonthPanelInset + MonthPanelWidth - 12; // mep phai cot gia tri
   for(int i = 0; i < MonthPanelRows; i++)
     {
      int rowY = PanelRowY(i);

      string iconObj = g_monthPrefix + "Icon" + IntegerToString(i);
      CreatePanelText(iconObj, leftX, rowY + 1, ANCHOR_LEFT_UPPER, 8, "Arial", iconColor[i]);
      ObjectSetString(0, iconObj, OBJPROP_TEXT, ShortToString(iconCode[i]));

      CreatePanelText(g_monthPrefix + "Name" + IntegerToString(i), leftX + 18, rowY,
                      ANCHOR_LEFT_UPPER, 10, "Arial", nameColor[i]);

      CreatePanelText(g_monthPrefix + "Value" + IntegerToString(i), rightX, rowY,
                      ANCHOR_RIGHT_UPPER, 10, "Arial", clrWhite);
     }
  }

//+------------------------------------------------------------------+
//| Thoi diem 00:00 ngay 1 cua thang hien tai (gio SERVER)             |
//+------------------------------------------------------------------+
datetime GetMonthStart()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.day  = 1;
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
  }

//+------------------------------------------------------------------+
//| Tinh so lieu bao cao thang: von dau ky, da nap/rut, lai/lo da      |
//| chot trong thang, lai/lo dang mo (floating). Chi tinh tren cac     |
//| lenh cua CHINH EA nay (loc theo Magic + Symbol); rieng cac giao    |
//| dich Nap/Rut (DEAL_TYPE_BALANCE) khong gan Magic/Symbol nen luon   |
//| duoc tinh cho toan tai khoan.                                      |
//+------------------------------------------------------------------+
void CalculateMonthlyStats(double &startBalance, double &deposits, double &withdrawals,
                            double &realizedMonth, double &floatingNow, datetime &monthStart)
  {
   monthStart    = GetMonthStart();
   deposits      = 0.0;
   withdrawals   = 0.0;
   realizedMonth = 0.0;

   HistorySelect(monthStart, TimeCurrent());
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
     {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0)
         continue;

      ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      if(dealType == DEAL_TYPE_BALANCE)
        {
         // Giao dich Nap/Rut tien thu cong, khong phai lenh giao dich
         double amount = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         if(amount >= 0.0)
            deposits += amount;
         else
            withdrawals += amount; // giu am, la so tien da rut
         continue;
        }

      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != (long)InpMagicNumber)
         continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol)
         continue;

      realizedMonth += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                      + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION)
                      + HistoryDealGetDouble(dealTicket, DEAL_SWAP);
     }

   floatingNow = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      floatingNow += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }

   // Von dau ky = so du hien tai, tru lui phan da nap/rut va lai/lo da chot trong thang
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   startBalance = currentBalance - deposits - withdrawals - realizedMonth;
  }

//+------------------------------------------------------------------+
//| Dinh dang so tien co dau phay ngan cach hang nghin: 50,000.00     |
//+------------------------------------------------------------------+
string FormatMoney(double v)
  {
   string s   = DoubleToString(MathAbs(v), 2);
   int    dot = StringFind(s, ".");
   string intPart = StringSubstr(s, 0, dot);
   int    n   = StringLen(intPart);

   string res = "";
   for(int i = 0; i < n; i++)
     {
      if(i > 0 && (n - i) % 3 == 0)
         res += ",";
      res += StringSubstr(intPart, i, 1);
     }
   return ((NormalizeDouble(v, 2) < 0.0) ? "-" : "") + res + StringSubstr(s, dot);
  }

//+------------------------------------------------------------------+
//| Cap nhat noi dung PANEL BAO CAO: 6 dong du lieu. Gia tri o khung   |
//| tren mau trang; 2 dong khung duoi xanh = lai, do = lo.            |
//+------------------------------------------------------------------+
void UpdateMonthlyLabel()
  {
   if(ObjectFind(0, g_monthPrefix + "Bg") < 0)
      CreateMonthlyLabel();

   double startBalance, deposits, withdrawals, realizedMonth, floatingNow;
   datetime monthStart;
   CalculateMonthlyStats(startBalance, deposits, withdrawals, realizedMonth, floatingNow, monthStart);

   double todayNet, todayPercent;
   CalculateNetProfitToday(todayNet, todayPercent);

   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double inputValue      = startBalance + deposits;          // "Gia tri dau vao" = von dau ky + tien nap trong ky
   double resultNow       = currentBalance + floatingNow;     // "Ket qua" = so du + dang mo
   double monthPL         = realizedMonth + floatingNow;      // "Lai/lo" thang do EA tao ra (khong tinh nap/rut)

   MqlDateTime ms;
   TimeToStruct(monthStart, ms);

   string names[6] = {"Gia tri dau vao", "Ket qua", "Lai/lo", "Ngay bat dau",
                      "Ket qua hom nay", "Trang thai hien tai"};
   string values[6];
   color  colors[6];

   values[0] = FormatMoney(inputValue);
   colors[0] = clrWhite;

   values[1] = FormatMoney(resultNow);
   colors[1] = clrWhite;

   values[2] = FormatMoney(monthPL);
   colors[2] = (monthPL >= 0) ? (color)C'80,220,140' : (color)C'255,90,90';     // lai/lo - xanh/do

   values[3] = StringFormat("%02d/%02d/%04d", ms.day, ms.mon, ms.year);
   colors[3] = clrWhite;

   values[4] = FormatMoney(todayNet);
   colors[4] = (todayNet >= 0) ? (color)C'80,220,140' : (color)C'255,90,90';    // hom nay - xanh/do

   values[5] = FormatMoney(floatingNow);
   colors[5] = (floatingNow >= 0) ? (color)C'80,220,140' : (color)C'255,90,90'; // dang mo - xanh/do

   for(int i = 0; i < MonthPanelRows; i++)
     {
      string nameObj = g_monthPrefix + "Name"  + IntegerToString(i);
      string valObj  = g_monthPrefix + "Value" + IntegerToString(i);

      ObjectSetString(0, nameObj, OBJPROP_TEXT, names[i]);
      ObjectSetString(0, valObj,  OBJPROP_TEXT, values[i]);
      ObjectSetInteger(0, valObj, OBJPROP_COLOR, colors[i]);
     }

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Tao nhan hien thi trang thai tin tuc (chi tao 1 lan)               |
//+------------------------------------------------------------------+
void CreateNewsLabel()
  {
   if(ObjectFind(0, g_newsLabel) >= 0)
      return;

   ObjectCreate(0, g_newsLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_newsLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, g_newsLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, g_newsLabel, OBJPROP_XDISTANCE, 85);
   ObjectSetInteger(0, g_newsLabel, OBJPROP_YDISTANCE, 45);
   ObjectSetInteger(0, g_newsLabel, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, g_newsLabel, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, g_newsLabel, OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, g_newsLabel, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_newsLabel, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, g_newsLabel, OBJPROP_BACK, false);
  }

//+------------------------------------------------------------------+
//| Dang trong khung gio tam dung vi tin? Truy van lich tin toi da    |
//| 1 lan/60 giay (lich tin thay doi cham, goi moi tick rat ton may). |
//+------------------------------------------------------------------+
bool IsNewsBlackout()
  {
   datetime now = TimeCurrent();
   if(g_newsCheckTime == 0 || now - g_newsCheckTime >= 60)
     {
      g_newsCached    = QueryNewsBlackout();
      g_newsCheckTime = now;
     }
   return g_newsCached;
  }

//+------------------------------------------------------------------+
//| Kiem tra xem hien tai co dang trong khung gio "tam dung vi tin"   |
//| hay khong: tin quan trong (>= InpNewsImportance) cua dong tien    |
//| lien quan den symbol, trong khoang truoc/sau tin da cau hinh      |
//+------------------------------------------------------------------+
bool QueryNewsBlackout()
  {
   string baseCur   = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   string profitCur = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
   datetime now = TimeCurrent();

   int maxMinutes = MathMax(InpNewsBeforeMinutes, InpNewsAfterMinutes);
   datetime searchFrom = now - InpNewsAfterMinutes * 60 - maxMinutes * 60;
   datetime searchTo   = now + InpNewsBeforeMinutes * 60 + maxMinutes * 60;

   string currencies[2];
   currencies[0] = baseCur;
   currencies[1] = profitCur;

   for(int c = 0; c < 2; c++)
     {
      if(currencies[c] == "")
         continue;

      MqlCalendarValue values[];
      if(!CalendarValueHistory(values, searchFrom, searchTo, NULL, currencies[c]))
         continue;

      for(int i = 0; i < ArraySize(values); i++)
        {
         MqlCalendarEvent evt;
         if(!CalendarEventById(values[i].event_id, evt))
            continue;
         if(evt.importance < InpNewsImportance)
            continue;

         datetime eventTime    = values[i].time;
         datetime blackoutFrom = eventTime - InpNewsBeforeMinutes * 60;
         datetime blackoutTo   = eventTime + InpNewsAfterMinutes * 60;

         if(now >= blackoutFrom && now <= blackoutTo)
            return true;
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Cap nhat noi dung nhan trang thai tin tuc                         |
//+------------------------------------------------------------------+
void UpdateNewsLabel()
  {
   if(ObjectFind(0, g_newsLabel) < 0)
      CreateNewsLabel();

   bool blackout = IsNewsBlackout();
   string text = blackout ? "Tin tuc: TAM DUNG (co tin quan trong)" : "Tin tuc: An toan";
   color clr = blackout ? clrOrange : clrLime;

   ObjectSetString(0, g_newsLabel, OBJPROP_TEXT, text);
   ObjectSetInteger(0, g_newsLabel, OBJPROP_COLOR, clr);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Ma hoa URL (UTF-8 percent-encoding) de gui tieng Viet an toan     |
//+------------------------------------------------------------------+
string UrlEncode(const string text)
  {
   uchar utf8[];
   int len = StringToCharArray(text, utf8, 0, -1, CP_UTF8);
   string result = "";
   uchar oneChar[1];

   for(int i = 0; i < len; i++)
     {
      uchar b = utf8[i];
      if(b == 0)
         continue;
      if((b >= 'A' && b <= 'Z') || (b >= 'a' && b <= 'z') || (b >= '0' && b <= '9') ||
         b == '-' || b == '_' || b == '.' || b == '~')
        {
         oneChar[0] = b;
         result += CharArrayToString(oneChar, 0, 1, CP_ACP);
        }
      else
         result += StringFormat("%%%02X", b);
     }
   return result;
  }

//+------------------------------------------------------------------+
//| Gui 1 tin nhan van ban toi Telegram qua Bot API                   |
//+------------------------------------------------------------------+
void SendTelegramMessage(const string text)
  {
   if(!InpUseTelegram || InpTelegramBotToken == "" || InpTelegramChatID == "")
      return;

   string url = "https://api.telegram.org/bot" + InpTelegramBotToken +
                "/sendMessage?chat_id=" + InpTelegramChatID +
                "&text=" + UrlEncode(text);

   char   data[];
   char   result[];
   string resultHeaders;

   ResetLastError();
   int res = WebRequest("GET", url, NULL, 5000, data, result, resultHeaders);

   if(res == -1)
     {
      int err = GetLastError();
      Print("Gui Telegram that bai, ma loi: ", err,
            " - Kiem tra da them https://api.telegram.org vao Tools > Options > Expert Advisors > Allow WebRequest for listed URL");
     }
  }

//+------------------------------------------------------------------+
//| So sanh trang thai hien tai voi lan truoc, gui thong bao Telegram |
//| khi co su kien: khop lenh, DCA them, chot loi, tam dung vi tin    |
//+------------------------------------------------------------------+
void CheckAndNotifyEvents(bool newsBlackout)
  {
   int buyCount  = CountPositions(POSITION_TYPE_BUY);
   int sellCount = CountPositions(POSITION_TYPE_SELL);

   if(buyCount > g_prevBuyCount)
      SendTelegramMessage(StringFormat("DCA them lenh BUY [%s] - tong %d lenh dang mo", _Symbol, buyCount));
   if(sellCount > g_prevSellCount)
      SendTelegramMessage(StringFormat("DCA them lenh SELL [%s] - tong %d lenh dang mo", _Symbol, sellCount));

   if(g_state != g_prevNotifyState)
     {
      if(g_state == STATE_BUY)
         SendTelegramMessage(StringFormat("Buy Stop da khop [%s] - bat dau basket BUY", _Symbol));
      else if(g_state == STATE_SELL)
         SendTelegramMessage(StringFormat("Sell Stop da khop [%s] - bat dau basket SELL", _Symbol));
      else if(g_state == STATE_IDLE && g_prevNotifyState != STATE_IDLE)
        {
         double netProfit, percent;
         CalculateNetProfitToday(netProfit, percent);
         SendTelegramMessage(StringFormat("Da chot loi basket [%s]. Lai/lo hom nay: %.2f %s (%.2f%%)",
                                           _Symbol, netProfit, AccountInfoString(ACCOUNT_CURRENCY), percent));
        }
     }

   if(newsBlackout && !g_prevNewsBlackout)
      SendTelegramMessage(StringFormat("Tam dung giao dich [%s] - sap co tin quan trong", _Symbol));
   else if(!newsBlackout && g_prevNewsBlackout)
      SendTelegramMessage(StringFormat("Het gio tin [%s] - tiep tuc giao dich binh thuong", _Symbol));

   g_prevNotifyState  = g_state;
   g_prevBuyCount     = buyCount;
   g_prevSellCount    = sellCount;
   g_prevNewsBlackout = newsBlackout;
  }

//+------------------------------------------------------------------+
//| Tao nhan trang thai DCA (chi tao 1 lan)                           |
//+------------------------------------------------------------------+
void CreateDCALabel()
  {
   if(ObjectFind(0, g_dcaLabel) >= 0)
      return;

   ObjectCreate(0, g_dcaLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_dcaLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, g_dcaLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, g_dcaLabel, OBJPROP_XDISTANCE, 85);
   ObjectSetInteger(0, g_dcaLabel, OBJPROP_YDISTANCE, 65);
   ObjectSetInteger(0, g_dcaLabel, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, g_dcaLabel, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, g_dcaLabel, OBJPROP_COLOR, clrSilver);
   ObjectSetInteger(0, g_dcaLabel, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_dcaLabel, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, g_dcaLabel, OBJPROP_BACK, false);
  }

//+------------------------------------------------------------------+
//| Cap nhat nhan trang thai DCA: dang cho phep hay dang bi cam, va   |
//| bi cam vi ly do gi (nen nguoc lien tiep / gia truot qua nhanh)    |
//+------------------------------------------------------------------+
void UpdateDCALabel()
  {
   if(ObjectFind(0, g_dcaLabel) < 0)
      CreateDCALabel();

   string text;
   color  clr;

   // Uu tien hien cac cong chan o muc cao hon truoc
   if(!g_eaEnabled)
     {
      text = "EA: DA DUNG (/stop tu Telegram)";
      clr  = clrRed;
     }
   else if(IsManualPaused())
     {
      text = StringFormat("EA: TAM DUNG den %s (gio server)", TimeToString(g_pauseUntil, TIME_MINUTES));
      clr  = clrOrange;
     }
   else if(!IsWithinTradingHours())
     {
      text = StringFormat("EA: NGOAI KHUNG GIO  |  gio server %s",
                           TimeToString(TimeCurrent(), TIME_MINUTES));
      clr  = clrOrange;
     }
   else if(g_state != STATE_BUY && g_state != STATE_SELL)
     {
      double adx, plusDI, minusDI;
      if(!InpUseADXFilter)
        {
         text = StringFormat("DCA: chua co basket  |  he so x%.2f, DCA %s, TP %s  |  gio server %s",
                              g_scale, DoubleToString(DistDCA(), _Digits),
                              DoubleToString(GetTPDistance(InpInitialLot), _Digits),
                              TimeToString(TimeCurrent(), TIME_MINUTES));
         clr  = clrSilver;
        }
      else if(!GetADXValues(adx, plusDI, minusDI))
        {
         text = "ADX: dang tai du lieu...";
         clr  = clrSilver;
        }
      else if(adx < InpADXLevel)
        {
         text = StringFormat("ADX %.1f < %.0f: cho xu huong, chua vao lenh", adx, InpADXLevel);
         clr  = clrSilver;
        }
      else
        {
         text = StringFormat("ADX %.1f: chi %s (+DI %.1f / -DI %.1f)", adx,
                              (plusDI > minusDI ? "BUY STOP" : "SELL STOP"), plusDI, minusDI);
         clr  = clrLime;
        }
     }
   else
     {
      ENUM_POSITION_TYPE type = (g_state == STATE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      int streak = CountAgainstCandles(type);

      if(IsPriceMovingTooFast())
        {
         text = "DCA: CAM - gia truot qua nhanh";
         clr  = clrOrange;
        }
      else if(IsCandleTrendAgainst(type))
        {
         text = StringFormat("DCA: CAM - %d nen nguoc lien tiep, cho nen dao chieu", streak);
         clr  = clrOrange;
        }
      else
        {
         text = StringFormat("DCA: cho phep (nen nguoc lien tiep: %d/%d)",
                              streak, InpMaxAgainstCandles);
         clr  = clrLime;
        }
     }

   ObjectSetString(0, g_dcaLabel, OBJPROP_TEXT, text);
   ObjectSetInteger(0, g_dcaLabel, OBJPROP_COLOR, clr);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Tao duong ke gia TP cua basket (chi tao 1 lan)                    |
//+------------------------------------------------------------------+
void CreateTPLine()
  {
   if(ObjectFind(0, g_tpLine) >= 0)
      return;

   ObjectCreate(0, g_tpLine, OBJ_HLINE, 0, 0, 0);
   ObjectSetInteger(0, g_tpLine, OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, g_tpLine, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, g_tpLine, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, g_tpLine, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_tpLine, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, g_tpLine, OBJPROP_BACK, true);
  }

//+------------------------------------------------------------------+
//| Cap nhat vi tri duong ke TP theo gia trung binh basket hien tai.  |
//| Chi hien khi dang co basket chay (BUY hoac SELL), an di neu IDLE. |
//+------------------------------------------------------------------+
void UpdateTPLine()
  {
   if(g_state != STATE_BUY && g_state != STATE_SELL)
     {
      ObjectDelete(0, g_tpLine);
      return;
     }

   ENUM_POSITION_TYPE type = (g_state == STATE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   double avgPrice = GetBasketAveragePrice(type);
   if(avgPrice <= 0.0)
      return;

   double dist    = GetTPDistance(GetBasketTotalLot(type));
   int    digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double tpPrice = (type == POSITION_TYPE_BUY) ? avgPrice + dist
                                                 : avgPrice - dist;
   tpPrice = NormalizeDouble(tpPrice, digits);

   if(ObjectFind(0, g_tpLine) < 0)
      CreateTPLine();

   ObjectSetDouble(0, g_tpLine, OBJPROP_PRICE, tpPrice);
   ObjectSetString(0, g_tpLine, OBJPROP_TEXT,
                    StringFormat("TP Basket (%d lenh): %s", CountPositions(type), DoubleToString(tpPrice, digits)));
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Trich gia tri chuoi tu JSON tho theo key (vd "text":"/stop")      |
//+------------------------------------------------------------------+
string ExtractJsonString(const string json, const string key, int startPos, int &foundAt)
  {
   string pattern = "\"" + key + "\":\"";
   int p = StringFind(json, pattern, startPos);
   foundAt = p;
   if(p < 0)
      return "";

   p += StringLen(pattern);
   int end = StringFind(json, "\"", p);
   if(end < 0)
      return "";

   return StringSubstr(json, p, end - p);
  }

//+------------------------------------------------------------------+
//| Trich gia tri so tu JSON tho theo key (vd "update_id":123)        |
//+------------------------------------------------------------------+
long ExtractJsonNumber(const string json, const string key, int startPos)
  {
   string pattern = "\"" + key + "\":";
   int p = StringFind(json, pattern, startPos);
   if(p < 0)
      return -1;

   p += StringLen(pattern);
   string num = "";
   for(int i = p; i < StringLen(json); i++)
     {
      ushort c = StringGetCharacter(json, i);
      if(c >= '0' && c <= '9')
         num += ShortToString(c);
      else
         break;
     }

   if(num == "")
      return -1;
   return (long)StringToInteger(num);
  }

//+------------------------------------------------------------------+
//| Dong toan bo lenh dang mo cua EA (ca 2 chieu) + huy lenh cho      |
//+------------------------------------------------------------------+
void CloseEverything()
  {
   CloseAllPositions(POSITION_TYPE_BUY);
   CloseAllPositions(POSITION_TYPE_SELL);
   CancelOppositePending(ORDER_TYPE_BUY_STOP);
   CancelOppositePending(ORDER_TYPE_SELL_STOP);
  }

//+------------------------------------------------------------------+
//| Xu ly 1 lenh dieu khien nhan tu Telegram                          |
//+------------------------------------------------------------------+
void HandleTelegramCommand(const string cmd)
  {
   string c = cmd;
   StringToLower(c);
   StringTrimLeft(c);
   StringTrimRight(c);

   if(StringFind(c, "/stop") == 0)
     {
      g_eaEnabled = false;
      CloseEverything();
      SendTelegramMessage(StringFormat("DA DUNG EA [%s]: da dong toan bo lenh va huy lenh cho. Nhan /start de chay lai.", _Symbol));
     }
   else if(StringFind(c, "/start") == 0)
     {
      g_eaEnabled  = true;
      g_pauseUntil = 0;   // huy luon lenh /pause dang treo
      SendTelegramMessage(StringFormat("DA BAT LAI EA [%s]: tiep tuc giao dich binh thuong.", _Symbol));
     }
   else if(StringFind(c, "/pause") == 0)
     {
      // Cu phap: /pause 30  -> tam dung 30 phut roi tu dong chay lai
      int mins = 30;
      int sp = StringFind(c, " ");
      if(sp > 0)
        {
         string arg = StringSubstr(c, sp + 1);
         StringTrimLeft(arg); StringTrimRight(arg);
         int v = (int)StringToInteger(arg);
         if(v > 0) mins = v;
        }
      g_pauseUntil = TimeCurrent() + mins * 60;
      SendTelegramMessage(StringFormat(
         "TAM DUNG [%s] %d phut (den %s gio server). Cac lenh dang mo van cho TP. Nhan /start de chay lai ngay.",
         _Symbol, mins, TimeToString(g_pauseUntil, TIME_MINUTES)));
     }
   else if(StringFind(c, "/status") == 0)
     {
      double netProfit, percent;
      CalculateNetProfitToday(netProfit, percent);
      int buyCount  = CountPositions(POSITION_TYPE_BUY);
      int sellCount = CountPositions(POSITION_TYPE_SELL);

      string gate = "DANG CHAY";
      if(!g_eaEnabled)                  gate = "DA DUNG (/stop)";
      else if(IsManualPaused())         gate = StringFormat("TAM DUNG den %s", TimeToString(g_pauseUntil, TIME_MINUTES));
      else if(!IsWithinTradingHours())  gate = "NGOAI KHUNG GIO";
      else if(InpUseNewsFilter && IsNewsBlackout()) gate = "TAM DUNG vi tin tuc";

      string statusText = StringFormat(
         "TRANG THAI [%s]\nEA: %s\nGio server: %s\nLenh BUY: %d\nLenh SELL: %d\nTong lot: %.2f\nLai/lo hom nay: %.2f %s (%.2f%%)",
         _Symbol, gate,
         TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
         buyCount, sellCount,
         GetBasketTotalLot(buyCount > 0 ? POSITION_TYPE_BUY : POSITION_TYPE_SELL),
         netProfit, AccountInfoString(ACCOUNT_CURRENCY), percent);

      SendTelegramMessage(statusText);
     }
  }

//+------------------------------------------------------------------+
//| Doc tin nhan moi tu Telegram va thuc thi lenh dieu khien          |
//+------------------------------------------------------------------+
void PollTelegramCommands()
  {
   if(!InpUseTelegram || !InpTelegramControl)
      return;
   if(InpTelegramBotToken == "" || InpTelegramChatID == "")
      return;

   string url = "https://api.telegram.org/bot" + InpTelegramBotToken +
                "/getUpdates?timeout=0&limit=10";
   if(g_telegramOffset > 0)
      url += "&offset=" + IntegerToString(g_telegramOffset + 1);

   char   data[];
   char   result[];
   string resultHeaders;

   ResetLastError();
   int res = WebRequest("GET", url, NULL, 5000, data, result, resultHeaders);

   if(res == -1)
     {
      int err = GetLastError();
      Print("[Telegram] Doc lenh THAT BAI, ma loi ", err,
            ". Neu 4060: chua them https://api.telegram.org vao Tools > Options > Expert Advisors > Allow WebRequest for listed URL.");
      return;
     }
   if(res != 200)
     {
      Print("[Telegram] Doc lenh tra ve HTTP ", res,
            " - thuong la Bot Token sai hoac da bi revoke. Kiem tra lai token tu @BotFather.");
      return;
     }

   string json = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);

   // Lan poll dau tien sau khi EA khoi dong: CHI ghi nhan update_id moi nhat,
   // KHONG thuc thi, de tranh chay lai cac lenh /stop //pause cu tu hom truoc.
   if(g_telegramFirstPoll)
     {
      g_telegramFirstPoll = false;
      int sp = 0; long maxId = -1; int cnt = 0;
      while(true)
        {
         int p = StringFind(json, "\"update_id\":", sp);
         if(p < 0) break;
         long uid = ExtractJsonNumber(json, "update_id", sp);
         if(uid > maxId) maxId = uid;
         sp = p + 12; cnt++;
        }
      if(maxId > 0)
         g_telegramOffset = maxId;
      Print("[Telegram] Ket noi OK. Bo qua ", cnt, " tin cu, bat dau nhan lenh moi tu day.");
      return;
     }

   // Duyet tuan tu tung update trong mang "result"
   int searchPos = 0;
   while(true)
     {
      long updateId = ExtractJsonNumber(json, "update_id", searchPos);
      if(updateId < 0)
         break;

      int updateIdPos = StringFind(json, "\"update_id\":", searchPos);
      if(updateIdPos < 0)
         break;

      // Chi chap nhan lenh tu dung Chat ID da cau hinh (bao mat)
      string chatIdStr = "";
      int chatBlockPos = StringFind(json, "\"chat\":", updateIdPos);
      if(chatBlockPos >= 0)
        {
         long cid = ExtractJsonNumber(json, "id", chatBlockPos);
         if(cid >= 0)
            chatIdStr = IntegerToString(cid);
        }

      int textPos;
      string msgText = ExtractJsonString(json, "text", updateIdPos, textPos);

      if(msgText != "" && chatIdStr == InpTelegramChatID)
         HandleTelegramCommand(msgText);

      g_telegramOffset = updateId;
      searchPos = updateIdPos + 12;
     }
  }

//+------------------------------------------------------------------+
//| QUY DOI KHOANG CACH GIA SANG MA KHAC (vd USTEC)                    |
//| Cac input khoang cach nhap theo kieu VANG; EA nhan voi he so =     |
//| ATR ngay cua ma dang chay / ATR ngay cua ma vang tham chieu.       |
//+------------------------------------------------------------------+
double DistInit()     { return InpInitialDistance      * g_scale; }
double DistDCA()      { return InpDCADistance          * g_scale; }
double DistVolMove()  { return InpMaxPriceMoveInWindow * g_scale; }
double DistFastMove() { return InpFastMoveDistance     * g_scale; }
double DistTPPrice()  { return InpTPPrice              * g_scale; }

//+------------------------------------------------------------------+
//| Tien cua 1 lot khi gia chay 1 don vi gia (0 = chua co du lieu san) |
//+------------------------------------------------------------------+
double MoneyPerPriceUnit()
  {
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0)
      return 0.0;
   return tickValue / tickSize;
  }

//+------------------------------------------------------------------+
//| Goi trong OnInit. False = khong the quy doi -> dung EA             |
//+------------------------------------------------------------------+
bool InitPriceScale()
  {
   if(InpPriceScale > 0.0)
     {
      g_scale        = InpPriceScale;
      g_scaleReady   = true;
      g_scaleFromATR = true;
      LogPriceScale("he so tu nhap", 0.0, 0.0);
      return true;
     }
   if(InpScaleRefSymbol == "" || InpScaleRefSymbol == _Symbol)
     {
      g_scale        = 1.0;   // chinh la ma vang -> giu nguyen
      g_scaleReady   = true;
      g_scaleFromATR = true;
      LogPriceScale("ma tham chieu", 0.0, 0.0);
      return true;
     }
   if(!SymbolSelect(InpScaleRefSymbol, true))
     {
      Print("[Quy doi] Khong tim thay ma tham chieu '", InpScaleRefSymbol, "' tren san. ",
            "Sua InpScaleRefSymbol cho dung ten ma vang, hoac nhap InpPriceScale (vd 6.0).");
      return false;
     }
   g_atrSelf = iATR(_Symbol, PERIOD_D1, 14);
   g_atrRef  = iATR(InpScaleRefSymbol, PERIOD_D1, 14);
   if(g_atrSelf == INVALID_HANDLE || g_atrRef == INVALID_HANDLE)
     {
      Print("[Quy doi] Khong tao duoc chi bao ATR, ma loi ", GetLastError());
      return false;
     }
   UpdatePriceScale();
   return true;
  }

//+------------------------------------------------------------------+
//| Tinh he so tu ATR ngay (nen da dong). Chua co du lieu ATR thi tam  |
//| dung ti le gia; goi lai moi lan OnTimer cho den khi co ATR, sau do |
//| chi tinh lai 1 lan moi ngay.                                       |
//+------------------------------------------------------------------+
void UpdatePriceScale()
  {
   if(g_atrSelf == INVALID_HANDLE || g_atrRef == INVALID_HANDLE)
      return;   // he so tu nhap hoac dang chay chinh ma vang

   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(g_scaleFromATR && today == g_scaleDay)
      return;   // da tinh tu ATR trong ngay

   double atrSelf[1], atrRef[1];
   if(CopyBuffer(g_atrSelf, 0, 1, 1, atrSelf) == 1 && CopyBuffer(g_atrRef, 0, 1, 1, atrRef) == 1
      && atrSelf[0] > 0.0 && atrRef[0] > 0.0)
     {
      g_scale        = atrSelf[0] / atrRef[0];
      g_scaleReady   = true;
      g_scaleFromATR = true;
      g_scaleDay     = today;
      LogPriceScale("ATR ngay", atrSelf[0], atrRef[0]);
      return;
     }

   if(g_scaleReady)
      return;   // dang dung he so tam, cho du lieu ATR
   double pSelf = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double pRef  = SymbolInfoDouble(InpScaleRefSymbol, SYMBOL_BID);
   if(pSelf > 0.0 && pRef > 0.0)
     {
      g_scale      = pSelf / pRef;
      g_scaleReady = true;
      LogPriceScale("TAM theo ti le gia, cho du lieu ATR", pSelf, pRef);
     }
  }

//+------------------------------------------------------------------+
//| In ra tab Experts cac khoang cach thuc te sau khi quy doi          |
//+------------------------------------------------------------------+
void LogPriceScale(const string source, double valSelf, double valRef)
  {
   double perUnit  = MoneyPerPriceUnit();
   string unitInfo = (perUnit > 0.0)
                     ? StringFormat("1 don vi gia = %.4f %s cho 0.01 lot", perUnit * 0.01,
                                    AccountInfoString(ACCOUNT_CURRENCY))
                     : "chua co gia tri diem";
   Print(StringFormat("[Quy doi] %s (%s): he so x%.3f [%.3f / %.3f] -> lenh cho %s, DCA %s, "
                      "tam dung %s, cat lo nhanh %s, TP cach gia TB %s | %s",
                      _Symbol, source, g_scale, valSelf, valRef,
                      DoubleToString(DistInit(), _Digits), DoubleToString(DistDCA(), _Digits),
                      DoubleToString(DistVolMove(), _Digits), DoubleToString(DistFastMove(), _Digits),
                      DoubleToString(GetTPDistance(InpInitialLot), _Digits), unitInfo));
  }

//+------------------------------------------------------------------+
//| CHONG DON LENH VAO 1 DIEM                                          |
//+------------------------------------------------------------------+
//| Lenh vua gui da duoc san chap nhan chua                            |
//+------------------------------------------------------------------+
bool TradeOK()
  {
   uint rc = trade.ResultRetcode();
   return (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED);
  }

//+------------------------------------------------------------------+
//| Chieu 'side' (0 = BUY, 1 = SELL) vua gui lenh trong vai giay?      |
//+------------------------------------------------------------------+
bool RecentlySent(int side)
  {
   return (InpMinSecondsBetweenOrders > 0 &&
           TimeCurrent() - g_lastOrderTime[side] < InpMinSecondsBetweenOrders);
  }

//+------------------------------------------------------------------+
//| Ghi nho lenh DCA vua gui: phai thay no trong danh sach vi the     |
//| (hoac qua 30 giay) moi duoc DCA tiep                               |
//+------------------------------------------------------------------+
void MarkDCASent(int side, int countBefore)
  {
   g_lastOrderTime[side] = TimeCurrent();
   g_expectCount[side]   = countBefore + 1;
   g_expectUntil[side]   = TimeCurrent() + 30;
  }

//+------------------------------------------------------------------+
//| Gia mo XA NHAT cua basket: BUY = thap nhat, SELL = cao nhat        |
//+------------------------------------------------------------------+
bool GetBasketEdgePrice(ENUM_POSITION_TYPE type, double &edge)
  {
   bool found = false;
   edge = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type)
         continue;

      double p = PositionGetDouble(POSITION_PRICE_OPEN);
      if(!found || (type == POSITION_TYPE_BUY ? p < edge : p > edge))
         edge = p;
      found = true;
     }
   return found;
  }

//+------------------------------------------------------------------+
//| Neu co hon 1 lenh Buy Stop (hoac Sell Stop) thi xoa bot, chi giu 1 |
//+------------------------------------------------------------------+
void RemoveDuplicatePendings()
  {
   ENUM_ORDER_TYPE types[2] = {ORDER_TYPE_BUY_STOP, ORDER_TYPE_SELL_STOP};
   for(int k = 0; k < 2; k++)
     {
      bool kept = false;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0)
            continue;
         if(OrderGetInteger(ORDER_MAGIC) != (long)InpMagicNumber)
            continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol)
            continue;
         if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != types[k])
            continue;
         if(!kept)
           {
            kept = true;   // giu lai lenh dau tien gap duoc
            continue;
           }
         if(trade.OrderDelete(ticket))
            Print("[Chong trung] Da xoa lenh cho thua #", ticket);
        }
     }
  }

//+------------------------------------------------------------------+
//| Lenh nguoc chieu lo khop cung luc voi basket chinh (ca Buy Stop va |
//| Sell Stop deu khop trong 1 cu giat): khong DCA, nhung van dat TP   |
//| len san va tu chot khi du loi, khong de bi bo quen.                |
//+------------------------------------------------------------------+
void ManageStrayPositions(ENUM_POSITION_TYPE type)
  {
   if(CountPositions(type) == 0)
      return;
   SyncBasketTPToBroker(type);
   CheckBasketTP(type);
  }

//+------------------------------------------------------------------+
//| Ngay khi 1 lenh vao khop (Stop khop hoac DCA), huy het lenh Stop   |
//| con lai ngay lap tuc, khong cho den tick sau -> Stop kia khong kip |
//| khop chong vao cung 1 diem trong cu giat.                          |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.symbol != _Symbol)
      return;
   if(!CanTrade() || !HistoryDealSelect(trans.deal))
      return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != (long)InpMagicNumber)
      return;
   if(HistoryDealGetInteger(trans.deal, DEAL_ENTRY) != DEAL_ENTRY_IN)
      return;

   int side = (HistoryDealGetInteger(trans.deal, DEAL_TYPE) == DEAL_TYPE_BUY) ? 0 : 1;
   g_lastOrderTime[side] = TimeCurrent();
   CancelOppositePending(ORDER_TYPE_BUY_STOP);
   CancelOppositePending(ORDER_TYPE_SELL_STOP);
  }

//+------------------------------------------------------------------+
//| KHOA 1 EA / SYMBOL / MAGIC                                         |
//| 2 GlobalVariable cua terminal: <ten> = ma phien cua EA dang giu   |
//| khoa, <ten>_HB = nhip tim (gio may). EA thu 2 cung magic tren cung |
//| symbol se DUNG CHO; khi EA dau tat (hoac treo qua nguong) thi EA   |
//| dang cho tu nhan khoa va chay tiep.                                |
//+------------------------------------------------------------------+
bool LockNeeded()
  {
   return (InpSingleInstance && !MQLInfoInteger(MQL_TESTER));
  }

bool CanTrade()
  {
   return (!LockNeeded() || g_lockOwned);
  }

int LockStaleSeconds()
  {
   return MathMax(60, 4 * InpRefreshSeconds);
  }

bool AcquireInstanceLock()
  {
   if(!LockNeeded())
      return true;

   if(g_lockName == "")
     {
      g_lockName   = StringFormat("CCBSN_LOCK_%s_%I64u", _Symbol, InpMagicNumber);
      g_lockHBName = g_lockName + "_HB";
      MathSrand((uint)GetTickCount());
      g_lockToken  = (double)(GetTickCount64() % 100000000) * 1000.0 + (double)(MathRand() % 1000) + 1.0;
     }

   if(GlobalVariableCheck(g_lockName) && GlobalVariableCheck(g_lockHBName))
     {
      double owner = GlobalVariableGet(g_lockName);
      double beat  = GlobalVariableGet(g_lockHBName);
      if(owner != g_lockToken && (double)TimeLocal() - beat < LockStaleSeconds())
         return false;   // EA khac cung magic dang chay va con song
     }

   GlobalVariableSet(g_lockName, g_lockToken);
   GlobalVariableSet(g_lockHBName, (double)TimeLocal());
   g_lockOwned = true;
   return true;
  }

//+------------------------------------------------------------------+
//| Goi trong OnTimer. True = EA nay dang giu khoa, duoc giao dich.    |
//+------------------------------------------------------------------+
bool InstanceHeartbeat()
  {
   if(!LockNeeded())
      return true;

   if(g_lockOwned)
     {
      // 2 EA gan cung luc va EA kia ghi de khoa -> nhuong, chuyen sang dung cho
      if(GlobalVariableCheck(g_lockName) && GlobalVariableGet(g_lockName) != g_lockToken)
        {
         g_lockOwned = false;
         Print("[Khoa] EA khac cung magic da giu khoa tren ", _Symbol, " -> EA nay chuyen sang DUNG CHO.");
         return false;
        }
      GlobalVariableSet(g_lockName, g_lockToken);
      GlobalVariableSet(g_lockHBName, (double)TimeLocal());
      return true;
     }

   if(AcquireInstanceLock())
     {
      Print("[Khoa] EA kia da tat -> EA nay nhan quyen giao dich tren ", _Symbol, ".");
      return true;
     }
   return false;
  }

void ReleaseInstanceLock()
  {
   if(!g_lockOwned || g_lockName == "")
      return;
   if(GlobalVariableCheck(g_lockName) && GlobalVariableGet(g_lockName) == g_lockToken)
     {
      GlobalVariableDel(g_lockName);
      GlobalVariableDel(g_lockHBName);
     }
   g_lockOwned = false;
  }

//+------------------------------------------------------------------+
//| Helpers                                                            |
//+------------------------------------------------------------------+
int CountPositions(ENUM_POSITION_TYPE type)
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type)
         count++;
     }
   return count;
  }

bool GetLastPositionInfo(ENUM_POSITION_TYPE type, double &outPrice, double &outLot)
  {
   datetime latestTime = 0;
   bool found = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type)
         continue;

      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(t >= latestTime)
        {
         latestTime = t;
         outPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         outLot   = PositionGetDouble(POSITION_VOLUME);
         found = true;
        }
     }
   return found;
  }

bool HasPendingOrderOfType(ENUM_ORDER_TYPE type)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != (long)InpMagicNumber)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) == type)
         return true;
     }
   return false;
  }

bool HasAnyPendingOrder()
  {
   return HasPendingOrderOfType(ORDER_TYPE_BUY_STOP) || HasPendingOrderOfType(ORDER_TYPE_SELL_STOP);
  }
//+------------------------------------------------------------------+
