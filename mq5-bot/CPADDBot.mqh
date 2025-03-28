//+------------------------------------------------------------------+
//|                                                     CPADDBot.mqh |
//|                                                  Denis Kislitsyn |
//|                                             https://kislitsyn.me |
//+------------------------------------------------------------------+
struct _SYSTEMTIME {
  ushort wYear;         // 2014 etc
  ushort wMonth;        // 1 - 12
  ushort wDayOfWeek;    // 0 - 6 with 0 = Sunday
  ushort wDay;          // 1 - 31
  ushort wHour;         // 0 - 23
  ushort wMinute;       // 0 - 59
  ushort wSecond;       // 0 - 59
  ushort wMilliseconds; // 0 - 999
};

#import "kernel32.dll"
  void GetLocalTime(_SYSTEMTIME &time);
#import

#include <Generic\HashMap.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayString.mqh>
#include <Charts\Chart.mqh>
#include <ChartObjects\ChartObjectsLines.mqh>
#include <ChartObjects\ChartObjectsArrows.mqh>
#include <Files\FileTxt.mqh>

#include "Include\DKStdLib\Common\DKStdLib.mqh"
#include "Include\DKStdLib\Common\DKDatetime.mqh"
#include "Include\DKStdLib\Common\CDKString.mqh"
#include "Include\DKStdLib\Logger\CDKLogger.mqh"
#include "Include\DKStdLib\TradingManager\CDKPositionInfo.mqh"
#include "Include\DKStdLib\TradingManager\CDKTrade.mqh"
#include "Include\DKStdLib\TradingManager\CDKTSLBE.mqh"
#include "Include\DKStdLib\TradingManager\CDKTSLStep.mqh"
#include "Include\DKStdLib\Drawing\DKChartDraw.mqh"
#include "Include\DKStdLib\Files\IniFile.mqh"
#include "Include\DKStdLib\Files\DKFiles.mqh"

#include "Include\DKStdLib\Bot\CDKBaseBot.mqh"
#include "CDKPriceLevel.mqh"
#include "CDKDivBarTag.mqh"

#include "TimeFilter.mqh"


enum ENUM_PADD_RSI_FILTER_MODE {
  PADD_RSI_FILTER_MODE_ALL = 0, // Все вершины
  PADD_RSI_FILTER_MODE_LAST = 1, // Последняя вершина
};

enum ENUM_FRACTAL_TYPE {
  FRACTAL_TYPE_UP   = 0, // Верх
  FRACTAL_TYPE_DOWN = 1, // Низ
};

enum ENUM_PADD_DIV_MODE {
  PADD_DIV_MODE_NO_DIV = 0, // Отключена
  PADD_DIV_MODE_DIV    = 1, // Только дивергенция
  PADD_DIV_MODE_CON    = 2, // Только конвергенция
  PADD_DIV_MODE_BOTH   = 3  // Дивергенция и конвергенция
};

enum ENUM_PADD_BOT_MODE {
  PADD_BOT_MODE_TRADING_FX = 1, // Торговля
  PADD_BOT_MODE_TESTING_BO_FIXED = 2, // Тест БО: Фиксированное время, мин
  PADD_BOT_MODE_TESTING_BO_EXPIRATION = 3 // Тест БО: Экспирация
};

enum ENUM_PADD_SHOULDER_EXTREME_FILTER_MODE {
  PADD_SHOULDER_EXTREME_FILTER_MODE_OFF   = 1, // Отключен
  PADD_SHOULDER_EXTREME_FILTER_MODE_LH_RH = 2, // Лево HIT(H/L) vs Право HIT(H/L)
  PADD_SHOULDER_EXTREME_FILTER_MODE_LH_RC = 3, // Лево HIT(H/L) vs Право CLOSE
};

struct TestResult {
  int    Time;
  string Hour;
  int    TotalCnt;
  int    ProfitCnt;
  int    LossCnt;
  double WinRate;
  
  void   InitZero() { TotalCnt = 0; ProfitCnt = 0; LossCnt = 0; }
  void   TestResult() { InitZero(); }
  
  int    IncTotal() { TotalCnt++; return TotalCnt; } 
  int    IncProfit() { ProfitCnt++; return ProfitCnt; } 
  int    IncLoss() { LossCnt++; return LossCnt; } 
  
  int    CalcLoss() { LossCnt = TotalCnt - ProfitCnt; return LossCnt; } 
  double CalcWinRate() { WinRate = (TotalCnt != 0) ? (double)ProfitCnt/(double)TotalCnt*100 : 0; return WinRate; } 
};

class CPADDBot : public CDKBaseBot {
 private:
  CHashMap<datetime, CDKPriceLevel*>    LevelHash;
  CHashMap<datetime, CDKPriceLevel*>    DivHash;
  CHashMap<datetime, CDKPriceLevel*>    RetestHash;
  datetime                              LastPosTime;

 public: // Settings
  ENUM_PADD_BOT_MODE       EN_Mode;                                                            // EN.MOD: Режим 
  bool                     ENEnable;                                                           // EN.E: Открывать сделки? 
  ENUM_MM_TYPE             ENMMType;                                                           // MMType: Money managmenet
  double                   ENMMValue;                                                          // MMValue
  
  uint                     ENSLDist;
  double                   EN_SL_AR_StopLoss_ATRRatio;                                         // EN.SL.AR: Множитель ATR для SL (0-откл)  
  uint                     ENTPDist;
  double                   ENTPRRRatio;
  uint                     EN_PD_PosDelayMin;                                                  // EN.PD: Мин. задержка между позициями (0-нет), мин
  
  uint                     TS_ED_S_EnterDelay_Sec;                                             // TS.ED.S: Задержка перед входом в позицию, сек
  string                   TS_FCA_M_FixedCloseAfter_Min;                                       // TS.FCA.M: Фиксированное время в сделке через ";", мин
  ENUM_TIMEFRAMES          TS_EC_TF_ExpClose_TF;                                               // TS.EC.TF: Таймфрейм определения экспирации
  string                   TS_EC_AL_M_ExpClose_AddBarWhenLessToClose_Min;                      // TS.EC.AL.M: Мин.время от стрелки до конца бара экспирации через ";", мин  
  TestResult               TS_Hour[][25];
  datetime                 TS_From;
  CArrayLong               TS_Times;
  
  bool                     ARREnable;                                                          // ARR.E: Рисовать стрелки?
  bool                     ARRReverse;                                                         // ARR.R: Реверс стрелок?
  int                      ARRBuyCode;                                                         // ARR.B.CD: Код стрелки BUY
  color                    ARRBuyColor;                                                        // ARR.B.CL: Цвет стрелки BUY
  int                      ARRSellCode;                                                        // ARR.B.CD: Код стрелки SELL
  color                    ARRSellColor;                                                       // ARR.B.CD: Цвет стрелки SELL  
  
  ENUM_TIMEFRAMES          FractalTF;                                                          // B.FTF: Timeframe фракталов
  uint                     LevelStartMin;                                                      // F.LST: Время начала действия уровня, мин  
  uint                     LevelExpirationMin;                                                 // B.LEX: Срок действия уровня, мин
  int                      LevelShiftPnt;                                                      // B.LSP: Доп. сдвиг уровня от фрактала, пункт
  uint                     F_F_OEN_Fractal_Filter_OnlyExtremeBar;                              // F.EDB: Фрактал выше/ниже всех за N баров (0-откл)
    
  bool                     FUEnable;                                                           // FU.E: Фрактал включен?
  uint                     FULeftBarCount;                                                     // FU.LBC: Свечей слева, шт
  bool                     FULeftHighSorted;                                                   // FU.LHS: HIGH свечей слева упорядочены
  bool                     FULeftLowSorted;                                                    // FU.LLS: LOW свечей слева упорядочены
  uint                     FURightBarCount;                                                    // FU.RBC: Свечей справа, шт
  bool                     FURightHighSorted;                                                  // FU.RHS: HIGH свечей справа упорядочены
  bool                     FURightLowSorted;                                                   // FU.RLS: LOW свечей справа упорядочены
  uint                     FUArrowCode;                                                        // FU.ACD: Код символа стрелки
  color                    FUArrowColor;                                                       // FU.ACL: Цвет стрелки
  
  bool                     FDEnable;                                                           // FD.E: Фрактал включен?
  uint                     FDLeftBarCount;                                                     // FD.LBC: Свечей слева, шт
  bool                     FDLeftHighSorted;                                                   // FD.LHS: HIGH свечей слева упорядочены
  bool                     FDLeftLowSorted;                                                    // FD.LLS: LOW свечей слева упорядочены
  uint                     FDRightBarCount;                                                    // FD.RBC: Свечей справа, шт
  bool                     FDRightHighSorted;                                                  // FD.RHS: HIGH свечей справа упорядочены
  bool                     FDRightLowSorted;                                                   // FD.RLS: LOW свечей справа упорядочены
  uint                     FDArrowCode;                                                        // FD.ACD: Код символа стрелки
  color                    FDArrowColor;                                                       // FD.ACL: Цвет стрелки
  
  ENUM_PADD_DIV_MODE       DivMode;                                                            // DV.DIV.M: Режим дивергенции
  uint                     DivMinPartCount;                                                    // DV.MPC: Мин. количество последовательных сегментов дивергении
  ENUM_TIMEFRAMES          DivTF;                                                              // DV.DBL: Timeframe дивергенции
  uint                     DivStartShiftLeftMin;                                               // DV.DST: Свдиг ожидания дивергенции влево от касания, мин
  uint                     DivExpirationMin;                                                   // DV.DEX: Срок ожидания дивергенция, мин  
  uint                     DivBarsBetweenMin;                                                  // DV.BB.MIN: Мин. количество баров между вершинами RSI, шт
  uint                     DivBarsBetweenMax;                                                  // DV.BB.MAX: Макс. количество баров между вершинами RSI, шт
  ENUM_PADD_RSI_FILTER_MODE DivRSIFilterMode;                                                  // DV.RSI.FM: Режим фильтра вершин RSI
  double                   DivSupRSIMin;                                                       // DV.SUP.RSI.MIN: Мин. RSI для вершин поддержки
  double                   DivSupRSIMax;                                                       // DV.SUP.RSI.MAX: Макс. RSI для вершин поддержки
  double                   DivResRSIMin;                                                       // DV.RES.RSI.MIN: Мин. RSI для вершин сопротивления
  double                   DivResRSIMax;                                                       // DV.RES.RSI.MAX: Макс. RSI для вершин сопротивления
  bool                     DivVAllow;                                                          // DV.VA: Разрешить разнонаправленные сегменты \/ или /\  
  bool                     DivNoLeftLowFilterEnable;                                           // DV.LHF.LB.E: Запретить пробитие H/L свечи слева от дивергенции
  bool                     DivLevelHitFromTouchToDivEnable;                                    // DV.LHF.TD.E: Обязательно пробитие уровня слева от дивергенции/конвергенции
  uint                     DivLeftBarCount;                                                    // DV.LHF.LB.C: Количество свечей слева для проверки H/L  
  bool                     DivLastBarIsHighest;                                                // DV.HLB.E: Последняя свеча дивергенции выше всех, начиная с касания
  bool                     DivUseNextBarExtremeEnable;                                         // DV.NBE.E: Использовать H/L соседней свечи цены для дивергенции
  bool                     DivStartOnlyAtFractalEnable;                                        // DV.SAF.E: Дивергенции обязательно начинается на фрактале  
  double                   DivTouchSupRSIMin;                                                  // DV.TCH.SUP.RSI.MIN: Мин. RSI в момент касания для поддержки
  double                   DivTouchSupRSIMax;                                                  // DV.TCH.SUP.RSI.MAX: Макс. RSI в момент касания для поддержки
  double                   DivTouchResRSIMin;                                                  // DV.TCH.RES.RSI.MIN: Мин. RSI в момент касания для сопротивления
  double                   DivTouchResRSIMax;                                                  // DV.TCH.RES.RSI.MAX: Макс. RSI в момент касания для сопротивления  
  double                   DivTouchSupATRMin;                                                  // DV.TCH.SUP.ATR.MIN: Мин. ATR в момент касания для поддержки
  double                   DivTouchSupATRMax;                                                  // DV.TCH.SUP.ATR.MAX: Макс. ATR в момент касания для поддержки
  double                   DivTouchResATRMin;                                                  // DV.TCH.RES.ATR.MIN: Мин. ATR в момент касания для сопротивления
  double                   DivTouchResATRMax;                                                  // DV.TCH.RES.ATR.MAX: Макс. ATR в момент касания для сопротивления  
  
