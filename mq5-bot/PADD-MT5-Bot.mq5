//+------------------------------------------------------------------+
//|                                                 PADD-MT5-Bot.mq5 |
//|                                                  Denis Kislitsyn |
//|                                             https://kislitsyn.me |
//+------------------------------------------------------------------+

#property script_show_inputs

#include "Include\DKStdLib\Common\DKStdLib.mqh"
#include "Include\DKStdLib\Logger\CDKLogger.mqh"
#include "Include\DKStdLib\License\DKLicense.mqh";
#include "Include\DKStdLib\TradingManager\CDKTrade.mqh"

#include "CPADDBot.mqh"

input     group                    "1.1 ВХОДЫ (EN)"
input     ENUM_PADD_BOT_MODE       Inp_EN_Mode                           = PADD_BOT_MODE_TRADING_FX;            // EN.MOD: Режим
input     bool                     InpENEnable                           = true;                                // EN.E: Открывать позиции?
input     ENUM_MM_TYPE             InpENMMType                           = ENUM_MM_TYPE_FIXED_LOT;              // EN.MMT: Тип расчета лота
input     double                   InpENMMValue                          = 0.01;                                // EN.MMV: Значение для расчета лот
input     uint                     InpENSLDist                           = 1000;                                // EN.SL.FD: Фиксированная дистанция SL, пункт
input     double                   Inp_EN_SL_AR_StopLoss_ATRRatio        = 1.5;                                 // EN.SL.AR: Множитель ATR для SL (0-откл)
          uint                     InpENTPDist                           = 5000;                                // EN.TPD: Фиксированная дистанция TP, пункт
input     double                   InpENTPRRRatio                        = 2.5;                                 // EN.TPRR: Мультипликатор RR для TP
input     uint                     Inp_EN_PD_PosDelayMin                 = 1;                                   // EN.PD: Мин. задержка между позициями (0-нет), мин

input     group                    "1.2 ТЕСТИРОВАНИЕ (TS)"
input     uint                     Inp_TS_ED_S_EnterDelay_Sec            = 5;                                   // TS.ED.S: Задержка перед входом в позицию, сек
input     string                   Inp_TS_FCA_M_FixedCloseAfter_Min      = "5;6";                               // TS.FCA.M: Фиксированное время в сделке через ";", мин
input     ENUM_TIMEFRAMES          Inp_TS_EC_TF_ExpClose_TF              = PERIOD_M1;                           // TS.EC.TF: Таймфрейм определения экспирации
input     string                   Inp_TS_EC_AL_M_ExpClose_AddBarWhenLessToClose_Min = "3;5";                   // TS.EC.AL.M: Мин.время от стрелки до конца бара экспирации через ";", мин

input     group                    "2. СТРЕЛКИ (ARR)"
input     bool                     InpARREnable                          = true;                                // ARR.E: Рисовать стрелки?
input     bool                     InpARRReverse                         = false;                               // ARR.R: Реверс стрелок и сделок?
input     int                      InpARRBuyCode                         = 233;                                 // ARR.B.CD: Код стрелки BUY
input     color                    InpARRBuyColor                        = clrGreen;                            // ARR.B.CL: Цвет стрелки BUY
input     int                      InpARRSellCode                        = 234;                                 // ARR.B.CD: Код стрелки SELL
input     color                    InpARRSellColor                       = clrRed;                              // ARR.B.CD: Цвет стрелки SELL

input     group                    "3.0. ФРАКТАЛЫ (F)"
input     ENUM_TIMEFRAMES          InpFractalTF                          = PERIOD_M1;                           // F.FTF: Timeframe фракталов
input     uint                     InpLevelStartMin                      = 5;                                   // F.LST: Время начала действия уровня, мин
input     uint                     InpLevelExpirationMin                 = 240;                                 // F.LEX: Срок действия уровня, мин
input     int                      InpLevelShiftPnt                      = 0;                                   // F.LSP: Доп. сдвиг уровня от фрактала, пункт
input     uint                     Inp_F_F_OEN_Fractal_Filter_OnlyExtremeBar = 0;                               // F.F.OEN: Фильтр: Только на экстремуме за N баров на F.FTF ТФ (0-откл)

