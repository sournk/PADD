//+------------------------------------------------------------------+
//|                                               DKNewBarDetector.mqh |
//|                                                  Denis Kislitsyn |
//|                                               http:/kislitsyn.me |
//+------------------------------------------------------------------+
#property copyright "Denis Kislitsyn"
#property link      "http:/kislitsyn.me"
   
#include <Generic\HashMap.mqh>
#include <Arrays\ArrayInt.mqh>  

 
class DKNewBarDetector
{
  private: 
    string MonitoredSymbol;
    CHashMap <ENUM_TIMEFRAMES, datetime> BarTime;

  public:
    void DKNewBarDetector(void) {};
    void DKNewBarDetector(string NewSymbolName) {SetSymbol(NewSymbolName);}
    void DKNewBarDetector(string NewSymbolName, ENUM_TIMEFRAMES TimeFrame) 
    {
      SetSymbol(NewSymbolName);
      AddTimeFrame(TimeFrame);
    }
    
    void SetSymbol(string NewSymbolName) {MonitoredSymbol = NewSymbolName;}
    
    bool AddTimeFrame(ENUM_TIMEFRAMES PeriodToDetect)
    {
      return(BarTime.Add(PeriodToDetect, 0));
    }
    
    bool AddTimeFrameSkipCurrentBar(ENUM_TIMEFRAMES aPeriodToDetect)
    {
      return(BarTime.Add(aPeriodToDetect, iTime(MonitoredSymbol, aPeriodToDetect, 0)));
    }   
    
    int TimeFramesCount()
    {
      return(BarTime.Count());
    } 
    
    bool RemoveTimeFrame(ENUM_TIMEFRAMES PeriodToDetect)
    {
      return(BarTime.Remove(PeriodToDetect));
    }
    
    void ClearTimeFrames()
    {
      BarTime.Clear();
    }
    
    // // Return true if new bar avaliable on PeriodToDetect timeframe.
    bool CheckNewBarAvaliable(ENUM_TIMEFRAMES PeriodToDetect)
    {
      datetime CurrentBarDateTime, LastBarDateTime;
      
      if (BarTime.TryGetValue(PeriodToDetect, LastBarDateTime))
      {
        CurrentBarDateTime = iTime(MonitoredSymbol, PeriodToDetect, 0);
        if (CurrentBarDateTime > LastBarDateTime)
        {
          BarTime.Remove(PeriodToDetect);
          BarTime.Add(PeriodToDetect, CurrentBarDateTime);
          
          return true;
        }        
      }
      
      return false;
    }
    
    // Return true if new bar avaliable on any timeframe.
    // CArrayInt contains array of ENUM_TIMEFRAMES with new bar.
    bool CheckNewBarAvaliable(CArrayInt &Periods)
    {
      ENUM_TIMEFRAMES Keys[];
      datetime Values[];
      
      BarTime.CopyTo(Keys, Values); 
      for (int i = 0; i < BarTime.Count(); i++)
        if (CheckNewBarAvaliable(Keys[i]))
        {
          Periods.Add(Keys[i]);
        }
         
       return Periods.Total() > 0;
    }  
    
    // Checks is timeframes monitored or not?
    bool IsTimeFrameMonitored(ENUM_TIMEFRAMES aPeriodToDetect)
    {
      datetime dt;
      if (BarTime.TryGetValue(aPeriodToDetect, dt))
        return true;
        
      return false;      
    }
    
    // Return last bar datetime by dataframe 
    datetime GetBarDateTime(ENUM_TIMEFRAMES PeriodToDetect)
    {
      datetime dt;
      if (BarTime.TryGetValue(PeriodToDetect, dt))
        return dt;
        
      return 0;
    }
    
    void ResetLastBarTime(ENUM_TIMEFRAMES PeriodToDetect)
    {
      datetime dt;
      if (BarTime.TryGetValue(PeriodToDetect, dt))
      {
        BarTime.Remove(PeriodToDetect);
        BarTime.Add(PeriodToDetect, 0);
      }
    }    
    
    void ResetAllLastBarTime()
    {
      ENUM_TIMEFRAMES Keys[];
      datetime Values[];
      
      BarTime.CopyTo(Keys, Values); 
      for (int i = 0; i < BarTime.Count(); i++)
        ResetLastBarTime(Keys[i]);
    }
};