  bool                     RetestEnable;                                                       // RT.E: Ретест включен?
  double                   RetestEnterImmediatelyATRRatio;                                     // RT.IE: Коэф. ATR размера свечи ОН для немедленного входа
  double                   RetestNotEnterATRRatio;                                             // RT.NE: Коэф. ATR размера свечи ОН для инвалидации уровня  
  double                   RetestBarSizeRatio;                                                 // RT.BR: Коэф. размера свечи ОН ретест уровня (0.5=50%)  
  uint                     RetestExpirationMin;                                                // RT.EXP: Срок ожидания ретеста, мин
  bool                     RetestReverseBarWorstLevelO_NAllow;                                 // RT.OWL.V5: Запрещен Open обратной свечи хуше уровня
  bool                     RetestReverseBarWorstLevelC_NAllow;                                 // RT.CWL.V5: Запрещен Сlose обратной свечи хуше уровня  

  int                      RSIMAPeriod;                                                        // RSI.MAP: RSI Период MA
  ENUM_APPLIED_PRICE       RSIAppliedPrice;                                                    // RSI.AP: RSI Применять к цене
  bool                     RSIDivTopMinDistEnable;                                             // RSI.DP.E: Фильтр входа по мин. дистанции между вершинами RSI дивергенции
  double                   RSIDivTopMinDistValue;                                              // RSI.DP.R: Мин. дистанция между вершинами RSI дивергенции, %
  
  
  bool                     ATREntryBarSizeEnable;                                              // ATR.E: Фильтр входа по размеру свечи обратного направления
  int                      ATRMAPeriod;                                                        // ATR.MAP: Период MA  
  double                   ATRRatio;                                                           // ATR.R: Мультипликатор ATR
  bool                     ATRLevDIVDistEnable;                                                // ATR.EPD.E: Фильтр входа по дистанции от уровня до H/L дивергенции
  double                   ATRLevDIVDistRatio;                                                 // ATR.EPD.R: Мультипликатор ATR для дистанции от уровня до H/L дивергенции
  bool                     ATRDivTopPriceMinDistEnable;                                        // ATR.DTP.E: Фильтр входа по мин. дистанции между вершинами ценовой дивергенции
  double                   ATRDivTopPriceMinDistRatio;                                         // ATR.DTP.R: Мультипликатор ATR для дистанции между вершинами ценовой дивергенции
  
  bool                     TTIEnable;                                                          // TTI.E: Фильтр времени включен? 
  string                   TTIFilename;                                                        // TTI.FN: Имя файла к индикатору "TTI-MT5-Ind"  
  uint                     TTIHitIntervalAfterSecOfMin;                                        // TTI.HI.ASM: Отфильтровать касания после начала минуты через X сек
  uint                     TTIHitIntervalBeforeSecOfMin;                                       // TTI.HI.BSM: Отфильтровать касания до конца минуты за X сек  
  int                      TTIAddHours;                                                        
  datetime                 TTIFileModified;
  string                   TTIDescr;                                                           // Description of TTI
  
  double                   LSFLeftShoulderRatio;                                               // LSF.LS.RAT: Коэф. длины левого плеча к длине правого
  bool                     LSFLeftExtremeEnable;                                               // LSF.LE.ENB: Запретить пробой H/L левого плеча
  ENUM_PADD_SHOULDER_EXTREME_FILTER_MODE LSFShoulderCompareMode;                               // LSF.SC.MOD: Фильтр по экстремумам левого и правого плечей
  
 
 public:
  string                   ChartPrefixLevel;
  string                   ChartPrefixDivGL;
  string                   ChartPrefixRetest;
  string                   ChartPrefixDivVL;
  string                   ChartPrefixArrow;
  
  ENUM_LINE_STYLE          DivLineStyle;
  ENUM_LINE_STYLE          RetestLineStyle;
  
  int                      IndFracUpHandle;
  int                      IndFracDownHandle;
  int                      IndRSI;
  int                      IndATR;

  void                     CPADDBot::UpdateComment();

  void                     CPADDBot::CPADDBot();
  void                     CPADDBot::InitChild();
  bool                     CPADDBot::Check(void);
  
  // Event Handlers
  void                     CPADDBot::OnTick(void);
  void                     CPADDBot::OnDeinit(const int reason);
  void                     CPADDBot::OnBar(CArrayInt& _tf_list);
  //void                     CPADDBot::OnTrade(void);
  //void                     CPADDBot::OnTimer(void);
  
  bool                     CPADDBot::HasTrendLineHit(const ENUM_LEVEL_TYPE _type, 
                                                     CDKDivBarTag& _tag1, 
                                                     CDKDivBarTag& _tag2, 
                                                     double& _values[],
                                                     const double _tag1_val, const double _tag2_val);                       // Has any value hit of trendline from _tag1 to _tag2
  
  void                     CPADDBot::FindFractalAndAddLevelToTrack(const int _ind_handle, 
                                                                   const int _right_bar_cnt, 
                                                                   const ENUM_LEVEL_TYPE _lev_type);                           // Check Fractals indicators and add level to tracking Hash
                                     
  bool                     CPADDBot::IsShoulderLeftExtremeFilterPass(CDKPriceLevel* lev);
  bool                     CPADDBot::IsShoulderLeftAndRightCompareFilterPass(CDKPriceLevel* lev);
  bool                     CPADDBot::IsShoulderFilterPass(CDKPriceLevel* lev);
                                     
  void                     CPADDBot::CheckRetestHit(void);
  void                     CPADDBot::CheckLevelHit(void);                                       // Check level hit
  void                     CPADDBot::Traverse(int start_idx, CArrayInt& _start_arr, 
                                              CArrayInt& _finish_arr, CArrayInt& _path, 
                                              CArrayInt& _res[], int _deep_lev, 
                                              int _max_deep_lev);                               // Traverse div edges
  void                     CPADDBot::FindDivAndEnterPos(void);                                  // Find divs and enter pos
  void                     CPADDBot::EnterPosWithoutDiv(void);                                  // Enter pos immediately after the level is broken
  void                     CPADDBot::CreateRetestLevelAfterReverse(void);                       // Waits reverse bar after hit and creates Retest lev
  
  bool                     CPADDBot::CreateRetestLevel(CDKPriceLevel* _lev);                    // Creates retest level
  
  void                     CPADDBot::EnterPos(CDKPriceLevel* _lev);                             // Enter pos
  int                      CPADDBot::GetHour(datetime _dt);
  bool                     CPADDBot::IsSecInsideMin();
  int                      CPADDBot::GetTSTimeToCloseFromComment(const string _pos_comment);
  bool                     CPADDBot::IsPositionReadyToClose(CPositionInfo& _pos);
  bool                     CPADDBot::IsPosProfitInOptionMarket(CPositionInfo& _pos, const double _level_price);
  double                   CPADDBot::GetPosLevelPriceFromComment(CPositionInfo& _pos);
  void                     CPADDBot::CloseTrades();
  
  void                     CPADDBot::Draw(void);                                                // Draw all POCs and BOSs
  
  void                     CPADDBot::LoadTimeFilterFromFile();                                  // Load TF from INI file
  void                     CPADDBot::CheckTTIUpdatedAndReload();                                // Reload TTI settings if file updated
};


//+------------------------------------------------------------------+
//| Update comment
//+------------------------------------------------------------------+
void CPADDBot::UpdateComment() {
  if (!CommentEnable) return;
  string res = "";

  CDKBaseBot::SetComment(res);
}

//+------------------------------------------------------------------+
//| Constructor
//+------------------------------------------------------------------+
void CPADDBot::CPADDBot() {
  ChartPrefixLevel = "LEV";
  ChartPrefixDivGL = "DIV-GL";
  ChartPrefixDivVL = "DIV-VL";
  ChartPrefixRetest = "RTST";
  ChartPrefixArrow = "ARROW";
  DivLineStyle = STYLE_DOT;
  RetestLineStyle = STYLE_DASHDOTDOT;
  
  EN_Mode = PADD_BOT_MODE_TRADING_FX;
  ENEnable = true;
  ENMMType = ENUM_MM_TYPE_FIXED_LOT;
  ENMMValue = 0.01;
  
  ENSLDist = 100;
  EN_SL_AR_StopLoss_ATRRatio = 1.5;
  ENTPDist = 500;
  ENTPRRRatio = 2.0;
  EN_PD_PosDelayMin = 0;
  
  TS_ED_S_EnterDelay_Sec = 0;
  TS_FCA_M_FixedCloseAfter_Min = "5";                                  // TS.FCA.M: Фиксированное время в сделке, мин
  TS_EC_TF_ExpClose_TF = PERIOD_M1;                                    // TS.EC.TF: Таймфрейм определения экспирации
  TS_EC_AL_M_ExpClose_AddBarWhenLessToClose_Min = "3";                 // TS.EC.AL.M: Мин.время от стрелки до конца бара экспирации, мин    
  
  RetestEnable = false;
  RetestEnterImmediatelyATRRatio = 2.0;
  RetestNotEnterATRRatio = 5.0;
  RetestExpirationMin = 60;
  RetestBarSizeRatio = 0.5;
  RetestReverseBarWorstLevelC_NAllow = false;  
  RetestReverseBarWorstLevelO_NAllow = false;
  
  ARREnable = true;
  ARRReverse = false;
  ARRBuyCode = 233;
  ARRBuyColor = clrGreen;
  ARRSellCode = 234;
  ARRSellColor = clrRed;
  
  FractalTF = PERIOD_M1;
  LevelStartMin = 0;
  LevelExpirationMin = 240;
  LevelShiftPnt = 0;
  F_F_OEN_Fractal_Filter_OnlyExtremeBar = 0;
  
  FUEnable = true;
  FULeftBarCount = 3;
  FULeftHighSorted = true;
  FULeftLowSorted = true;
  FURightBarCount = 3;
  FURightHighSorted = true;
  FURightLowSorted = true;
  FUArrowCode = 234;
  FUArrowColor = clrRed;
  
  FDEnable = true;
  FDLeftBarCount = 3;
  FDLeftHighSorted = true;
  FDLeftLowSorted = true;
  FDRightBarCount = 3;
  FDRightHighSorted = true;
  FDRightLowSorted = true;
  FDArrowCode = 235;
  FDArrowColor = clrGreen;  
  
  DivMode = PADD_DIV_MODE_DIV;
  DivMinPartCount = 1;
  DivTF = PERIOD_M1;
  DivStartShiftLeftMin = 240;
  DivExpirationMin = 240;
  DivBarsBetweenMin = 3;
  DivBarsBetweenMax = 100;
  DivRSIFilterMode = PADD_RSI_FILTER_MODE_ALL;
  DivSupRSIMin = 0.0;
  DivSupRSIMax = 30.0;
  DivResRSIMin = 70.0;
  DivResRSIMax = 100.0;
  DivVAllow = false;
  DivNoLeftLowFilterEnable = false;
  DivLeftBarCount = 3;
  DivLastBarIsHighest = false;
  DivUseNextBarExtremeEnable = true;
  DivStartOnlyAtFractalEnable = true;
  DivTouchSupRSIMin = 0.0;                                                  // DV.TCH.SUP.RSI.MIN: Мин. RSI в момент касания для поддержки
  DivTouchSupRSIMax = 30.0;                                                  // DV.TCH.SUP.RSI.MAX: Макс. RSI в момент касания для поддержки
  DivTouchResRSIMin = 70.0;                                                  // DV.TCH.SUP.RSI.MIN: Мин. RSI в момент касания для сопротивления
  DivTouchResRSIMax = 100.0;                                                  // DV.TCH.SUP.RSI.MAX: Макс. RSI в момент касания для сопротивления    
  DivTouchSupATRMin = 0.0;
  DivTouchSupATRMax = 100.0;
  DivTouchResATRMin = 0.0;  
  DivTouchResATRMax = 100.0;

  
  RSIMAPeriod = 14;
  RSIAppliedPrice = PRICE_CLOSE;
  RSIDivTopMinDistEnable = false;
  RSIDivTopMinDistValue = 1.0;
  
  ATREntryBarSizeEnable = true;
  ATRMAPeriod = 48;
  ATRRatio = 1.5;
  ATRLevDIVDistEnable = false;
  ATRLevDIVDistRatio = 5.0;
  ATRDivTopPriceMinDistEnable = true;
  ATRDivTopPriceMinDistRatio = 1.5;
  
  TTIEnable = false;
  TTIFilename = "TimeFilter.ini";
  TTIHitIntervalAfterSecOfMin = 5;
  TTIHitIntervalBeforeSecOfMin = 55;
  TTIAddHours = 0;
  TTIFileModified = 0;
  TTIDescr = "";
  
  LSFLeftExtremeEnable = false;
  LSFLeftShoulderRatio = 0.5;
  LSFShoulderCompareMode = PADD_SHOULDER_EXTREME_FILTER_MODE_OFF;
}