input     group                    "3.1. ФРАКТАЛ ВЕРХ (FU)"
input     bool                     InpFUEnable                           = true;                                // FU.E: Фрактал включен?
input     uint                     InpFULeftBarCount                     = 3;                                   // FU.LBC: Свечей слева, шт
input     bool                     InpFULeftHighSorted                   = true;                                // FU.LHS: HIGH свечей слева упорядочены
input     bool                     InpFULeftLowSorted                    = true;                                // FU.LLS: LOW свечей слева упорядочены
input     uint                     InpFURightBarCount                    = 3;                                   // FU.RBC: Свечей справа, шт
input     bool                     InpFURightHighSorted                  = true;                                // FU.RHS: HIGH свечей справа упорядочены
input     bool                     InpFURightLowSorted                   = true;                                // FU.RLS: LOW свечей справа упорядочены
sinput    uint                     InpFUArrowCode                        = 234;                                 // FU.ACD: Код символа стрелки
sinput    color                    InpFUArrowColor                       = clrRed;                              // FU.ACL: Цвет стрелки

input     group                    "3.2. ФРАКТАЛ НИЗ (FD)"
input     bool                     InpFDEnable                           = true;                                // FD.E: Фрактал включен?
input     uint                     InpFDLeftBarCount                     = 3;                                   // FD.LBC: Свечей слева, шт
input     bool                     InpFDLeftHighSorted                   = true;                                // FD.LHS: HIGH свечей слева упорядочены
input     bool                     InpFDLeftLowSorted                    = true;                                // FD.LLS: LOW свечей слева упорядочены
input     uint                     InpFDRightBarCount                    = 3;                                   // FD.RBC: Свечей справа, шт
input     bool                     InpFDRightHighSorted                  = true;                                // FD.RHS: HIGH свечей справа упорядочены
input     bool                     InpFDRightLowSorted                   = true;                                // FD.RLS: LOW свечей справа упорядочены
sinput    uint                     InpFDArrowCode                        = 233;                                 // FD.ACD: Код символа стрелки
sinput    color                    InpFDArrowColor                       = clrGreen;                            // FD.ACL: Цвет стрелки

