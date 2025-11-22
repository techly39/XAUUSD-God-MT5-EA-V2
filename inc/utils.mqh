//+------------------------------------------------------------------+
//|                                                        utils.mqh |
//|                                          XAUUSD-GOD EA Utilities |
//+------------------------------------------------------------------+
#ifndef INC_UTILS_MQH
#define INC_UTILS_MQH

//+------------------------------------------------------------------+
//| Symbol precision helpers                                          |
//+------------------------------------------------------------------+
int DigitsFor(const string symbol)
{
   return (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
}

double PointFor(const string symbol)
{
   return SymbolInfoDouble(symbol, SYMBOL_POINT);
}

double NormalizePrice(const double price, const string symbol)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
}

//+------------------------------------------------------------------+
//| Time helpers                                                      |
//+------------------------------------------------------------------+
bool IsTimeWithin(const string hhmm, const datetime server_time)
{
   if(StringLen(hhmm) != 5 || StringSubstr(hhmm, 2, 1) != ":")
      return false;
   
   string hh_str = StringSubstr(hhmm, 0, 2);
   string mm_str = StringSubstr(hhmm, 3, 2);
   
   int target_hour = (int)StringToInteger(hh_str);
   int target_minute = (int)StringToInteger(mm_str);
   
   if(target_hour < 0 || target_hour > 23 || target_minute < 0 || target_minute > 59)
      return false;
   
   MqlDateTime dt;
   TimeToStruct(server_time, dt);
   
   return (dt.hour == target_hour && dt.min == target_minute);
}

bool IsNewBar(const ENUM_TIMEFRAMES tf, datetime &last_bar_time)
{
   datetime current_bar_time = iTime(Symbol(), tf, 0);
   
   if(current_bar_time == 0)
      return false;
   
   if(last_bar_time == 0)
   {
      last_bar_time = current_bar_time;
      return false;
   }
   
   if(current_bar_time > last_bar_time)
   {
      last_bar_time = current_bar_time;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Market data helper                                                |
//+------------------------------------------------------------------+
bool LatestTick(const string symbol, MqlTick &tick_out)
{
   return SymbolInfoTick(symbol, tick_out);
}

#endif // INC_UTILS_MQH