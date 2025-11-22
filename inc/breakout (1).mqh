//+------------------------------------------------------------------+
//|                                                     breakout.mqh |
//|                                          XAUUSD-GOD EA - Part G |
//|                                      Trend Breakout Signal Logic |
//+------------------------------------------------------------------+
#ifndef INC_BREAKOUT_MQH
#define INC_BREAKOUT_MQH

#include "types.mqh"
#include "config_inputs.mqh"
#include "constants.mqh"
#include "indicators.mqh"
#include "filters.mqh"
#include "logging.mqh"

//+------------------------------------------------------------------+
//| ScanAndSignal_Breakout                                           |
//| FIXED: Proper breakout detection for CLOSED bars                |
//+------------------------------------------------------------------+
Signal ScanAndSignal_Breakout()
{
   Signal sig;
   sig.valid = false;
   sig.dir = DIR_NONE;
   sig.entry = 0.0;
   sig.sl = 0.0;
   sig.tp = 0.0;
   sig.reason = "";

   // 1) Read last CLOSED bar (index 1)
   double o1 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double h1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double l1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double c1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   if(o1 == 0.0 || o1 == EMPTY_VALUE || h1 == 0.0 || h1 == EMPTY_VALUE ||
      l1 == 0.0 || l1 == EMPTY_VALUE || c1 == 0.0 || c1 == EMPTY_VALUE)
   {
      LogEvent("BO", "Invalid bar data");
      return sig;
   }

   // 2) EMA trend bias
   double ema1 = EMA(1);
   if(ema1 == EMPTY_VALUE)
   {
      LogEvent("BO", "Invalid EMA");
      return sig;
   }
   
   if(c1 == ema1)
   {
      LogEvent("BO", "Close = EMA, no bias");
      return sig;
   }
   
   Direction bias = DIR_NONE;
   if(c1 > ema1)
      bias = DIR_LONG;
   else if(c1 < ema1)
      bias = DIR_SHORT;

   LogEvent("BO", "Bias=" + (bias == DIR_LONG ? "LONG" : "SHORT") + " C=" + DoubleToString(c1, 5) + " EMA=" + DoubleToString(ema1, 5));

   // 3) Determine breakout levels
   if(Breakout_Lookback <= 1)
   {
      LogEvent("BO", "Lookback too small");
      return sig;
   }
   
   int bars_total = Bars(_Symbol, PERIOD_CURRENT);
   if(bars_total <= Breakout_Lookback)
   {
      LogEvent("BO", "Not enough bars");
      return sig;
   }

   double recent_high = -DBL_MAX;
   double recent_low = DBL_MAX;
   
   // CRITICAL FIX: Scan bars [2...Breakout_Lookback+1] to exclude bar 1 (testing bar)
   // If Breakout_Lookback=20, we scan bars 2-21 (20 bars BEFORE the current closed bar)
   for(int i = 2; i <= Breakout_Lookback + 1; i++)
   {
      double hi = iHigh(_Symbol, PERIOD_CURRENT, i);
      double lo = iLow(_Symbol, PERIOD_CURRENT, i);
      
      if(hi == 0.0 || hi == EMPTY_VALUE || lo == 0.0 || lo == EMPTY_VALUE)
      {
         LogEvent("BO", "Invalid data at bar " + IntegerToString(i));
         return sig;
      }
      
      if(hi > recent_high) recent_high = hi;
      if(lo < recent_low) recent_low = lo;
   }
   
   if(recent_high <= recent_low)
   {
      LogEvent("BO", "Invalid range H<L");
      return sig;
   }

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return sig;
   
   double range_width = (recent_high - recent_low) / point;
   LogEvent("BO", "Lookback Range [bars 2-" + IntegerToString(Breakout_Lookback+1) + "]: H=" + 
            DoubleToString(recent_high, 5) + " L=" + DoubleToString(recent_low, 5) + 
            " Width=" + DoubleToString(range_width, 1) + "pts");

   // 4) Check breakout - FIXED LOGIC
   double close_beyond = Breakout_CloseBeyond_Points * point;
   double pending_offset = Pending_Offset_Points * point;

   bool is_long_breakout = false;
   bool is_short_breakout = false;
   
   // LONG BREAKOUT: Close must be ABOVE recent high
   if(bias == DIR_LONG)
   {
      double breakout_level = recent_high + close_beyond;
      if(c1 >= breakout_level)
      {
         is_long_breakout = true;
         LogEvent("BO", "✅ LONG breakout: C=" + DoubleToString(c1, 5) + 
                  " >= H=" + DoubleToString(recent_high, 5) + "+" + 
                  IntegerToString(Breakout_CloseBeyond_Points) + "pts");
      }
      else
      {
         LogEvent("BO", "No LONG breakout: C=" + DoubleToString(c1, 5) + 
                  " < " + DoubleToString(breakout_level, 5) + 
                  " (need >" + DoubleToString(recent_high, 5) + ")");
      }
   }
   // SHORT BREAKOUT: Close must be BELOW recent low
   else if(bias == DIR_SHORT)
   {
      double breakout_level = recent_low - close_beyond;
      if(c1 <= breakout_level)
      {
         is_short_breakout = true;
         LogEvent("BO", "✅ SHORT breakout: C=" + DoubleToString(c1, 5) + 
                  " <= L=" + DoubleToString(recent_low, 5) + "-" + 
                  IntegerToString(Breakout_CloseBeyond_Points) + "pts");
      }
      else
      {
         LogEvent("BO", "No SHORT breakout: C=" + DoubleToString(c1, 5) + 
                  " > " + DoubleToString(breakout_level, 5) + 
                  " (need <" + DoubleToString(recent_low, 5) + ")");
      }
   }
   
   if(!is_long_breakout && !is_short_breakout)
   {
      return sig;
   }

   // 5) ATR-based SL
   double atr1 = ATR(1);
   if(atr1 == EMPTY_VALUE || atr1 <= 0.0)
   {
      LogEvent("BO", "Invalid ATR");
      return sig;
   }
   
   double atr_points = atr1 / point;
   int sl_points = (int)MathRound(ATR_Mult_SL_Trend * atr_points);
   sl_points = (int)MathMax((double)MIN_SL_POINTS, (double)sl_points);
   double sl_price_dist = sl_points * point;

   LogEvent("BO", "ATR=" + DoubleToString(atr1, 2) + " SL_pts=" + IntegerToString(sl_points));

   // 6) Build signal
   if(is_long_breakout)
   {
      double entry = recent_high + pending_offset;
      double sl = entry - sl_price_dist;
      double tp = 0.0;
      
      if(TP_Mode == TP_FIXED && TP_Fixed_Points > 0)
         tp = entry + (TP_Fixed_Points * point);
      else if(TP_Mode == TP_RR && RR_Target > 0.0)
         tp = entry + (RR_Target * sl_points * point);
      
      sig.valid = true;
      sig.dir = DIR_LONG;
      sig.entry = entry;
      sig.sl = sl;
      sig.tp = tp;
      sig.reason = REASON_TREND_BO;
      
      LogEvent("BO", "📈 LONG SIGNAL: Entry=" + DoubleToString(entry, 5) + 
               " SL=" + DoubleToString(sl, 5) + " TP=" + DoubleToString(tp, 5));
      return sig;
   }
   else if(is_short_breakout)
   {
      double entry = recent_low - pending_offset;
      double sl = entry + sl_price_dist;
      double tp = 0.0;
      
      if(TP_Mode == TP_FIXED && TP_Fixed_Points > 0)
         tp = entry - (TP_Fixed_Points * point);
      else if(TP_Mode == TP_RR && RR_Target > 0.0)
         tp = entry - (RR_Target * sl_points * point);
      
      sig.valid = true;
      sig.dir = DIR_SHORT;
      sig.entry = entry;
      sig.sl = sl;
      sig.tp = tp;
      sig.reason = REASON_TREND_BO;
      
      LogEvent("BO", "📉 SHORT SIGNAL: Entry=" + DoubleToString(entry, 5) + 
               " SL=" + DoubleToString(sl, 5) + " TP=" + DoubleToString(tp, 5));
      return sig;
   }

   return sig;
}

#endif // INC_BREAKOUT_MQH