//+------------------------------------------------------------------+
//| Inits bot
//+------------------------------------------------------------------+
void CPADDBot::InitChild() {
  LevelHash.Clear();
  DivHash.Clear();
  RetestHash.Clear();
    
  IndFracDownHandle = iCustom(Sym.Name(), FractalTF, "PADD-Fractal-Ind",
                              "1. ОСНОВНЫЕ (B)",
                              FRACTAL_TYPE_DOWN,                   // B.FT: Тип фрактала
                              FDArrowCode,                               // B.ACD: Код символа стрелки
                              FDArrowColor,                           // B.ACL: Цвет стрелки
                              "2. ФИЛЬТРЫ (F)",
                              FDLeftBarCount,                                // F.LBC: Свечей слева, шт
                              FDLeftHighSorted,                              // F.LHS: HIGH свечей слева упорядочены
                              FDLeftLowSorted,                             // F.LLS: LOW свечей слева упорядочены
                              FDRightBarCount,                                // F.RBC: Свечей справа, шт
                              FDRightHighSorted,                             // F.RHS: HIGH свечей справа упорядочены
                              FDRightLowSorted                             // F.RLS: LOW свечей справа упорядочены                                
                              );
  IndFracUpHandle = iCustom(Sym.Name(), FractalTF, "PADD-Fractal-Ind",
                              "1. ОСНОВНЫЕ (B)",
                              FRACTAL_TYPE_UP,                   // B.FT: Тип фрактала
                              FUArrowCode,                               // B.ACD: Код символа стрелки
                              FUArrowColor,                           // B.ACL: Цвет стрелки
                              "2. ФИЛЬТРЫ (F)",
                              FULeftBarCount,                                // F.LBC: Свечей слева, шт
                              FULeftHighSorted,                              // F.LHS: HIGH свечей слева упорядочены
                              FULeftLowSorted,                             // F.LLS: LOW свечей слева упорядочены
                              FURightBarCount,                                // F.RBC: Свечей справа, шт
                              FURightHighSorted,                             // F.RHS: HIGH свечей справа упорядочены
                              FURightLowSorted                             // F.RLS: LOW свечей справа упорядочены                                
                              );
  
  IndRSI = iRSI(Sym.Name(), DivTF, RSIMAPeriod, RSIAppliedPrice);
  IndATR = iATR(Sym.Name(), DivTF, ATRMAPeriod);
  
  TTIFileModified = 0;
  LastPosTime = 0;
  
  // Dynamic Test Expiration/Close time init
  TS_From = TimeCurrent();
  TS_Times.Clear();
  if(EN_Mode != PADD_BOT_MODE_TRADING_FX) {
    CDKString str;
    if(EN_Mode == PADD_BOT_MODE_TESTING_BO_FIXED)      str.Assign(TS_FCA_M_FixedCloseAfter_Min);
    if(EN_Mode == PADD_BOT_MODE_TESTING_BO_EXPIRATION) str.Assign(TS_EC_AL_M_ExpClose_AddBarWhenLessToClose_Min);    
    
    CArrayString list;
    str.Split(";", list);
    for(int i=0;i<list.Total();i++)  {
      long num = StringToInteger(list.At(i)); 
      if(num>0 && TS_Times.SearchLinear(num)<0)
        TS_Times.Add(num);
    }
    
    // Init TestResults
    ArrayResize(TS_Hour, TS_Times.Total());
    for(int i=0;i<TS_Times.Total();i++) {
      for(int j=0;j<24;j++) {
        TS_Hour[i, j].InitZero();
        TS_Hour[i, j].Hour = IntegerToString(j);
      }
      TS_Hour[i, 24].Hour = StringFormat("Total %d min:", TS_Times.At(i));    
    }
  }  
}

//+------------------------------------------------------------------+
//| Check bot's inputs
//+------------------------------------------------------------------+
bool CPADDBot::Check(void) {
  bool res = CDKBaseBot::Check();
  
  if (IndFracDownHandle < 0 || IndFracUpHandle < 0) {
    Logger.Error("Ошибка загрузки индикатора PADD-Fractal-Ind", true);
    res = false;
  }
  
  if (IndRSI < 0) {
    Logger.Error("Ошибка загрузки индикатора RSI", true);
    res = false;
  }
  
  if (IndATR < 0) {
    Logger.Error("Ошибка загрузки индикатора ATR", true);
    res = false;
  }
  
  if (DivMode != PADD_DIV_MODE_NO_DIV && DivMinPartCount < 1) {
    Logger.Error("Ошибка параметра `DV.MPC`. Значение должно быть >=1", true);
    res = false;
  }
  
  if ((DivNoLeftLowFilterEnable || DivLevelHitFromTouchToDivEnable) && DivLeftBarCount < 1) {
    Logger.Error("Ошибка параметра `DV.LL.BC`. Значение должно быть >=1", true);
    res = false;
  }
  
  if (TTIEnable) {
    CheckTTIUpdatedAndReload();
    if (TTIFileModified == 0) {
      Logger.Error(StringFormat("Ошибка загрузки TimeTilter из файла `%s`", TTIFilename), true);
      res = false;
    }
  }
  
  if(EN_Mode != PADD_BOT_MODE_TRADING_FX) 
    if(TS_Times.Total()<=0){
      Logger.Error("В режиме тестирования необходимо задать минимум одно значение в `TS.FCA.M` или `TS.EC.AL.M`", true);
      res = false;
    }
    
  return res;
}

//+------------------------------------------------------------------+
//| OnTick Handler
//+------------------------------------------------------------------+
void CPADDBot::OnTick(void) {
  CDKBaseBot::OnTick(); // Check new bar and show comment
  CheckLevelHit();
  CheckRetestHit();
  if(DivMode == PADD_DIV_MODE_NO_DIV) 
    EnterPosWithoutDiv();
    
  if(EN_Mode != PADD_BOT_MODE_TRADING_FX) 
    CloseTrades();  
    
  UpdateComment();
}

datetime LocalTimeKernel32() {
  _SYSTEMTIME st;
  GetLocalTime(st);
  string real_time = StringFormat("%04d-%02d-%02d %02d:%02d:%02d.%03d", st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond, st.wMilliseconds);
 
  return StringToTime(real_time);
}

//+------------------------------------------------------------------+
//| OnDeinit Handler
//+------------------------------------------------------------------+
void CPADDBot::OnDeinit(const int reason){
  if (EN_Mode == PADD_BOT_MODE_TRADING_FX) return;

  for(int i=0;i<TS_Times.Total();i++) {
    for(int j=0;j<24;j++) {
      TS_Hour[i, j].CalcLoss();
      TS_Hour[i, j].CalcWinRate();
      
      // Totals
      TS_Hour[i, 24].TotalCnt += TS_Hour[i, j].TotalCnt;
      TS_Hour[i, 24].ProfitCnt += TS_Hour[i, j].ProfitCnt;
      TS_Hour[i, 24].LossCnt += TS_Hour[i, j].LossCnt;
    }
    TS_Hour[i, 24].CalcWinRate();
  }
  
  //Logger.Warn("");
  //Logger.Warn(StringFormat("СТАТИСТИКА ПО ЧАСАМ ОТКРЫТИЯ В РЕЖИМЕ %s:",
  //                         EnumToString(EN_Mode))); 
  //ArrayPrint(TS_Hour, 0);      
 
  CFileTxt csv_file;
  string filename = StringFormat("%s_%s_%s_%s_%s_%s_%d.csv",
                                 TimeToStringISO(LocalTimeKernel32()),
                                 Symbol(),
                                 TimeframeToString(Period()),
                                 TimeToString(TS_From, TIME_DATE),
                                 TimeToString(TimeCurrent(), TIME_DATE),
                                 (EN_Mode == PADD_BOT_MODE_TESTING_BO_FIXED) ? "FIX" : "EXP",
                                 TS_Times.Total()
                                 );
  csv_file.Open(filename, FILE_CSV | FILE_WRITE);
  for(int i=0;i<TS_Times.Total();i++) {
    csv_file.WriteString(StringFormat("%s - %d min\n", 
                                      (EN_Mode == PADD_BOT_MODE_TESTING_BO_FIXED) ? "FIXED TIME" : "EXPIRATION",
                                      TS_Times.At(i)));
    csv_file.WriteString("Hour;Total;Profit;Loss;WinRate\n");
    for(int j=0;j<25;j++){
      string line = StringFormat("%s;%d;%d;%d;%.2f\n",
                                 TS_Hour[i,j].Hour,
                                 TS_Hour[i,j].TotalCnt,
                                 TS_Hour[i,j].ProfitCnt,
                                 TS_Hour[i,j].LossCnt,
                                 TS_Hour[i,j].WinRate);   
      csv_file.WriteString(line);
    }
    csv_file.WriteString("\n");
  }
  csv_file.Close();
  Logger.Warn(StringFormat("Статистика по часам открытия записана в файл %s", filename));
}

//+------------------------------------------------------------------+
//| OnBar Handler
//+------------------------------------------------------------------+
void CPADDBot::OnBar(CArrayInt& _tf_list) {
  CheckTTIUpdatedAndReload();

  if (_tf_list.SearchLinear(FractalTF) >= 0) {
    if (FUEnable) FindFractalAndAddLevelToTrack(IndFracUpHandle, FURightBarCount, LEVEL_TYPE_RESISTANCE);
    if (FDEnable) FindFractalAndAddLevelToTrack(IndFracDownHandle, FDRightBarCount, LEVEL_TYPE_SUPPORT);
  }
  
  if (_tf_list.SearchLinear(DivTF) >= 0) { 
    if (DivMode != PADD_DIV_MODE_NO_DIV) FindDivAndEnterPos();
    if (DivMode == PADD_DIV_MODE_NO_DIV) 
      CreateRetestLevelAfterReverse(); // v5
  }
}