input     group                    "4. ДИВЕРГЕНЦИЯ (DV): D1-D2-...-DN"
input     ENUM_PADD_DIV_MODE       InpDivMode                            = PADD_DIV_MODE_BOTH;                  // DV.DIV.M: Режим дивергенции
input     ENUM_TIMEFRAMES          InpDivTF                              = PERIOD_M1;                           // DV.DBL: Timeframe дивергенции
input     uint                     InpDivStartShiftLeftMin               = 240;                                 // DV.DST: Свдиг ожидания дивергенции влево от касания, мин
input     uint                     InpDivExpirationMin                   = 240;                                 // DV.DEX: Срок ожидания дивергенции после касания, мин
input     uint                     InpDivBarsBetweenMin                  = 3;                                   // DV.BB.MIN: Мин. количество баров между вершинами RSI, шт
input     uint                     InpDivBarsBetweenMax                  = 100;                                 // DV.BB.MAX: Макс. количество баров между вершинами RSI, шт
input     ENUM_PADD_RSI_FILTER_MODE InpDivRSIFilterMode                  = PADD_RSI_FILTER_MODE_ALL;            // DV.RSI.FM: Режим фильтра вершин RSI
input     double                   InpDivSupRSIMin                       = 0.0;                                 // DV.SUP.RSI.MIN: Мин. RSI для вершин поддержки
input     double                   InpDivSupRSIMax                       = 30.0;                                // DV.SUP.RSI.MAX: Макс. RSI для вершин поддержки
input     double                   InpDivResRSIMin                       = 70.0;                                // DV.RES.RSI.MIN: Мин. RSI для вершин сопротивления
input     double                   InpDivResRSIMax                       = 100.0;                               // DV.RES.RSI.MAX: Макс. RSI для вершин сопротивления
input     uint                     InpDivMinPartCount                    = 2;                                   // DV.MPC: Мин. количество последовательных сегментов дивергенции
input     bool                     InpDivVAllow                          = false;                               // DV.VA: Разрешить разнонаправленные сегменты (\/ или /\)
input     bool                     InpDivNoLeftLowFilterEnable           = false;                               // DV.LHF.LB.E: Запрет пробития уровня слева от D1 на DV.LHF.C
input     bool                     InpDivLevelHitFromTouchToDivEnable    = true;                                // DV.LHF.TD.E: Обязат. пробитие уровня слева от DN+1 на DV.LHF.C
input     uint                     InpDivLeftBarCount                    = 3;                                   // DV.LHF.C: Кол. свечей слева для проверки пробития уровня
input     bool                     InpDivLastBarIsHighest                = true;                                // DV.HLB.E: Последняя свеча дивергенции выше всех, начиная с касания
input     bool                     InpDivUseNextBarExtremeEnable         = true;                                // DV.NBE.E: Использовать H/L соседних свечей цены для дивергенции
input     bool                     InpDivStartOnlyAtFractalEnable        = true;                                // DV.SAF.E: Дивергенции обязательно начинается на фрактале
input     double                   InpDivTouchSupRSIMin                  = 0.0;                                 // DV.TCH.SUP.RSI.MIN: Мин. RSI в момент касания для поддержки
input     double                   InpDivTouchSupRSIMax                  = 30.0;                                // DV.TCH.SUP.RSI.MAX: Макс. RSI в момент касания для поддержки
input     double                   InpDivTouchResRSIMin                  = 70.0;                                // DV.TCH.RES.RSI.MIN: Мин. RSI в момент касания для сопротивления
input     double                   InpDivTouchResRSIMax                  = 100.0;                               // DV.TCH.RES.RSI.MAX: Макс. RSI в момент касания для сопротивления
input     double                   InpDivTouchSupATRMin                  = 0.0;                                 // DV.TCH.SUP.ATR.MIN: Мин. ATR в момент касания для поддержки
input     double                   InpDivTouchSupATRMax                  = 100.0;                               // DV.TCH.SUP.ATR.MAX: Макс. ATR в момент касания для поддержки
input     double                   InpDivTouchResATRMin                  = 0.0;                                 // DV.TCH.RES.ATR.MIN: Мин. ATR в момент касания для сопротивления
input     double                   InpDivTouchResATRMax                  = 100.0;                               // DV.TCH.RES.ATR.MAX: Макс. ATR в момент касания для сопротивления

input     group                    "5. РЕТЕСТ (RT)"
input     bool                     InpRetestEnable                       = true;                                // RT.E: Ретест включен?
input     double                   InpRetestEnterImmediatelyATRRatio     = 2.0;                                 // RT.IE: Коэф. ATR размера свечи ОН для немедленного входа
input     double                   InpRetestNotEnterATRRatio             = 5.0;                                 // RT.NE: Коэф. ATR размера свечи ОН для инвалидации уровня
input     double                   InpRetestBarSizeRatio                 = 0.5;                                 // RT.BR: Коэф. размера свечи ОН ретест уровня (0.5=50%)
input     uint                     InpRetestExpirationMin                = 60;                                  // RT.EXP: Срок ожидания ретеста, мин
input     bool                     InpRetestReverseBarWorstLevelO_NAllow = true;                                // RT.OWL.V5: Запрещен Open обратной свечи хуже уровня
input     bool                     InpRetestReverseBarWorstLevelC_NAllow = true;                                // RT.CWL.V5: Запрещен Сlose обратной свечи хуже уровня

