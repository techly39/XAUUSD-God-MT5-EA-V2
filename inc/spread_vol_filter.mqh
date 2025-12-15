//+------------------------------------------------------------------+
//|                                            spread_vol_filter.mqh |
//|                                         XAUUSD-GOD EA Project    |
//|                            Enhanced Pre-Trade Gate Functions     |
//+------------------------------------------------------------------+
#ifndef INC_SPREAD_VOL_FILTER_MQH
#define INC_SPREAD_VOL_FILTER_MQH

#include "filters.mqh"
#include "utils.mqh"
#include "config_inputs.mqh"

// External reference to global pause timer declared in main EA
extern datetime g_noTradeUntil;

// Global pause timers for edge-case protections (file-scoped, internal to this module)
static datetime g_spreadSpikeUntil = 0;    // Spread spike pause (10min)
static datetime g_flashCrashUntil = 0;     // Flash crash pause (30min)

//+------------------------------------------------------------------+
//| Enhanced gate: Check if trading is allowed right now             |
//| Returns false if ANY condition fails (conservative approach)     |
//+------------------------------------------------------------------+
bool CanTradeNow(const string symbol, const datetime server_time)
{
   // Static variables for spread spike tracking
   static double spread_history[];
   static int spread_index = 0;
   static datetime last_spread_update = 0;
   static bool first_run = true;

   // Initialize spread history array on first call
   if(first_run)
   {
      int array_size = (SpreadSpike_MinSamples > 0 && SpreadSpike_MinSamples <= 60) ? SpreadSpike_MinSamples : 30;
      ArrayResize(spread_history, array_size);
      ArrayInitialize(spread_history, 0.0);
      first_run = false;
   }
   
   // Use existing filter functions
   if(!SpreadOK(symbol))
      return false;
   
   if(!ATRSane())
      return false;
   
   if(!DayAllowed(server_time))
      return false;
   
   // 4. SESSION TIMING CHECK
   if(Use_Session_Filter)
   {
      MqlDateTime dt;
      TimeToStruct(server_time, dt);
      
      // Check if within daily session hours
      if(dt.hour < Session_Start_Hour || dt.hour >= Session_End_Hour)
         return false;
      
      // Friday early close check
      if(dt.day_of_week == 5)
      {
         // Parse Friday_CloseTime (format "HH:MM")
         if(StringLen(Friday_CloseTime) == 5)
         {
            string hh_str = StringSubstr(Friday_CloseTime, 0, 2);
            string mm_str = StringSubstr(Friday_CloseTime, 3, 2);
            
            int close_hour = (int)StringToInteger(hh_str);
            int close_min = (int)StringToInteger(mm_str);
            
            if(close_hour >= 0 && close_hour <= 23 && close_min >= 0 && close_min <= 59)
            {
               // Block if at or past Friday close time
               if(dt.hour > close_hour || (dt.hour == close_hour && dt.min >= close_min))
                  return false;
            }
         }
      }
   }
   
   // 5. MARGIN LEVEL CHECK
   double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(margin_level > 0.0 && margin_level < 10000.0)
   {
      if(margin_level < 200.0)
         return false;
   }
   
   // 6. CONSECUTIVE LOSS PAUSE CHECK (2 hours)
   // g_noTradeUntil is set by main EA when loss streak threshold is reached
   if(g_noTradeUntil > TimeCurrent())
      return false;
   
   // 7. SPREAD SPIKE PROTECTION (10 minutes pause)
   // Track spread MA over 60 seconds, pause if current spread ≥3x moving average
   MqlTick tick_check;
   if(SymbolInfoTick(symbol, tick_check))
   {
      double point_val = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point_val > 0.0)
      {
         double current_spread_pts = (tick_check.ask - tick_check.bid) / point_val;
         datetime current_time = TimeCurrent();
         
         // Update spread history every second (not per bar)
         if(current_time - last_spread_update >= 1)
         {
            spread_history[spread_index] = current_spread_pts;
            spread_index = (spread_index + 1) % ArraySize(spread_history);
            last_spread_update = current_time;
         }

         // Calculate moving average based on configured window size
         double spread_sum = 0.0;
         int valid_count = 0;
         for(int i = 0; i < ArraySize(spread_history); i++)
         {
            if(spread_history[i] > 0.0)
            {
               spread_sum += spread_history[i];
               valid_count++;
            }
         }
         
         // Check for 3x spike
         if(valid_count > 0)
         {
            double spread_ma = spread_sum / valid_count;
            if(current_spread_pts >= (spread_ma * SpreadSpike_Multiplier))
            {
               g_spreadSpikeUntil = TimeCurrent() + (SpreadSpike_Pause_Minutes * 60); // 10 minutes
            }
         }
      }
   }
   
   // Block trading if in spread spike pause
   if(g_spreadSpikeUntil > TimeCurrent())
      return false;
   
   // 8. FLASH CRASH PROTECTION (30 minutes pause)
   // Pause if M1 candle range exceeds 500 pips ($5.00)
   double m1_high = iHigh(symbol, PERIOD_M1, 1);
   double m1_low = iLow(symbol, PERIOD_M1, 1);
   
   if(m1_high > 0.0 && m1_low > 0.0 && m1_high != EMPTY_VALUE && m1_low != EMPTY_VALUE)
   {
      double point_val = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point_val > 0.0)
      {
         double m1_range_pts = (m1_high - m1_low) / point_val;
         // 500 pips = 5000 points for 5-digit XAUUSD ($5.00 range)
         if(m1_range_pts >= (FlashCrash_Threshold_Pips * 10.0))
         {
            g_flashCrashUntil = TimeCurrent() + (FlashCrash_Pause_Minutes * 60); // 30 minutes
         }
      }
   }
   
   // Block trading if in flash crash pause
   if(g_flashCrashUntil > TimeCurrent())
      return false;
   
   return true;
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