//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Bot's logic
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Check Fractals indicators
//| and add level to tracking Hash
//+------------------------------------------------------------------+
void CPADDBot::FindFractalAndAddLevelToTrack(const int _ind_handle, const int _right_bar_cnt, const ENUM_LEVEL_TYPE _lev_type) {
  double buh[];
  if (!CopyBuffer(_ind_handle, 0, 0, _right_bar_cnt+2, buh)) return; // +2 - because of 0 - is new born bar; +1 - right end of fractal
  if (buh[0] <= 0) return;
  
  // Check F_EDB_Fractal_ExtremeDuringBar
  if(F_F_OEN_Fractal_Filter_OnlyExtremeBar > 0) {
    int fractal_idx = _right_bar_cnt+1;
    int extreme_idx = (_lev_type == LEVEL_TYPE_RESISTANCE) ? 
                      iHighest(Sym.Name(), FractalTF, MODE_HIGH, F_F_OEN_Fractal_Filter_OnlyExtremeBar, fractal_idx) :  
                      iLowest( Sym.Name(), FractalTF, MODE_LOW,  F_F_OEN_Fractal_Filter_OnlyExtremeBar, fractal_idx);
    bool res = (extreme_idx == fractal_idx);
    if(DEBUG >= Logger.Level)
      Logger.Debug(StringFormat("%s/%d: Filter F.EDB: RES=%s; FRACTAL_IDX=%d %s EXTREME_IDX=%d",
                                __FUNCTION__, __LINE__,
                                (res) ? "PASS" : "FAIL",
                                fractal_idx,
                                (res) ? "=" : "!=",
                                extreme_idx
                                ));
    if(!res)
      return;
  }
  
  ENUM_POSITION_TYPE dir = (_lev_type == LEVEL_TYPE_RESISTANCE) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
  double lev_price = Sym.AddToPrice(dir, buh[0], -1*LevelShiftPnt);
  datetime peak_time = iTime(Sym.Name(), FractalTF, _right_bar_cnt+1);
  
  // Find dt of extreme at DivTF
  int peak_start_bar_divtf_idx = iBarShift(Sym.Name(), DivTF, peak_time)+1; 
  int peak_divtf_idx = (_lev_type == LEVEL_TYPE_RESISTANCE) ?
                       iHighest(Sym.Name(), DivTF, MODE_HIGH, peak_start_bar_divtf_idx, 0) :
                       iLowest(Sym.Name(), DivTF, MODE_LOW, peak_start_bar_divtf_idx, 0);
  
  CDKPriceLevel* lev = new CDKPriceLevel();
  lev.Init(Sym.Name(), DivTF, _lev_type);
  lev.SupColor = FDArrowColor;
  lev.ResColor = FUArrowColor;
  lev.Detect.SetIndexAndValue(0, lev_price);
  lev.Start.SetTimeAndValue(peak_time, lev_price);
  lev.StartExtereme.SetIndexAndValue(peak_divtf_idx, lev_price); // v4.02
  lev.StartReal.SetTimeAndValue(lev.StartExtereme.GetTime()+LevelStartMin*60, lev_price); // v4.02
  lev.Finish.SetTimeAndValue(lev.Start.GetTime()+LevelExpirationMin*60, lev_price);
  lev.Draw(Logger.Name+"-"+ChartPrefixLevel, 0, 0);
  LevelHash.TrySetValue(lev.Start.GetTime(), lev); 
}

//+------------------------------------------------------------------+
//| Check level hit
//+------------------------------------------------------------------+
void CPADDBot::CheckLevelHit(void) {
  datetime keys[];
  CDKPriceLevel* lev[];
  LevelHash.CopyTo(keys, lev);
  for(int i=0;i<ArraySize(keys);i++) {
    CDKPriceLevel* lev = lev[i];
    if (lev.Hit.GetTime() != 0) continue;
    
    if (lev.CheckHitBid()) {
      // Check Level Start Min
      if(TimeCurrent() < (lev.StartExtereme.GetTime() + LevelStartMin*60)) {
        lev.Finish.SetIndexAndValue(0, lev.Hit.GetValue());
        lev.Hit.Init(Sym.Name(), TF);
        lev.Draw(Logger.Name+"-"+ChartPrefixLevel, 0, 0);
        Logger.Debug(StringFormat("%s/%d: F.LST: RES=FAIL; LEV_START_PEAK=%s;", 
                                  __FUNCTION__, __LINE__,
                                    TimeToString(lev.StartExtereme.GetTime() + LevelStartMin*60)
                                    ));
        continue;        
      }
      
      // Check Hit is inside Min
      if(IsSecInsideMin()) {
        lev.Finish.SetIndexAndValue(0, lev.Hit.GetValue());
        lev.Hit.Init(Sym.Name(), TF);
        lev.Draw(Logger.Name+"-"+ChartPrefixLevel, 0, 0);
        Logger.Debug(StringFormat("%s/%d: TTI.HI.*: RES=FAIL; LEV_START=%s; TTI.HI.*=[%d; %d)", 
                                  __FUNCTION__, __LINE__,
                                    TimeToString(lev.Start.GetTime()),
                                    TTIHitIntervalAfterSecOfMin, TTIHitIntervalBeforeSecOfMin
                                    ));
        continue;
      }
      
      // DV.TCH.*.RSI.* Filter Check
      double rsi_buh[];
      if(CopyBuffer(IndRSI, 0, 0, 1, rsi_buh) <= 0)
        continue;
      if((lev.Type == LEVEL_TYPE_SUPPORT    && (rsi_buh[0] < DivTouchSupRSIMin || rsi_buh[0] > DivTouchSupRSIMax)) || 
         (lev.Type == LEVEL_TYPE_RESISTANCE && (rsi_buh[0] < DivTouchResRSIMin || rsi_buh[0] > DivTouchResRSIMax))) {
        if(Logger.Level == DEBUG)
          Logger.Debug(StringFormat("%s/%d: DV.TCH.*.RSI.*: RES=FAIL; LEV_START=%s; RSI=%f; RSI_RANGE=[%f; %f]",
                                    __FUNCTION__, __LINE__,
                                    TimeToString(lev.Start.GetTime()),
                                    rsi_buh[0],
                                    (lev.Type == LEVEL_TYPE_SUPPORT) ? DivTouchSupRSIMin : DivTouchResRSIMin,
                                    (lev.Type == LEVEL_TYPE_SUPPORT) ? DivTouchSupRSIMax : DivTouchResRSIMax)
                                    );          
         
        continue;         
      }

      // DV.TCH.*.ATR.* Filter Check
      double atr_buh[];
      if(CopyBuffer(IndATR, 0, 0, 1, atr_buh) <= 0)
        continue;

        
      double ext_buh = 0;
      double ext_atr_min = 0;
      double ext_atr_max = 0;      
      if(lev.Type == LEVEL_TYPE_SUPPORT) {
        ext_buh = iHigh(Sym.Name(), DivTF, iHighest(Sym.Name(), DivTF, MODE_HIGH, lev.Start.GetIndex()+1));
        ext_atr_min = atr_buh[0] * DivTouchSupATRMin;
        ext_atr_max = atr_buh[0] * DivTouchSupATRMax;
      }
      if(lev.Type == LEVEL_TYPE_RESISTANCE) {
        ext_buh = iLow(Sym.Name(), DivTF, iLowest(Sym.Name(), DivTF, MODE_LOW, lev.Start.GetIndex()+1));
        ext_atr_min = atr_buh[0] * DivTouchResATRMin;
        ext_atr_max = atr_buh[0] * DivTouchResATRMax;        
      }
        
      double ext_atr_curr = MathAbs(ext_buh-lev.Start.GetValue());
      
      if(!(ext_atr_curr >= ext_atr_min && ext_atr_curr <= ext_atr_max)) {
        if(Logger.Level == DEBUG)
          Logger.Debug(StringFormat("%s/%d: DV.TCH.*.ATR.*: RES=FAIL; LEV_START=%s; PEAK=%f; ATR_RANGE=[%f; %f]",
                                    __FUNCTION__, __LINE__,
                                    TimeToString(lev.Start.GetTime()),
                                    ext_atr_curr,
                                    ext_atr_min,
                                    ext_atr_max
                                    ));          
         
        continue;         
     }

     // v4 addition
     if(!IsShoulderFilterPass(lev))
      continue;
    
    //if (lev.CheckHit(HIT_TYPE_BREAKOUT)) {    
      lev.Finish.SetIndexAndValue(lev.Hit.GetIndex(), lev.Hit.GetValue());
      lev.Draw(Logger.Name+"-"+ChartPrefixLevel, 0, 0);
      
      // Create DIV level
      CDKPriceLevel* div = new CDKPriceLevel();
      div.Init(Sym.Name(), DivTF, lev.Type);
      div.SupColor = FDArrowColor;
      div.ResColor = FUArrowColor;
      div.LevelLineStyle = DivLineStyle;
      div.Detect.SetIndexAndValue(0, lev.Start.GetValue());
      div.Start.SetIndexAndValue(0, lev.Start.GetValue());
      div.Finish.SetTimeAndValue(div.Start.GetTime()+DivExpirationMin*60, lev.Start.GetValue());
      div.Draw(Logger.Name+"-"+ChartPrefixDivGL, 0, 0);
      
      // Draw start and finish VLINEs
      CChartObjectVLine* vline = new CChartObjectVLine();
      vline.Create(0, StringFormat("%s-%s-%s-%s-START", Logger.Name, ChartPrefixDivVL, LevelTypeToString(div.Type, true), TimeToString(div.Start.GetTime())), 0, div.Start.GetTime());
      vline.Color((div.Type == LEVEL_TYPE_SUPPORT) ? div.SupColor : div.ResColor);
      vline.Style(DivLineStyle);
      
      vline = new CChartObjectVLine();
      vline.Create(0, StringFormat("%s-%s-%s-%s-FINISH", Logger.Name, ChartPrefixDivVL, LevelTypeToString(div.Type, true), TimeToString(div.Start.GetTime())), 0, div.Finish.GetTime());
      vline.Color((div.Type == LEVEL_TYPE_SUPPORT) ? div.SupColor : div.ResColor);
      vline.Style(DivLineStyle);
            
      DivHash.TrySetValue(div.Start.GetTime(), div);       
    }
  }
}

//+------------------------------------------------------------------+
//| Check shoulder left extreme filter pass for v4
//+------------------------------------------------------------------+
bool CPADDBot::IsShoulderLeftExtremeFilterPass(CDKPriceLevel* lev) {
  int right_start_idx = lev.StartExtereme.GetIndex(true);
  int left_len = (int)(right_start_idx * LSFLeftShoulderRatio);
  int left_start_idx = right_start_idx + left_len;
  
  // 1. Check Left High
  if(LSFLeftExtremeEnable){
    if(lev.Type == LEVEL_TYPE_RESISTANCE) {
      int left_extreme_idx = iHighest(Sym.Name(), DivTF, MODE_HIGH, left_len, right_start_idx+1);
      double left_extreme_val = iHigh(Sym.Name(), DivTF, left_extreme_idx);
      if(left_extreme_val >= lev.StartExtereme.GetValue()) {
        if(DEBUG >= Logger.Level)
          Logger.Debug(StringFormat("%s/%d: LSF.LE.ENB: RES=FAIL; LEV_LEFT(%s)=%s; >= LEV(%s)=%s; LEV_LEFT_START=%s",
                                    __FUNCTION__, __LINE__,
                                    TimeToString(iTime(Sym.Name(), DivTF, left_extreme_idx)),
                                    Sym.PriceToString(left_extreme_val),
                                    TimeToString(lev.StartExtereme.GetTime()),
                                    Sym.PriceToString(lev.StartExtereme.GetValue()),                                    
                                    TimeToString(iTime(Sym.Name(), DivTF, left_start_idx))
                                    ));
        return false;
      }
    }
    
    if(lev.Type == LEVEL_TYPE_SUPPORT) {
      int left_extreme_idx = iLowest(Sym.Name(), DivTF, MODE_LOW, left_len, right_start_idx+1);
      double left_extreme_val = iLow(Sym.Name(), DivTF, left_extreme_idx);
      if(left_extreme_val <= lev.StartExtereme.GetValue()) {
        if(DEBUG >= Logger.Level)
          Logger.Debug(StringFormat("%s/%d: LSF.LE.ENB: RES=FAIL; LEV_LEFT(%s)=%s; <= LEV(%s)=%s; LEV_LEFT_START=%s",
                                    __FUNCTION__, __LINE__,
                                    TimeToString(iTime(Sym.Name(), DivTF, left_extreme_idx)),
                                    Sym.PriceToString(left_extreme_val),
                                    TimeToString(lev.StartExtereme.GetTime()),
                                    Sym.PriceToString(lev.StartExtereme.GetValue()),
                                    TimeToString(iTime(Sym.Name(), DivTF, left_start_idx))
                                    ));
        return false;
      }
    }
  }
  
  return true;
}