input     group                    "6. RSI"
input     int                      InpRSIMAPeriod                        = 14;                                  // RSI.MAP: RSI Период MA
input     ENUM_APPLIED_PRICE       InpRSIAppliedPrice                    = PRICE_CLOSE;                         // RSI.AP: RSI Применять к цене
input     bool                     InpRSIDivTopMinDistEnable             = true;                                // RSI.DP.E: Фильтр входа по мин. дистанции между вершинами RSI дивергенции
input     double                   InpRSIDivTopMinDistValue              = 1.0;                                 // RSI.DP.V: Мин. дистанция между вершинами RSI дивергенции, %

input     group                    "7. ATR"
input     int                      InpATRMAPeriod                        = 48;                                  // ATR.MAP: Период MA
input     bool                     InpATREntryBarSizeEnable              = true;                                // ATR.BR.E: Фильтр входа по H-L свечи обратного направления
input     double                   InpATRRatio                           = 1.5;                                 // ATR.BR.R: Мультипликатор ATR для свечи обратного направления
input     bool                     InpATRLevDIVDistEnable                = true;                                // ATR.LD.E: Фильтр входа по дистанции от уровня до H/L старта дивергенции
input     double                   InpATRLevDIVDistRatio                 = 5.0;                                 // ATR.LD.R: Мультипликатор ATR для дистанции от уровня до H/L старта дивергенции
input     bool                     InpATRDivTopPriceMinDistEnable        = true;                                // ATR.DP.E: Фильтр входа по мин. дистанции между вершинами ценовой дивергенции
input     double                   InpATRDivTopPriceMinDistRatio         = 1.5;                                 // ATR.DP.R: Мультипликатор ATR для дистанции между вершинами ценовой дивергенции

input     group                    "8. ФИЛЬТР"          
input     bool                     InpTTIEnable                          = false;                               // TTI.E: Фильтр времени включен? 
input     string                   InpTTIFilename                        = "C:\\Users\\<User>\\AppData\\Roaming\\MetaQuotes\\Terminal\\Common\\Files\\TimeFilter.ini"; // TTI.FN: Полное имя INI файла настроек фильтра по времени
input     uint                     InpTTIHitIntervalAfterSecOfMin        = 5;                                   // TTI.HI.ASM: Отфильтровать касания после какой секунды каждой минуты (>=60-откл)
input     uint                     InpTTIHitIntervalBeforeSecOfMin       = 55;                                  // TTI.HI.BSM: Отфильтровать касания до какой секунты каждой минуты  (>=60-откл)

input     double                   InpLSFLeftShoulderRatio               = 0.5;                                 // LSF.LS.RAT: Коэф. длины левого плеча к длине правого (0-откл)
input     bool                     InpLSFLeftExtremeEnable               = true;                                // LSF.LE.ENB: Запретить пробой H/L левого плеча
input     ENUM_PADD_SHOULDER_EXTREME_FILTER_MODE InpLSFShoulderCompareMode = PADD_SHOULDER_EXTREME_FILTER_MODE_LH_RC; // LSF.SC.MOD: Фильтр по экстремумам левого и правого плечей

input     group                    "9. ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ"
input     ulong                    InpMagic                              = 202407111;                           // Magic: Идентификатор эксперта
sinput    string                   InpGlobalPrefix                       = "PADD";                              // GP: Префикс комментариев и графики
sinput    bool                     InpCommentEnable                      = true;                                // MS.CE: Comment Enable (turn off with no visual for speed)
sinput    uint                     InpCommentIntervalSec                 = 1*60;                                // MS.CI: Comment Interval update, sec
sinput    LogLevel                 InpLL                                 = LogLevel(INFO);                      // MS.LL: Log Level
sinput    string                   InpLFI                                = "";                                  // MS.LF.I: Log Filter IN String (use `;` as sep)
sinput    string                   InpLFO                                = "";                                  // MS.LF.O: Log Filter OUT String (use `;` as sep)


