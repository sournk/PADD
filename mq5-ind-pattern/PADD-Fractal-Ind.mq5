//+------------------------------------------------------------------+
//|                                             PADD-Fractal-Ind.mq5 |
//|                                                  Denis Kislitsyn |
//|                                             https://kislitsyn.me |
//+------------------------------------------------------------------+
#property copyright "Denis Kislitsyn"
#property link      "https://kislitsyn.me"
#property version   "1.00"
#property indicator_chart_window

#property indicator_buffers 1
#property indicator_plots   1

#property indicator_label1  "Фрактал"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed
#property indicator_width1  1

#include <Arrays/ArrayObj.mqh>

#include "Include\DKStdLib\Logger\CDKLogger.mqh"
#include "Include\DKStdLib\Common\DKStdLib.mqh"

enum ENUM_FRACTAL_TYPE {
  FRACTAL_TYPE_UP   = 0, // Верх
  FRACTAL_TYPE_DOWN = 1, // Низ
};

input  group              "1. ОСНОВНЫЕ (B)"
input  ENUM_FRACTAL_TYPE  InpFractalType                    = FRACTAL_TYPE_UP;                  // B.FT: Тип фрактала
sinput uint               InpArrowCode                      = 234;                              // B.ACD: Код символа стрелки
sinput color              InpArrowColor                     = clrRed;                           // B.ACL: Цвет стрелки

input  group              "2. ФИЛЬТРЫ (F)"
input  uint               InpLeftBarCount                   = 3;                                // F.LBC: Свечей слева, шт
input  bool               InpLeftHighSorted                 = true;                             // F.LHS: HIGH свечей слева упорядочены
input  bool               InpLeftLowSorted                  = true;                             // F.LLS: LOW свечей слева упорядочены
input  uint               InpRightBarCount                  = 3;                                // F.RBC: Свечей справа, шт
input  bool               InpRightHighSorted                = true;                             // F.RHS: HIGH свечей справа упорядочены
input  bool               InpRightLowSorted                 = true;                             // F.RLS: LOW свечей справа упорядочены

// input  group              "3. ПРОЧЕЕ (M)"
       LogLevel           InpLogLevel                       = LogLevel(ERROR);                  // M.LL: Уровень логирования
       string             InpGlobalPrefix                   = "PADD.I";

CDKLogger                 logger;

double                    buffer_pattern[];

void InitBuffer(const int _buffer_num, double& _buffer[],
                const int _plot_arrow_code, const int _plot_arrow_shift, const color _color,
                const double _plot_empty_value) {
                
  SetIndexBuffer(_buffer_num, _buffer, INDICATOR_DATA); //--- indicator buffers mapping
  PlotIndexSetInteger(_buffer_num, PLOT_ARROW, _plot_arrow_code); //--- зададим код символа для отрисовки в PLOT_ARROW
  PlotIndexSetInteger(_buffer_num, PLOT_ARROW_SHIFT, _plot_arrow_shift); //--- зададим cмещение стрелок по вертикали в пикселях 
  PlotIndexSetDouble(_buffer_num, PLOT_EMPTY_VALUE, _plot_empty_value); //--- установим в качестве пустого значения 0
  PlotIndexSetInteger(_buffer_num, PLOT_LINE_COLOR, _color); //--- зададим цвет
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
  logger.Name   = InpGlobalPrefix;
  logger.Level  = InpLogLevel;
  logger.Format = "%name%:[%level%] %message%";
  //if(MQL5InfoInteger(MQL5_DEBUGGING)) logger.Level = LogLevel(DEBUG);
  
  if (InpLeftBarCount <= 0 || InpRightBarCount <= 0) {
    logger.Error("Количество свечей слева и справа фрактала должны быть положительные", true);
    return(INIT_PARAMETERS_INCORRECT);
  }
  
  InitBuffer(0, buffer_pattern, InpArrowCode, 0, InpArrowColor, 0);
  
  logger.Info(StringFormat("%s: SYM=%s | TF=%s",
                           __FUNCTION__,
                           _Symbol,
                           EnumToString(_Period)));
                                                      
  return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
}

bool IsSorted(double &_buf[], const int _start_idx, const int _finish_idx, const int _dir) {
  double prev = _buf[_start_idx];
  for(int i=_start_idx+1;i<=_finish_idx;i++) {
    if ((_dir >= 0 && _buf[i] <= prev) ||
        (_dir < 0  && _buf[i] >= prev)) 
        return false;
    
    prev = _buf[i];
  }
     
  return true;
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &t[],
                const double &o[],
                const double &h[],
                const double &l[],
                const double &c[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
                
  // For manually refreshed chart           
  if (prev_calculated == 0) { 
  }
                
  // Fill 0.0 for buffers
  for(int i=rates_total-1; i>MathMax(prev_calculated-1, 0); i--) 
    buffer_pattern[i] = 0.0;
  
  double high[]; ArrayCopy(high, h);
  double low[];  ArrayCopy(low,  l);
  int dir = (InpFractalType == FRACTAL_TYPE_UP) ? +1 : -1;
  
  int start_idx = MathMax(prev_calculated, (int)InpLeftBarCount);
  if (start_idx > (ArraySize(h)-1)) return(prev_calculated);
  
  int finish_idx = ArraySize(h)-1-(int)InpRightBarCount-1;
  
  for (int i=start_idx; i<=finish_idx; i++) {
    if (InpLeftHighSorted  && !IsSorted(high, i-InpLeftBarCount, i, +1*dir)) continue;
    if (InpLeftLowSorted   && !IsSorted(low,  i-InpLeftBarCount, i, +1*dir)) continue;
    
    if (InpRightHighSorted && !IsSorted(high, i, i+InpRightBarCount, -1*dir)) continue;
    if (InpRightLowSorted  && !IsSorted(low,  i, i+InpRightBarCount, -1*dir)) continue;
    
    buffer_pattern[i] = (dir > 0) ? h[i] : l[i];
  }
  
  return(finish_idx+1);                         
}