//+------------------------------------------------------------------+
//| Check shoulder left extreme filter pass for v4
//+------------------------------------------------------------------+
bool CPADDBot::IsShoulderLeftAndRightCompareFilterPass(CDKPriceLevel* lev) {
  int right_start_idx = lev.StartExtereme.GetIndex(true);
  int left_len = (int)(right_start_idx * LSFLeftShoulderRatio);
  int left_start_idx = right_start_idx + left_len;
  
  // 2. Compare extreme left and right shoulders
  if(LSFShoulderCompareMode != PADD_SHOULDER_EXTREME_FILTER_MODE_OFF){
    if(lev.Type == LEVEL_TYPE_RESISTANCE) {
      int left_extreme_idx = iLowest(Sym.Name(), DivTF, MODE_LOW, left_len, right_start_idx+1);
      double left_extreme_val = iLow(Sym.Name(), DivTF, left_extreme_idx);
      
      ENUM_SERIESMODE mode = (LSFShoulderCompareMode == PADD_SHOULDER_EXTREME_FILTER_MODE_LH_RC) ? MODE_CLOSE : MODE_LOW;
      int right_extreme_idx = iLowest(Sym.Name(), DivTF, mode, right_start_idx, 0);
      double right_extreme_val = iLow(Sym.Name(), DivTF, right_extreme_idx);
      
      if(left_extreme_val <= right_extreme_val) {
        if(DEBUG >= Logger.Level)
          Logger.Debug(StringFormat("%s/%d: LSF.SC.MOD: RES=FAIL; LEV_LEFT(%s)=%s; <= LEV_RIGHT_%s(%s)=%s; LEV_LEFT_START=%s",
                                    __FUNCTION__, __LINE__,
                                    TimeToString(iTime(Sym.Name(), DivTF, left_extreme_idx)),
                                    Sym.PriceToString(left_extreme_val),
                                    (LSFShoulderCompareMode == PADD_SHOULDER_EXTREME_FILTER_MODE_LH_RC) ? "CLOSE" : "LOW",
                                    TimeToString(iTime(Sym.Name(), DivTF, right_extreme_idx)),
                                    Sym.PriceToString(right_extreme_val),                                    
                                    TimeToString(iTime(Sym.Name(), DivTF, left_start_idx))
                                    ));
        return false;
      }
    }    
    
    if(lev.Type == LEVEL_TYPE_SUPPORT) {
      int left_extreme_idx = iHighest(Sym.Name(), DivTF, MODE_HIGH, left_len, right_start_idx+1);
      double left_extreme_val = iHigh(Sym.Name(), DivTF, left_extreme_idx);
      
      ENUM_SERIESMODE mode = (LSFShoulderCompareMode == PADD_SHOULDER_EXTREME_FILTER_MODE_LH_RC) ? MODE_CLOSE : MODE_HIGH;
      int right_extreme_idx = iHighest(Sym.Name(), DivTF, mode, right_start_idx, 0);
      double right_extreme_val = iHigh(Sym.Name(), DivTF, right_extreme_idx);
      
      if(left_extreme_val >= right_extreme_val) {
        if(DEBUG >= Logger.Level)
          Logger.Debug(StringFormat("%s/%d: LSF.SC.MOD: RES=FAIL; LEV_LEFT(%s)=%s; >= LEV_RIGHT_%s(%s)=%s; LEV_LEFT_START=%s",
                                    __FUNCTION__, __LINE__,
                                    TimeToString(iTime(Sym.Name(), DivTF, left_extreme_idx)),
                                    Sym.PriceToString(left_extreme_val),
                                    (LSFShoulderCompareMode == PADD_SHOULDER_EXTREME_FILTER_MODE_LH_RC) ? "CLOSE" : "HIGH",
                                    TimeToString(iTime(Sym.Name(), DivTF, right_extreme_idx)),
                                    Sym.PriceToString(right_extreme_val),                                    
                                    TimeToString(iTime(Sym.Name(), DivTF, left_start_idx))
                                    ));
        return false;
      }
    }    
  }
  
  return true;
}

//+------------------------------------------------------------------+
//| Check shoulder filter pass for v4
//+------------------------------------------------------------------+
bool CPADDBot::IsShoulderFilterPass(CDKPriceLevel* lev) {
  if(LSFLeftShoulderRatio <= 0) return true;
  if(!LSFLeftExtremeEnable || LSFShoulderCompareMode == PADD_SHOULDER_EXTREME_FILTER_MODE_OFF) return true;
  
  if(LSFLeftExtremeEnable && !IsShoulderLeftExtremeFilterPass(lev))
    return false;
  
  if(LSFShoulderCompareMode != PADD_SHOULDER_EXTREME_FILTER_MODE_OFF && !IsShoulderLeftAndRightCompareFilterPass(lev))
    return false;
    
  return true;
}

//+------------------------------------------------------------------+
//| Checks hit of retest level
//+------------------------------------------------------------------+
void CPADDBot::CheckRetestHit(void) {
  datetime keys[];
  CDKPriceLevel* lev[];
  RetestHash.CopyTo(keys, lev);
  for(int i=0;i<ArraySize(keys);i++) {
    CDKPriceLevel* lev = lev[i];
    if (lev.Hit.GetTime() != 0) continue;
    
    if (lev.CheckHitBid()) {
      EnterPos(lev);
      lev.Finish.SetIndexAndValue(lev.Hit.GetIndex(), lev.Hit.GetValue());
      lev.Draw(Logger.Name+"-"+ChartPrefixLevel, 0, 0);
    }
  } 
}

double ArrayMin(double& _arr[], const int _from_idx, const int _to_idx) {
  double min = _arr[_from_idx];
  for(int i=_from_idx+1;i<_to_idx;i++) 
    if (_arr[i]<min) min = _arr[i];
     
  return min;
}

double ArrayMax(double& _arr[], const int _from_idx, const int _to_idx) {
  double max = _arr[_from_idx];
  for(int i=_from_idx+1;i<_to_idx;i++) 
    if (_arr[i]>max) max = _arr[i];
     
  return max;
}

double PsewodscalarProduct(int x1, double y1, int x2, double y2, int x, double y) {
  return (x-x1)*(y2-y1)-(y-y1)*(x2-x1);
}

bool CPADDBot::HasTrendLineHit(const ENUM_LEVEL_TYPE _type, CDKDivBarTag& _tag1, CDKDivBarTag& _tag2, 
                               double& _values[], const double _tag1_val, const double _tag2_val) {
  int start_idx = _tag1.GetIndex();
  int x1 = start_idx-_tag1.GetIndex();
  int x2 = start_idx-_tag2.GetIndex();
  for(int i=x1+1;i<x2;i++){
    double d = PsewodscalarProduct(x1, _tag1_val, x2, _tag2_val, i, _values[start_idx-i]);
    if((_type == LEVEL_TYPE_SUPPORT    && d > 0)||
       (_type == LEVEL_TYPE_RESISTANCE && d < 0))
       return true;
  }
  
  return false;
}

//+------------------------------------------------------------------+
//| Traverse div edges
//+------------------------------------------------------------------+
void CPADDBot::Traverse(int start_idx, CArrayInt& _start_arr, CArrayInt& _finish_arr, CArrayInt& _path, CArrayInt& _res[], int _deep_lev, int _max_deep_lev) {
  for(int i=0;i<_start_arr.Total();i++)
    if(_start_arr.At(i) == start_idx) {
      CArrayInt new_path;
      new_path.AddArray(GetPointer(_path));
      new_path.Add(_finish_arr.At(i));
      
      if (_deep_lev < _max_deep_lev)
        Traverse(_finish_arr.At(i), _start_arr, _finish_arr, new_path, _res, _deep_lev+1, _max_deep_lev);
      
      ArrayResize(_res, ArraySize(_res)+1);
      _res[ArraySize(_res)-1] = new_path;
    }
}

//+------------------------------------------------------------------+
//| Creates retest level
//+------------------------------------------------------------------+
bool CPADDBot::CreateRetestLevel(CDKPriceLevel* _lev) {
  if(!Sym.RefreshRates()) return false;
  double retest_price = Sym.Bid();
  
  // 0. Get Reverse Bar size
  int idx = _lev.Hit.GetIndex(true)-1;
  double atr[];
  if (CopyBuffer(IndATR, 0, idx, 1, atr) < 0) return false;
  double reverse_bar_size = iHigh(Sym.Name(), DivTF, idx)-iLow(Sym.Name(), DivTF, idx);

  // 1. Check Reverse Bar Size: ATR.BR.R
  if (ATREntryBarSizeEnable && reverse_bar_size > atr[0]*ATRRatio) {
    if(Logger.Level >= DEBUG)
      Logger.Debug(StringFormat("%s/%d: Entry skipped by `ATR.BR.R`=%f", __FUNCTION__, __LINE__, ATRRatio));
    return false;
  };
  
  // 2. Check Retest Entry mode: ATR.RT.E
  if (RetestEnable) {
    if(reverse_bar_size > atr[0]*RetestNotEnterATRRatio) {
      if(Logger.Level >= DEBUG)
        Logger.Debug(StringFormat("%s/%d: Entry skipped by `ATR.RT.NE`=%f", __FUNCTION__, __LINE__, RetestNotEnterATRRatio));
      return false;
    }
    
    // Enter on half of Reverse Bar
    if(reverse_bar_size > atr[0]*RetestEnterImmediatelyATRRatio) 
      if(_lev.Type == LEVEL_TYPE_RESISTANCE)
        retest_price = iHigh(Sym.Name(), DivTF, idx) - reverse_bar_size*RetestBarSizeRatio;
      else
        retest_price = iLow(Sym.Name(), DivTF, idx)  + reverse_bar_size*RetestBarSizeRatio;
  };  
  
  // Create RETEST level
  CDKPriceLevel* retest = new CDKPriceLevel();
  retest.Init(Sym.Name(), DivTF, _lev.Type);
  retest.SupColor = FDArrowColor;
  retest.ResColor = FUArrowColor;
  retest.LevelLineStyle = RetestLineStyle;
  retest.Detect.SetIndexAndValue(0, retest_price);
  retest.Start.SetIndexAndValue(0, retest_price);
  retest.Finish.SetTimeAndValue(retest.Start.GetTime()+RetestExpirationMin*60, retest_price);
  retest.Draw(Logger.Name+"-"+ChartPrefixRetest, 0, 0);
  
  RetestHash.TrySetValue(retest.Start.GetTime(), retest); 
  
  return true;
}