CPADDBot                           bot;
CDKTrade                           trade;
CDKLogger                          logger;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){  
  logger.Init(InpGlobalPrefix, InpLL);
  logger.FilterInFromStringWithSep(InpLFI, ";");
  logger.FilterOutFromStringWithSep(InpLFO, ";");
  
  trade.Init(Symbol(), InpMagic, 0, GetPointer(logger));
  
  bot.EN_Mode = Inp_EN_Mode;
  bot.ENEnable = InpENEnable;
  bot.ENMMType = InpENMMType;
  bot.ENMMValue = InpENMMValue;
  bot.ENSLDist = InpENSLDist;
  bot.EN_SL_AR_StopLoss_ATRRatio = Inp_EN_SL_AR_StopLoss_ATRRatio;
  bot.ENTPDist = InpENTPDist;
  bot.ENTPRRRatio = InpENTPRRRatio; 
  bot.EN_PD_PosDelayMin = Inp_EN_PD_PosDelayMin;
  
  bot.TS_ED_S_EnterDelay_Sec = Inp_TS_ED_S_EnterDelay_Sec;
  bot.TS_EC_AL_M_ExpClose_AddBarWhenLessToClose_Min = Inp_TS_EC_AL_M_ExpClose_AddBarWhenLessToClose_Min;
  bot.TS_EC_TF_ExpClose_TF = Inp_TS_EC_TF_ExpClose_TF;
  bot.TS_FCA_M_FixedCloseAfter_Min = Inp_TS_FCA_M_FixedCloseAfter_Min;
  
  bot.ARREnable = InpARREnable;
  bot.ARRReverse = InpARRReverse;
  bot.ARRBuyCode = InpARRBuyCode;
  bot.ARRBuyColor = InpARRBuyColor;
  bot.ARRSellCode = InpARRSellCode;
  bot.ARRSellColor = InpARRSellColor;

  bot.FractalTF = InpFractalTF;
  bot.LevelStartMin = InpLevelStartMin;
  bot.LevelExpirationMin = InpLevelExpirationMin;  
  bot.LevelShiftPnt = InpLevelShiftPnt;
  bot.F_F_OEN_Fractal_Filter_OnlyExtremeBar = Inp_F_F_OEN_Fractal_Filter_OnlyExtremeBar;

  bot.FUEnable = InpFUEnable;
  bot.FULeftBarCount = InpFULeftBarCount;
  bot.FULeftHighSorted = InpFULeftHighSorted;
  bot.FULeftLowSorted = InpFULeftLowSorted;
  bot.FURightBarCount = InpFURightBarCount;
  bot.FURightHighSorted = InpFURightHighSorted;
  bot.FURightLowSorted = InpFURightLowSorted;
  bot.FUArrowCode = InpFUArrowCode;
  bot.FUArrowColor = InpFUArrowColor;
  
  bot.FDEnable = InpFDEnable;
  bot.FDLeftBarCount = InpFDLeftBarCount;
  bot.FDLeftHighSorted = InpFDLeftHighSorted;
  bot.FDLeftLowSorted = InpFDLeftLowSorted;
  bot.FDRightBarCount = InpFDRightBarCount;
  bot.FDRightHighSorted = InpFDRightHighSorted;
  bot.FDRightLowSorted = InpFDRightLowSorted;
  bot.FDArrowCode = InpFDArrowCode;
  bot.FDArrowColor = InpFDArrowColor;  
  
  bot.DivMode = InpDivMode;
  bot.DivMinPartCount = InpDivMinPartCount;
  bot.DivTF = InpDivTF;
  bot.DivStartShiftLeftMin = InpDivStartShiftLeftMin;
  bot.DivExpirationMin = InpDivExpirationMin;
  bot.DivBarsBetweenMin = InpDivBarsBetweenMin;
  bot.DivBarsBetweenMax = InpDivBarsBetweenMax;
  bot.DivRSIFilterMode = InpDivRSIFilterMode;
  bot.DivSupRSIMin = InpDivSupRSIMin;
  bot.DivSupRSIMax = InpDivSupRSIMax;
  bot.DivResRSIMin = InpDivResRSIMin;
  bot.DivResRSIMax = InpDivResRSIMax;
  bot.DivVAllow = InpDivVAllow;
  bot.DivNoLeftLowFilterEnable = InpDivNoLeftLowFilterEnable;
  bot.DivLeftBarCount = InpDivLeftBarCount;
  bot.DivLevelHitFromTouchToDivEnable = InpDivLevelHitFromTouchToDivEnable;
  bot.DivLastBarIsHighest = InpDivLastBarIsHighest;
  bot.DivUseNextBarExtremeEnable = InpDivUseNextBarExtremeEnable;
  bot.DivStartOnlyAtFractalEnable = InpDivStartOnlyAtFractalEnable;
  bot.DivTouchSupRSIMin = InpDivTouchSupRSIMin;
  bot.DivTouchSupRSIMax = InpDivTouchSupRSIMax;
  bot.DivTouchResRSIMin = InpDivTouchResRSIMin;
  bot.DivTouchResRSIMax = InpDivTouchResRSIMax;
  bot.DivTouchSupATRMin = InpDivTouchSupATRMin;
  bot.DivTouchSupATRMax = InpDivTouchSupATRMax;
  bot.DivTouchResATRMin = InpDivTouchResATRMin;
  bot.DivTouchResATRMax = InpDivTouchResATRMax;

  
  bot.RSIMAPeriod = InpRSIMAPeriod;
  bot.RSIAppliedPrice = InpRSIAppliedPrice;
  bot.RSIDivTopMinDistEnable = InpRSIDivTopMinDistEnable;
  bot.RSIDivTopMinDistValue = InpRSIDivTopMinDistValue;
  
  bot.ATREntryBarSizeEnable = InpATREntryBarSizeEnable;
  bot.ATRMAPeriod = InpATRMAPeriod;
  bot.ATRRatio = InpATRRatio;
  bot.ATRLevDIVDistEnable = InpATRLevDIVDistEnable;
  bot.ATRLevDIVDistRatio = InpATRLevDIVDistRatio;
  bot.ATRDivTopPriceMinDistEnable = InpATRDivTopPriceMinDistEnable;
  bot.ATRDivTopPriceMinDistRatio = InpATRDivTopPriceMinDistRatio;
  bot.RetestEnable = InpRetestEnable;
  bot.RetestEnterImmediatelyATRRatio = InpRetestEnterImmediatelyATRRatio;
  bot.RetestNotEnterATRRatio = InpRetestNotEnterATRRatio;
  bot.RetestExpirationMin = InpRetestExpirationMin;
  bot.RetestBarSizeRatio = InpRetestBarSizeRatio;
  bot.RetestReverseBarWorstLevelO_NAllow = InpRetestReverseBarWorstLevelO_NAllow;
  bot.RetestReverseBarWorstLevelC_NAllow = InpRetestReverseBarWorstLevelC_NAllow;
  
  bot.TTIEnable = InpTTIEnable;
  bot.TTIFilename = InpTTIFilename;
  bot.TTIHitIntervalAfterSecOfMin = InpTTIHitIntervalAfterSecOfMin;
  bot.TTIHitIntervalBeforeSecOfMin = InpTTIHitIntervalBeforeSecOfMin;
  
  bot.LSFLeftExtremeEnable = InpLSFLeftExtremeEnable;
  bot.LSFLeftShoulderRatio = InpLSFLeftShoulderRatio;
  bot.LSFShoulderCompareMode = InpLSFShoulderCompareMode;  
  
  bot.Init(Symbol(), bot.FractalTF, InpMagic, trade, GetPointer(logger));
  bot.NewBarDetector.AddTimeFrame(bot.DivTF);
  
  if (!bot.Check()) return(INIT_PARAMETERS_INCORRECT);
  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)  {
//--- destroy timer
  EventKillTimer();
  bot.OnDeinit(reason);
}
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()  {
  bot.OnTick();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()  {
  bot.OnTimer();
}

//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()  {
  bot.OnTrade();
}

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {

   
  }

