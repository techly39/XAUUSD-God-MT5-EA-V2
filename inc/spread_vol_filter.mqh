//+------------------------------------------------------------------+
//|                                            spread_vol_filter.mqh |
//|                                         XAUUSD-GOD EA Project    |
//|                                   Top-level gate functions       |
//+------------------------------------------------------------------+
#ifndef INC_SPREAD_VOL_FILTER_MQH
#define INC_SPREAD_VOL_FILTER_MQH

#include "filters.mqh"
#include "utils.mqh"

//+------------------------------------------------------------------+
//| Check if trading is allowed right now                            |
//+------------------------------------------------------------------+
bool CanTradeNow(const string symbol, const datetime server_time)
{
   return (SpreadOK(symbol) && ATRSane() && DayAllowed(server_time));
}

//+------------------------------------------------------------------+
//| New bar guard wrapper                                             |
//+------------------------------------------------------------------+
bool NewBarGuard(const ENUM_TIMEFRAMES tf, datetime &last_bar_time)
{
   if(!Only_New_Bar)
      return true;
   
   return IsNewBar(tf, last_bar_time);
}

#endif // INC_SPREAD_VOL_FILTER_MQH