//+------------------------------------------------------------------+
//| Find div and Enter pos
//+------------------------------------------------------------------+
void CPADDBot::FindDivAndEnterPos(void) {
  datetime keys[];
  CDKPriceLevel* lev[];
  DivHash.CopyTo(keys, lev);
  for(int i=0;i<ArraySize(keys);i++) {
    CDKPriceLevel* lev = lev[i];
    if(TimeCurrent() > lev.Finish.GetTime()) continue;
    if(lev.Hit.GetTime() != 0) continue; // Hit means DIV has found
    
    // Get start div interval idx 
    datetime div_interval_start_dt = lev.Start.GetTime() - DivStartShiftLeftMin*60;
    int div_interval_start_idx = iBarShift(Sym.Name(), DivTF, div_interval_start_dt);
    if(div_interval_start_idx < 0) continue;
    
    double rsi[]; ArraySetAsSeries(rsi, true);
    if (CopyBuffer(IndRSI, 0, 0, div_interval_start_idx+1, rsi) <= 2) continue;
    
    double price_arr[]; ArraySetAsSeries(price_arr, true);
    if(lev.Type == LEVEL_TYPE_RESISTANCE) 
      if(CopyHigh(Sym.Name(), DivTF, 0, div_interval_start_idx+1, price_arr) <=2) continue;
    if(lev.Type == LEVEL_TYPE_SUPPORT) 
      if(CopyLow(Sym.Name(), DivTF, 0, div_interval_start_idx+1, price_arr) <=2) continue;      
    
    // 01. Find all RSI peaks that fit the conditions
    CArrayObj div_list;
    div_list.Clear();
    for(int j=ArraySize(rsi)-2;j>=2;j--)
      if((lev.Type == LEVEL_TYPE_SUPPORT    && rsi[j]<rsi[j-1] && rsi[j]<rsi[j+1]) ||
         (lev.Type == LEVEL_TYPE_RESISTANCE && rsi[j]>rsi[j-1] && rsi[j]>rsi[j+1])) {

      CDKDivBarTag* div = new CDKDivBarTag();
      div.Init(Sym.Name(), DivTF, j, rsi[j]);
      
      double price = 0.0;
      if (DivUseNextBarExtremeEnable)
          // Price2 (chart) is max/min of [-1;+1] bar
          //price = (lev.Type == LEVEL_TYPE_SUPPORT) ? 
          //         MathMin(iLow(Sym.Name(), DivTF, j), iLow(Sym.Name(), DivTF, j-1)) : 
          //         MathMax(iHigh(Sym.Name(), DivTF, j), iHigh(Sym.Name(), DivTF, j-1));
          price = (lev.Type == LEVEL_TYPE_SUPPORT) ? 
                   iLow(Sym.Name(), DivTF, iLowest(Sym.Name(), DivTF, MODE_LOW, 3, j-1)) :
                   iHigh(Sym.Name(), DivTF, iHighest(Sym.Name(), DivTF, MODE_HIGH, 3, j-1));
      else
        price = (lev.Type == LEVEL_TYPE_SUPPORT) ? iLow(Sym.Name(), DivTF, j) : iHigh(Sym.Name(), DivTF, j);
        
      div.SetValue2(price);
      div_list.Add(div);
    }
    if (div_list.Total() < 2) continue; // Min 2 peaks    
    
    // 02. Filter out found RSI peaks that
    //   - have no div with chart price;
    //   - have no number of bars between neighboring peaks
    //   - have lower/highrt extreme between peaks
    CArrayInt div_list_finish_idx; div_list_finish_idx.Clear();
    CArrayInt div_list_start_idx; div_list_start_idx.Clear();
    
    for(int i=0;i<div_list.Total()-1;i++) 
      for(int j=i+1;j<div_list.Total();j++) {
        CDKDivBarTag* tag1 = div_list.At(i);
        CDKDivBarTag* tag2 = div_list.At(j);
        
        // Finish of div must be after Start
        if(tag2.GetTime() < lev.Start.GetTime()) 
          continue;
        
        double rsi_dir   = tag2.GetValue()-tag1.GetValue();
        double price_dir = tag2.GetValue2()-tag1.GetValue2();
        
        if(rsi_dir * price_dir >= 0) continue; // One dir rsi and chart - no div
        if(MathAbs(tag1.GetIndex()-tag2.GetIndex()-1)<(int)DivBarsBetweenMin) continue; // Peaks are too close each other
        if(MathAbs(tag1.GetIndex()-tag2.GetIndex()-1)>(int)DivBarsBetweenMax) continue; // Peaks are too far away each other
        
        // Check RSI line doesn't hit RSI div line
        if(HasTrendLineHit(lev.Type, tag1, tag2, rsi, tag1.GetValue(), tag2.GetValue())) 
          continue;
        
        // Check price doesn't hit price div line
        if(HasTrendLineHit(lev.Type, tag1, tag2, price_arr, tag1.GetValue2(), tag2.GetValue2())) 
          continue;
        
        div_list_start_idx.Add(i);
        div_list_finish_idx.Add(j);
      }    
    if (div_list_start_idx.Total() < (int)DivMinPartCount) continue;

    // 03. Recursive search for connected divergence edges
    CArrayInt path;
    CArrayInt res[];
    path.Add(div_list_start_idx.At(0));
  
    Traverse(div_list_start_idx.At(0), div_list_start_idx, div_list_finish_idx, path, res, 1, (int)DivMinPartCount);
    for(int k=0;k<ArraySize(res);k++)
      if (res[k].Total() > (int)DivMinPartCount){
        CArrayInt path = res[k];
        
        // 03.0 Check RSI's tops allowed range
        bool rsi_allowed = true;
        int rsi_idx_start = (DivRSIFilterMode == PADD_RSI_FILTER_MODE_LAST) ? path.Total()-1 : 0; 
        for(int m=rsi_idx_start;m<path.Total();m++) {
          CDKDivBarTag* tag = div_list.At(path.At(m));
          double rsi_value = tag.GetValue();
          if((lev.Type == LEVEL_TYPE_SUPPORT    && (rsi_value<DivSupRSIMin || rsi_value>DivSupRSIMax)) ||
             (lev.Type == LEVEL_TYPE_RESISTANCE && (rsi_value<DivResRSIMin || rsi_value>DivResRSIMax))) {
             rsi_allowed = false;
             break;
          }          
        }
        if(!rsi_allowed) continue;
        
        // 03.1 Check DIV or CON
        if (DivMode != PADD_DIV_MODE_NO_DIV) {
          CDKDivBarTag* tag1 = div_list.At(path.At(0));
          CDKDivBarTag* tag2 = div_list.At(path.At(1));
          if(lev.Type == LEVEL_TYPE_RESISTANCE) {
            if(tag1.GetValue2() > tag2.GetValue2()  // Линии сходятся - конвергенция
              && DivMode!=PADD_DIV_MODE_CON && DivMode!=PADD_DIV_MODE_BOTH) continue;                
            if(tag1.GetValue2() < tag2.GetValue2() // Линии расходятся - дивергенция
              && DivMode!=PADD_DIV_MODE_DIV && DivMode!=PADD_DIV_MODE_BOTH) continue; 
          } 
          else { //lev.Type == LEVEL_TYPE_SUPPORT
            if(tag1.GetValue2() > tag2.GetValue2()  // Линии сходятся - дивергенция
              && DivMode!=PADD_DIV_MODE_DIV && DivMode!=PADD_DIV_MODE_BOTH) continue;                
            if(tag1.GetValue2() < tag2.GetValue2() // Линии расходятся - конвергенция
              && DivMode!=PADD_DIV_MODE_CON && DivMode!=PADD_DIV_MODE_BOTH) continue;           
          }   
        }
        
        // 03.2.1 'DV.SAF.E': ver.3 Начало дивергенции совпадает с фракталом
        if(DivStartOnlyAtFractalEnable) {
          CDKDivBarTag* tag = div_list.At(path.At(0)); // Начало дивера на LTF
          datetime div_htf_dt = iTime(Sym.Name(), FractalTF, iBarShift(Sym.Name(), FractalTF, tag.GetTime()));
          CDKPriceLevel* frac_lev;
          bool res_saf = LevelHash.TryGetValue(div_htf_dt, frac_lev);
          if(Logger.Level == DEBUG)
            Logger.Debug(StringFormat("%s/%d: DV.SAF.E: RES=%s; DIV_TAG1=%s/%d; FRACTAL_DT=%s",
                                      __FUNCTION__, __LINE__,
                                      (res_saf) ? "PASS" : "FAIL",
                                      TimeToString(tag.GetTime()),
                                      tag.GetIndex(), 
                                      (res_saf) ? TimeToString(div_htf_dt) : "NOT_FOUND"
                                      ));          
          if(!res_saf) {
            continue; // No any fractal found at div start time
          }
        }
        
        // 03.2. Check V div
        double dir_prev = 0;
        if ((int)DivMinPartCount > 1 && !DivVAllow) {
          bool has_v = false;
          for(int m=0;m<path.Total()-1;m++) {
            CDKDivBarTag* tag1 = div_list.At(path.At(m));
            CDKDivBarTag* tag2 = div_list.At(path.At(m+1));        
            double dir = tag2.GetValue() - tag1.GetValue();
            if (dir_prev * dir < 0) { has_v = true; break; };
            dir_prev = dir;
           }
          if (has_v) continue;
        }
        
        // 03.3. Сheck LeftLow
        if(DivNoLeftLowFilterEnable){
          CDKDivBarTag* tag1 = div_list.At(path.At(0));
          if(lev.Type == LEVEL_TYPE_SUPPORT) {
            double left_bars_extreme = iLow(Sym.Name(), DivTF, iLowest(Sym.Name(), DivTF, MODE_LOW, DivLeftBarCount, tag1.GetIndex(true)+1));
            double tag1_price2 = iLow(Sym.Name(), DivTF, tag1.GetIndex(true));
            if(left_bars_extreme < tag1_price2) continue; 
          }
          if(lev.Type == LEVEL_TYPE_RESISTANCE) {
            double left_bars_extreme = iHigh(Sym.Name(), DivTF, iHighest(Sym.Name(), DivTF, MODE_HIGH, DivLeftBarCount, tag1.GetIndex(true)+1));
            double tag1_price2 = iHigh(Sym.Name(), DivTF, tag1.GetIndex(true));
            if(left_bars_extreme > tag1_price2) continue; 
          }          
        }
        
        // 03.4. V1.07 'DV.LHF.TD.E' Обязательно пробитие уровня от касания до конца дивергенции
        if(DivLevelHitFromTouchToDivEnable){
          CDKDivBarTag* last_div_tag = div_list.At(path.At(path.Total()-1));
          int reverse_bar_idx = last_div_tag.GetIndex(true)+1;
          if(lev.Type == LEVEL_TYPE_SUPPORT) {
            double extreme = iLow(Sym.Name(), DivTF, iLowest(Sym.Name(), DivTF, MODE_LOW, DivLeftBarCount, reverse_bar_idx));
            if(extreme > lev.Start.GetValue()) continue; 
          }
          if(lev.Type == LEVEL_TYPE_RESISTANCE) {
            double extreme = iHigh(Sym.Name(), DivTF, iHighest(Sym.Name(), DivTF, MODE_HIGH, DivLeftBarCount, reverse_bar_idx));
            if(extreme < lev.Start.GetValue()) continue; 
          }          
        }        
        
        // 03.5 Check ATR distance between level and DIV start
        if(ATRLevDIVDistEnable) {
          CDKDivBarTag* tag1 = div_list.At(path.At(0));
          int idx = tag1.GetIndex(true);
        
          double atr[];
          if (CopyBuffer(IndATR, 0, idx, 1, atr) < 0) continue;
          
          double dist_lev_div = MathAbs(tag1.GetValue2()-lev.Start.GetValue());
          if (dist_lev_div > atr[0]*ATRLevDIVDistRatio) continue;          
        }
        
        // 03.6 Check ATR distance between price divs' tops 
        if(ATRDivTopPriceMinDistEnable) {
          bool has_not_allowed_dist = false;
          for(int m=0;m<path.Total()-1;m++) {
            CDKDivBarTag* tag1 = div_list.At(path.At(m));
            CDKDivBarTag* tag2 = div_list.At(path.At(m+1));        

            double atr[];
            int idx = tag2.GetIndex(true);
            if (CopyBuffer(IndATR, 0, idx, 1, atr) < 0) { has_not_allowed_dist = true; break; };        
 
            double dist = MathAbs(tag2.GetValue2() - tag1.GetValue2());
            if (dist < atr[0]*ATRDivTopPriceMinDistRatio) { has_not_allowed_dist = true; break; };
           }
          if (has_not_allowed_dist) continue;          
        }

        // 03.7 Check RSI distance between divs' tops 
        if(RSIDivTopMinDistEnable) {
          bool has_not_allowed_dist = false;
          for(int m=0;m<path.Total()-1;m++) {
            CDKDivBarTag* tag1 = div_list.At(path.At(m));
            CDKDivBarTag* tag2 = div_list.At(path.At(m+1));        
 
            double dist = MathAbs(tag2.GetValue() - tag1.GetValue());
            if (dist < RSIDivTopMinDistValue) { has_not_allowed_dist = true; break; };
           }
          if (has_not_allowed_dist) continue;          
        }
        
        // 03.7 DV.HLB.E: Последняя свеча дивергенции выше всех, начиная с касания
        if(DivLastBarIsHighest) {
          CDKDivBarTag* tag1 = div_list.At(path.At(0));
          CDKDivBarTag* tag2 = div_list.At(path.At(1));        
          
          // This filter is only for divergence
          if((lev.Type == LEVEL_TYPE_RESISTANCE && tag1.GetValue2() < tag2.GetValue2()) ||
             (lev.Type == LEVEL_TYPE_SUPPORT    && tag1.GetValue2() > tag2.GetValue2())) {
            
            CDKDivBarTag* last_div_tag = div_list.At(path.At(path.Total()-1));
            int last_div_idx = last_div_tag.GetIndex(true);
            int cnt = lev.Start.GetIndex(true)-last_div_idx+1;
            
            int extreme_idx = (lev.Type == LEVEL_TYPE_SUPPORT) ? 
                              iLowest(Sym.Name(), DivTF, MODE_LOW, cnt, last_div_idx) : 
                              iHighest(Sym.Name(), DivTF, MODE_HIGH, cnt, last_div_idx); 
            
            // Last div bar must be highest/lowest
            bool res_DivLastBarIsHighest = (extreme_idx == tag2.GetIndex());
            if(Logger.Level == DEBUG)
              Logger.Debug(StringFormat("%s/%d: DV.HLB.E: RES=%s; DIV_TAG1=%s/%d; DIV_TAG2=%s/%d %s HIGHEST_INTERVAL_IDX=%d",
                                        __FUNCTION__, __LINE__,
                                        (res_DivLastBarIsHighest) ? "PASS" : "FAIL",
                                        TimeToString(tag1.GetTime()),
                                        tag1.GetIndex(), 
                                        TimeToString(tag2.GetTime()),
                                        tag2.GetIndex(),
                                        (res_DivLastBarIsHighest) ? "=" : "!=",
                                        extreme_idx
                                        ));
            
            if(!res_DivLastBarIsHighest) 
              continue;          
          }           
        }
        
        // 03.8. Draw edges
        for(int m=0;m<path.Total()-1;m++) {
          CDKDivBarTag* tag1 = div_list.At(path.At(m));
          CDKDivBarTag* tag2 = div_list.At(path.At(m+1));
          
          string name_postfix = StringFormat("%s-%s", TimeToString(tag1.GetTime()), TimeToString(tag2.GetTime()));
          CChartObjectTrend* tline = new CChartObjectTrend();      
          tline.Create(0, StringFormat("%s-DIV-RSI-%s-%s", Logger.Name, LevelTypeToString(lev.Type, true), name_postfix),1, tag1.GetTime(), tag1.GetValue(), tag2.GetTime(), tag2.GetValue());
          tline.Color((lev.Type == LEVEL_TYPE_SUPPORT) ? lev.SupColor : lev.ResColor);
          
          tline = new CChartObjectTrend();      
          tline.Create(0,StringFormat("%s-DIV-CHA-%s-%s", Logger.Name, LevelTypeToString(lev.Type, true), name_postfix),0, tag1.GetTime(), tag1.GetValue2(), tag2.GetTime(), tag2.GetValue2());          
          tline.Color((lev.Type == LEVEL_TYPE_SUPPORT) ? lev.SupColor : lev.ResColor);            
          lev.Hit.SetIndexAndValue(tag2.GetIndex(true), tag2.GetValue2());
          lev.Finish.SetTimeAndValue(TimeCurrent(), tag2.GetValue2());
          lev.Draw(Logger.Name+"-"+ChartPrefixDivGL, 0, 0);
        }
        
        CreateRetestLevel(lev); // EnterPos(lev);
        break;
      }
  }
}

