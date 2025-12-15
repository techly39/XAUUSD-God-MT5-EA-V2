//+------------------------------------------------------------------+
//|                                                      filters.mqh |
//|                                         XAUUSD-GOD EA Project    |
//|                                      Reusable filter functions   |
//+------------------------------------------------------------------+
#ifndef INC_FILTERS_MQH
#define INC_FILTERS_MQH

#include "types.mqh"
#include "config_inputs.mqh"
#include "indicators.mqh"
#include "utils.mqh"

//+------------------------------------------------------------------+
//| Check if spread is acceptable                                     |
//+------------------------------------------------------------------+
bool SpreadOK(const string symbol)
{
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return false;
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   
   double spread_points = (tick.ask - tick.bid) / point;
   
   if(Max_Spread_Points <= 0)
      return true;
   
   return (spread_points <= Max_Spread_Points);
}

//+------------------------------------------------------------------+
//| Check if ATR is within acceptable range                          |
//+------------------------------------------------------------------+
bool ATRSane()
{
   if(Min_ATR_Points <= 0.0)
      return true;
   
   double a = ATR(1);
   if(a == EMPTY_VALUE)
      return false;
   
   return (a >= Min_ATR_Points);
}

//+------------------------------------------------------------------+
//| Check if current day is allowed for trading                      |
//+------------------------------------------------------------------+
bool DayAllowed(const datetime server_time)
{
   MqlDateTime dt;
   TimeToStruct(server_time, dt);
   
   switch(dt.day_of_week)
   {
      case 1: return Trading_Day_Mon;
      case 2: return Trading_Day_Tue;
      case 3: return Trading_Day_Wed;
      case 4: return Trading_Day_Thu;
      case 5: return Trading_Day_Fri;
      default: return false;
   }
}

//+------------------------------------------------------------------+
//| RSI confirmation for direction                                    |
//+------------------------------------------------------------------+
bool RSIConfirm(const Direction d)
{
   double r = RSI(1);
   if(r == EMPTY_VALUE)
      return false;
   
   if(d == DIR_LONG)
   {
      if(RSI_Buy_Threshold <= 0.0)
         return true;
      return (r <= RSI_Buy_Threshold);
   }
   else if(d == DIR_SHORT)
   {
      if(RSI_Sell_Threshold <= 0.0)
         return true;
      return (r >= RSI_Sell_Threshold);
   }
   
   return false;
}

#endif // INC_FILTERS_MQH
