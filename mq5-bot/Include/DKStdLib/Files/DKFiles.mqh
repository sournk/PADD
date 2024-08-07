//+------------------------------------------------------------------+
//|                                                      DKFiles.mqh |
//|                                              http://kislitsyn.me |
//+------------------------------------------------------------------+
#property copyright "Denis Kislitsyn"
#property link      "http://kislitsyn.me"
#property version   "0.0.1"
#property description "The library provides simple functions for file operations"
#property strict

#import "kernel32.dll"
   int CreateFileW(string, uint, int, int, int, int, int);
   int GetFileTime (int handle, int& lpCreationTime[], int& lpLastAccessTime[], int& lpLastWriteTime[]);
   bool FileTimeToSystemTime(int& lpFileTime[], int& lpSystemTime[]);
   int CloseHandle(int);
#import

long GetFileProperty(const string filename, const ENUM_FILE_PROPERTY_INTEGER prop_id, const int flags = FILE_READ|FILE_CSV ) {
  long res = 0;
  
  ResetLastError(); 
  int handle = FileOpen(filename, flags); 
  if(handle != INVALID_HANDLE) {
    res = FileGetInteger(handle, prop_id);
    FileClose(handle); 
  }
  
  return res;
}  

//+------------------------------------------------------------------+
//| Returns time attr of the file
//|   WhatTime: 1: lpCreationTime 2: lpLastAccessTime 3: lpLastWriteTime 
//+------------------------------------------------------------------+
datetime GetFileTimeToStrAPI(string filename, int WhatTime) {
  MqlDateTime dt;
  int handle = CreateFileW(filename, 0x80000000 /* GENERIC_READ */, 0, 0, 3 /* OPEN_EXISTING */, 0, 0); 
  
  if (handle != -1) {
    int lpCreationTime[2]; int lpLastAccessTime[2]; int lpLastWriteTime[2];
    if (GetFileTime (handle, lpCreationTime, lpLastAccessTime, lpLastWriteTime)) {
      int FileTimeInlpSystemTime[4];
      int lpTime[2];
      string WhatTimeStr;
      switch (WhatTime) { 
      case 1: lpTime[0]=lpCreationTime[0]; lpTime[1]=lpCreationTime[1]; WhatTimeStr="CreationTime"; break;
      case 2: lpTime[0]=lpLastAccessTime[0]; lpTime[1]=lpLastAccessTime[1]; WhatTimeStr="LastAccessTime"; break;
      case 3: lpTime[0]=lpLastWriteTime[0];  lpTime[1]=lpLastWriteTime[1]; WhatTimeStr="LastWriteTime"; break;
      }
      FileTimeToSystemTime(lpTime, FileTimeInlpSystemTime);

      dt.year = FileTimeInlpSystemTime[0]&0x0000FFFF;
      dt.mon  = FileTimeInlpSystemTime[0]>>16;
      dt.day  = FileTimeInlpSystemTime[1]>>16;
      dt.hour = FileTimeInlpSystemTime[2]&0x0000FFFF;
      dt.min  = FileTimeInlpSystemTime[2]>>16;
      dt.sec  = FileTimeInlpSystemTime[3]&0x0000FFFF;
    }
    CloseHandle(handle);   
  }
  
  return(StructToTime(dt));

//   string time_string = "";
//   
//   int handle = CreateFileW(filename, 0x80000000 /* GENERIC_READ */, 0, 0, 3 /* OPEN_EXISTING */, 0, 0); 
//   
//   if (handle == -1) {
//      // Failed to open file 
//
//   } else {
//      int lpCreationTime[2]; int lpLastAccessTime[2]; int lpLastWriteTime[2];
//      if (!GetFileTime (handle, lpCreationTime, lpLastAccessTime, lpLastWriteTime)) {
//         // Failed to get file-time
//
//      } else {
//         int FileTimeInlpSystemTime[4];
//         int lpTime[2];
//         string WhatTimeStr;
//         switch (WhatTime)
//         { 
//          case 1: lpTime[0]=lpCreationTime[0]; lpTime[1]=lpCreationTime[1]; WhatTimeStr="CreationTime"; break;
//          case 2: lpTime[0]=lpLastAccessTime[0]; lpTime[1]=lpLastAccessTime[1]; WhatTimeStr="LastAccessTime"; break;
//          case 3: lpTime[0]=lpLastWriteTime[0];  lpTime[1]=lpLastWriteTime[1]; WhatTimeStr="LastWriteTime"; break;
//         }
//         FileTimeToSystemTime(lpTime, FileTimeInlpSystemTime);
//            
//            
//         int nYear=FileTimeInlpSystemTime[0]&0x0000FFFF;
//         int nMonth=FileTimeInlpSystemTime[0]>>16;
//         int nDay=FileTimeInlpSystemTime[1]>>16;
//         int nHour=FileTimeInlpSystemTime[2]&0x0000FFFF;
//         int nMin=FileTimeInlpSystemTime[2]>>16;
//         int nSec=FileTimeInlpSystemTime[3]&0x0000FFFF;
//            
//         time_string=TimeToString(TimeCurrent());
//      }
//      CloseHandle(handle);   
//   }
//
//   return(StringToTime(time_string));
}
 