//+------------------------------------------------------------------+
//| Enter pos immediately after the level is broken
//+------------------------------------------------------------------+
void CPADDBot::EnterPosWithoutDiv(void) {
  datetime keys[];
  CDKPriceLevel* lev[];
  DivHash.CopyTo(keys, lev);
  for(int i=0;i<ArraySize(keys);i++) {
    CDKPriceLevel* lev = lev[i];
    if(TimeCurrent() > lev.Finish.GetTime()) continue;
    if(lev.Hit.GetTime() != 0) continue; // Hit means DIV has found

    lev.Hit.SetIndexAndValue(0, lev.Start.GetValue());
    if(!RetestEnable) {
      lev.Finish.SetIndexAndValue(0, lev.Start.GetValue());
      EnterPos(lev);  
    }
  
    lev.Draw(Logger.Name+"-"+ChartPrefixDivGL, 0, 0);  
  }
}

//+------------------------------------------------------------------+
//| Waits reverse after hit and creates retest level
//+------------------------------------------------------------------+
void CPADDBot::CreateRetestLevelAfterReverse(void) {
  if(!RetestEnable) return; // v5. Only for RT.E=true
  
  datetime keys[];
  CDKPriceLevel* lev[];
  DivHash.CopyTo(keys, lev);
  for(int i=0;i<ArraySize(keys);i++) {
    CDKPriceLevel* lev = lev[i];
    if(TimeCurrent() > lev.Finish.GetTime()) continue;
    if(lev.Hit.GetTime() == 0) continue; // Level is not hit yet
    
    int prev_bar_idx = 1;
    double prev_bar_body_size = iClose(Sym.Name(), DivTF, prev_bar_idx)-iOpen(Sym.Name(), DivTF, prev_bar_idx);
    if(CompareDouble(prev_bar_body_size, 0.0)) continue; // bar has no dir
    
    // Wait only reverse bar for lev type
    if((lev.Type == LEVEL_TYPE_RESISTANCE && prev_bar_body_size > 0) ||
       (lev.Type == LEVEL_TYPE_SUPPORT && prev_bar_body_size < 0))
       continue;
       
    // Check O and C is not worst than level
    double prev_bar_o = iOpen(Sym.Name(), DivTF, prev_bar_idx);
    double prev_bar_c = iClose(Sym.Name(), DivTF, prev_bar_idx);
    double lev_val = lev.Start.GetValue();
    if(RetestReverseBarWorstLevelO_NAllow)
      if((lev.Type == LEVEL_TYPE_RESISTANCE && prev_bar_o < lev_val) ||
         (lev.Type == LEVEL_TYPE_SUPPORT && prev_bar_o > lev_val)) {
           Logger.Info(StringFormat("%s/%d: Reverse bar for Retest has filtred out: TYPE=%s; LEV(%s)=%s; REV_BAR_O=%s;",
                                    __FUNCTION__, __LINE__,
                                    EnumToString(lev.Type),
                                    TimeToString(lev.Start.GetTime()),
                                    Sym.PriceToString(lev_val),
                                    Sym.PriceToString(prev_bar_o)));
           continue;
         }
    if(RetestReverseBarWorstLevelC_NAllow)
      if((lev.Type == LEVEL_TYPE_RESISTANCE && prev_bar_c < lev_val) ||
         (lev.Type == LEVEL_TYPE_SUPPORT && prev_bar_c > lev_val)) {
            Logger.Info(StringFormat("%s/%d: Reverse bar for Retest has filtred out: TYPE=%s; LEV(%s)=%s; REV_BAR_C=%s;",
                                     __FUNCTION__, __LINE__,
                                     EnumToString(lev.Type),
                                      TimeToString(lev.Start.GetTime()),
                                     Sym.PriceToString(lev_val),
                                     Sym.PriceToString(prev_bar_c)));         
            continue;         
      }
    
    lev.Finish.SetIndexAndValue(0, lev.Start.GetValue());   
    CreateRetestLevel(lev);
      
    lev.Draw(Logger.Name+"-"+ChartPrefixDivGL, 0, 0);  
  }
}

//+------------------------------------------------------------------+
//| Draw all levels
//+------------------------------------------------------------------+
void CPADDBot::Draw(void) {
//  datetime keys[];
//  CDKPriceLevel* lev[];
//  LevelHash.CopyTo(keys, lev);
//  for(int i=0;i<ArraySize(keys);i++)
//    lev[i].Draw(Logger.Name+"-"+ChartPrefixLevel, 0, 0);
//
//  datetime keys_div[];
//  CDKPriceLevel* lev_div[];
//  LevelHash.CopyTo(keys_div, lev_div);    
//  DivHash.CopyTo(keys_div, lev_div);
//  for(int i=0;i<ArraySize(keys_div);i++)
//    lev_div[i].Draw(Logger.Name+"-"+ChartPrefixDiv, 0, 0);    
}

//+------------------------------------------------------------------+
//| Enter pos
//+------------------------------------------------------------------+
void CPADDBot::EnterPos(CDKPriceLevel* _lev) {
  // 0. Check TTI filter
  if (TTIEnable && !IsTimeAllowed(TimeCurrent(), TTIAddHours))
    return;
  
  // 1. EN.PD: Мин. задержка между позициями (0-нет), мин
  if(EN_PD_PosDelayMin > 0) {
    int delay_sec = (int)(TimeCurrent()-LastPosTime);
    if(delay_sec < (int)EN_PD_PosDelayMin*60) {
      if(Logger.Level >= DEBUG) 
        Logger.Debug(StringFormat("%s/%d: Entry filtred out due too short delay between pos (sec): %d<%d",
                                  __FUNCTION__, __LINE__,
                                  delay_sec, EN_PD_PosDelayMin*60));
      return;
    }
  }
  
  // 1.5. TS_ED_S_EnterDelay_Sec: Имитация задержки обработки стрелки
  if(EN_Mode != PADD_BOT_MODE_TRADING_FX)
    if(TS_ED_S_EnterDelay_Sec > 0) 
      Sleep(TS_ED_S_EnterDelay_Sec*1000);

  // 2. Reverse arrow and pos
  ENUM_LEVEL_TYPE lev_type = _lev.Type;
  if (ARRReverse) lev_type = ReverseLevelType(_lev.Type);
    
  if (!Sym.RefreshRates()) return;
  
  double price = (lev_type == LEVEL_TYPE_SUPPORT) ? Sym.Ask() : Sym.Bid();
  ENUM_POSITION_TYPE pos_type = (lev_type == LEVEL_TYPE_SUPPORT) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
  
  // Stop loss
  double sl = 0.0;
  if(EN_SL_AR_StopLoss_ATRRatio > 0) {
    double atr[];
    if (CopyBuffer(IndATR, 0, 0, 1, atr) < 0) return;
    sl = Sym.AddToPrice(pos_type, price, -1*atr[0]);
  }
  else sl = Sym.AddToPrice(pos_type, price, -1*ENSLDist);
  double sl_dist = MathAbs(price-sl);
  
  double lot = CalculateLotSuper(Sym.Name(), ENMMType, ENMMValue, price, sl);
  double tp = Sym.AddToPrice(pos_type, price, sl_dist*ENTPRRRatio);
  double arrow_price = Sym.Bid();
  
  // 3. Draw arrows
  if (ARREnable) {
    CChartObjectArrow* arrow = new CChartObjectArrow();    
    int code = (lev_type == LEVEL_TYPE_SUPPORT) ? ARRBuyCode : ARRSellCode;
    
    arrow.Create(0, 
                 StringFormat("%s-%s-%s-%s", Logger.Name, ChartPrefixArrow, LevelTypeToString(lev_type, true), TimeToString(_lev.Start.GetTime())), 
                 0, 
                 TimeCurrent(), 
                 arrow_price, //price, 
                 (char)code);
    arrow.Color((lev_type == LEVEL_TYPE_SUPPORT) ? ARRBuyColor : ARRSellColor);
  }
  
  // 4. Enter pos
  if (ENEnable) {
    string comment = _lev.GetFullChartID(Logger.Name);
    if(EN_Mode != PADD_BOT_MODE_TRADING_FX) {
      // For all testing modes disable SL and TP 
      // To close pos manually
      sl = 0; tp = 0;
      for(int i=0;i<TS_Times.Total();i++) {
        comment = StringFormat("%s|%d|%d|%s|%s", 
                               Logger.Name, 
                               EN_Mode,
                               TS_Times.At(i),
                               TimeframeToString(TS_EC_TF_ExpClose_TF),
                               Sym.PriceToString(arrow_price));      
      
        if (lev_type == LEVEL_TYPE_SUPPORT)    
          if(Trade.Buy(lot, Sym.Name(), price, sl, tp, comment) > 0)
            TS_Hour[i, GetHour(TimeCurrent())].IncTotal();
        if (lev_type == LEVEL_TYPE_RESISTANCE) 
          if(Trade.Sell(lot, Sym.Name(), price, sl, tp, comment) > 0) 
            TS_Hour[i, GetHour(TimeCurrent())].IncTotal();
      }
    }
    else {
      if (lev_type == LEVEL_TYPE_SUPPORT)    
        Trade.Buy(lot, Sym.Name(), price, sl, tp, comment);

      if (lev_type == LEVEL_TYPE_RESISTANCE) 
        Trade.Sell(lot, Sym.Name(), price, sl, tp, comment); 
    }
  }
  
  LastPosTime = TimeCurrent();  
}

