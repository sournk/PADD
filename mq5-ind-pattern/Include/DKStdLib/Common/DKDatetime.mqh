//+------------------------------------------------------------------+
//|                                                   DKDatetime.mqh |
//|                                                  Denis Kislitsyn |
//|                                             https://kislitsyn.me |
//+------------------------------------------------------------------+
#property copyright "Denis Kislitsyn"
#property link      "https://kislitsyn.me"
#property version   "0.0.1"


enum ENUM_DATETIME_PART {
  DATETIME_PART_YEAR    = 1*60*60*24*366,
  DATETIME_PART_QUARTER = 1*60*60*24*(31+30+31),
  DATETIME_PART_MON     = 1*60*60*24*31,
  DATETIME_PART_WEEK    = 1*60*60*24*7,
  DATETIME_PART_DAY     = 1*60*60*24,
  DATETIME_PART_HOUR    = 1*60*60,
  DATETIME_PART_MIN     = 1*60,
  DATETIME_PART_SEC     = 1,
};

//+------------------------------------------------------------------+
//| Returns begining of datetime part, i.g:
//|   - Begining of the month: TimeBegining(D'2023-12-22 10:10:10', DATETIME_PART_MON) == D'2023-12-01 00:00:00'
//|   - Begining of the day:   TimeBegining(D'2023-12-22 10:10:10', DATETIME_PART_DAY) == D'2023-12-22 00:00:00'
//+------------------------------------------------------------------+
datetime TimeBeginning(datetime _dt, ENUM_DATETIME_PART _dt_part) {
  MqlDateTime dt_struc;
  TimeToStruct(_dt, dt_struc);
  
  // Proccessing datetime
  if (_dt_part == DATETIME_PART_WEEK) {
    int day_of_week_ru = (dt_struc.day_of_week > 0) ? dt_struc.day_of_week : 7;
    _dt = _dt - (day_of_week_ru-1) * ((int)DATETIME_PART_DAY);
    TimeToStruct(_dt, dt_struc);
    _dt_part = DATETIME_PART_DAY;
  }
  
  if (_dt_part >= DATETIME_PART_YEAR)    dt_struc.mon  = 1;
  if (_dt_part >= DATETIME_PART_QUARTER) dt_struc.mon  = ((int)((dt_struc.mon-1)/3))*3+1;
  if (_dt_part >= DATETIME_PART_MON)     dt_struc.day  = 1;
  if (_dt_part >= DATETIME_PART_WEEK)    dt_struc.day  = 1;
  if (_dt_part >= DATETIME_PART_DAY)     dt_struc.hour = 0;
  if (_dt_part >= DATETIME_PART_HOUR)    dt_struc.min  = 0;
  if (_dt_part >= DATETIME_PART_MIN)     dt_struc.sec  = 0;
  
  return StructToTime(dt_struc);
}

//+------------------------------------------------------------------+
//| Returns end of datetime part, i.g:
//|   - End of the month: TimeBegining(D'2023-12-22 10:10', DATETIME_PART_MON) == D'2023-12-31 23:59:59'
//|   - End of the day:   TimeBegining(D'2023-12-22 10:10', DATETIME_PART_DAY) == D'2023-12-22 23:59:59'
//+------------------------------------------------------------------+
datetime TimeEnd(datetime _dt, const ENUM_DATETIME_PART _dt_part) {
  _dt = _dt + (int)_dt_part;
  return TimeBeginning(_dt, _dt_part)-1;
}