//+------------------------------------------------------------------+
//| Returns Hour from _dt
//+------------------------------------------------------------------+
int CPADDBot::GetHour(datetime _dt) {
  MqlDateTime dt_mql;
  TimeToStruct(_dt, dt_mql);
  return dt_mql.hour;
}

//+------------------------------------------------------------------+
//| Check Time is inside min TTI.HI.ASM and TTI.HI.BSM
//+------------------------------------------------------------------+
bool CPADDBot::IsSecInsideMin() {
  if(TTIHitIntervalAfterSecOfMin < 60 || TTIHitIntervalBeforeSecOfMin < 60){
    MqlDateTime dt_curr_mql;
    TimeCurrent(dt_curr_mql);      

    if(dt_curr_mql.sec >= (int)TTIHitIntervalAfterSecOfMin && dt_curr_mql.sec < (int)TTIHitIntervalBeforeSecOfMin) 
      return true;
  }
  
  return false;
}

//+------------------------------------------------------------------+
//| Parse _pos.Comment to get time to close after
//+------------------------------------------------------------------+
int CPADDBot::GetTSTimeToCloseFromComment(const string _pos_comment) {
  CDKString str;
  str.Assign(_pos_comment);
  
  CArrayString list;
  str.Split("|", list);
  if(list.Total()>=3) 
    return (int)StringToInteger(list.At(2));
  
  return 0;  
}

//+------------------------------------------------------------------+
//| Check if pos needs close
//+------------------------------------------------------------------+
bool CPADDBot::IsPositionReadyToClose(CPositionInfo& _pos) {
  int close_pos_after_min = GetTSTimeToCloseFromComment(_pos.Comment());  
  datetime dt_close_at = _pos.Time() + close_pos_after_min*60;
  if (EN_Mode == PADD_BOT_MODE_TESTING_BO_EXPIRATION){
    int exp_bar_idx_start = iBarShift(_Symbol, TS_EC_TF_ExpClose_TF, _pos.Time());
    datetime exp_bar_dt_start = iTime(_Symbol, TS_EC_TF_ExpClose_TF, exp_bar_idx_start);
    
    dt_close_at = exp_bar_dt_start + PeriodSeconds(TS_EC_TF_ExpClose_TF)*1-1;
    double exp_dist_sec = PeriodSeconds(TS_EC_TF_ExpClose_TF) - (double)(_pos.Time() - exp_bar_dt_start);
    if (exp_dist_sec <= (close_pos_after_min*60))
      dt_close_at = exp_bar_dt_start + PeriodSeconds(TS_EC_TF_ExpClose_TF)*2-1;    
  }
  
  return(TimeCurrent() >= dt_close_at);
}

//+------------------------------------------------------------------+
//| Проверяет прибыльность по правилам рынка бинарных опционов.
//| Если текушая цена позы при закрытии лучше цены уровня, то поза прибыльная.
//+------------------------------------------------------------------+
bool CPADDBot::IsPosProfitInOptionMarket(CPositionInfo& _pos, const double _level_price) {
  if (_level_price <= 0.0) return false;
  
  Sym.RefreshRates();
  double curr_price = Sym.Bid();
  if ((_pos.PositionType() == POSITION_TYPE_BUY  && curr_price > _level_price) || 
      (_pos.PositionType() == POSITION_TYPE_SELL && curr_price < _level_price)) 
    return true;
  
  return false;
}

//+------------------------------------------------------------------+
//| Парсит коммент позы и возвращает цену уровня
//+------------------------------------------------------------------+
double CPADDBot::GetPosLevelPriceFromComment(CPositionInfo& _pos) {
  string comment_parts[];
  if (StringSplit(_pos.Comment(), StringGetCharacter("|", 0), comment_parts) >= 0) {
    double level_price = StringToDouble(comment_parts[ArraySize(comment_parts)-1]);
    return level_price;
  }
  
  return 0.0;    
}

//+------------------------------------------------------------------+
//| Close Trades in test modes                                                                  |
//+------------------------------------------------------------------+
void CPADDBot::CloseTrades() {
  CPositionInfo positionInfo;
  
  int i = 0;
  while (i < PositionsTotal()) {
    if(positionInfo.SelectByIndex(i))
      if (positionInfo.Symbol() == _Symbol 
        && positionInfo.Magic() == InpMagic) {
         
        if (IsPositionReadyToClose(positionInfo))
          if (Trade.PositionClose(positionInfo.Ticket())) {
            uint ret_code = Trade.ResultRetcode();
            if (ret_code == TRADE_RETCODE_DONE) {
              double level_price = GetPosLevelPriceFromComment(positionInfo);
              Sym.RefreshRates();
              double curr_price = Sym.Bid();
              logger.Info(StringFormat("Position closed: TICKET=%I64u; RES=%s; DIR=%s; LEVEL_PRICE=%f %s CLOSE_PRICE=%f", 
                                        positionInfo.Ticket(),
                                        (IsPosProfitInOptionMarket(positionInfo, level_price)) ? "PROFIT" : "LOSS",
                                        (positionInfo.PositionType() == POSITION_TYPE_BUY) ? "BUY" : "SELL",
                                        level_price,
                                        (level_price > curr_price) ? ">" : "<",
                                        curr_price
                                        ));
              
              int time_idx = TS_Times.SearchLinear(GetTSTimeToCloseFromComment(positionInfo.Comment()));
              
              if (positionInfo.PositionType() == POSITION_TYPE_BUY  && IsPosProfitInOptionMarket(positionInfo, level_price)) 
                TS_Hour[time_idx, GetHour(positionInfo.Time())].IncProfit();

              if (positionInfo.PositionType() == POSITION_TYPE_SELL && IsPosProfitInOptionMarket(positionInfo, level_price)) 
                TS_Hour[time_idx, GetHour(positionInfo.Time())].IncProfit();

              continue;
            }
            else
              logger.Error(StringFormat("Position close error: TICKET=%I64u | RET_CODE=%d", positionInfo.Ticket(), ret_code));
        } 
      }      
    i++;
  }  
}

//+------------------------------------------------------------------+
//| Loads TTI from file
//+------------------------------------------------------------------+
void CPADDBot::LoadTimeFilterFromFile() {
  int val_int;
  TTIAddHours = 0;
  TTIDescr =  StringFormat("TIME FILTER от %s:\n", TimeToString(TimeCurrent()));
  if(GetIniKey(TTIFilename, "TimeFilter", "AddHours", val_int)) { 
    TTIAddHours = val_int; 
    TTIDescr += StringFormat("Сдвиг часов: %d\n", TTIAddHours); 
  }
  else TTIDescr += "Сдвиг часов: 0\n";
  
  string str;  
  if(GetIniKey(TTIFilename, "TimeFilter", "EveryDay", str)) {
    PeriodDaysToMinutes(Day_Pause, str);
    TTIDescr += StringFormat("Каждый день: %s\n", str);
  }
  else { PeriodDaysToMinutes(Day_Pause, ""); TTIDescr += StringFormat("Каждый день: %s\n", "N/A"); }
  
  if(GetIniKey(TTIFilename, "TimeFilter", "EveryHour", str)) {
    HourToMinutes(Hour_Pause, str);
    TTIDescr += StringFormat("Каждый час: %s\n", str);
  }
  else { HourToMinutes(Hour_Pause, ""); TTIDescr += StringFormat("Каждый час: %s\n", "N/A");}
  
  if(GetIniKey(TTIFilename, "TimeFilter", "Monday", str)) {
    PeriodDaysToMinutes(Monday_Pause, str);
    TTIDescr += StringFormat("Пн: %s\n", str);
  }
  else { PeriodDaysToMinutes(Monday_Pause, ""); TTIDescr += StringFormat("Пон: %s\n", "N/A"); }
  
  if(GetIniKey(TTIFilename, "TimeFilter", "Tuesday", str)) {
    PeriodDaysToMinutes(Tuesday_Pause, str);
    TTIDescr += StringFormat("ВТ: %s\n", str);
  }
  else { PeriodDaysToMinutes(Tuesday_Pause, ""); TTIDescr += StringFormat("Вт: %s\n", "N/A"); }
  
  if(GetIniKey(TTIFilename, "TimeFilter", "Wednesday", str)) {
    PeriodDaysToMinutes(Wednesday_Pause, str); 
    TTIDescr += StringFormat("СР: %s\n", str);
  }
  else { PeriodDaysToMinutes(Wednesday_Pause, ""); TTIDescr += StringFormat("Ср: %s\n", "N/A"); }

  if(GetIniKey(TTIFilename, "TimeFilter", "Thursday", str)) {
    PeriodDaysToMinutes(Thursday_Pause, str);
    TTIDescr += StringFormat("ЧТ: %s\n", str);
  }
  else { PeriodDaysToMinutes(Thursday_Pause, ""); TTIDescr += StringFormat("Чт: %s\n", str); TTIDescr += StringFormat("Чт: %s\n", "N/A"); }
  
  if(GetIniKey(TTIFilename, "TimeFilter", "Friday", str)) { 
    PeriodDaysToMinutes(Friday_Pause, str);
    TTIDescr += StringFormat("ПТ: %s\n", str);
  }
  else { PeriodDaysToMinutes(Friday_Pause, ""); TTIDescr += StringFormat("Пт: %s\n", "N/A"); }
  
  CommentText = TTIDescr;
}

//+------------------------------------------------------------------+
//| Check TTI file modified and reloads TTI
//+------------------------------------------------------------------+
void CPADDBot::CheckTTIUpdatedAndReload() {
  if (!TTIEnable) return;
  
  if(TimeCurrent()<=TTIFileModified) return;
  
  datetime dt = (datetime)GetFileTimeToStrAPI(TTIFilename, 3);
  if (dt>TTIFileModified) { 
    LoadTimeFilterFromFile(); 
    TTIFileModified = dt;
  }
}