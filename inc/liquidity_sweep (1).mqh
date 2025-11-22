//+------------------------------------------------------------------+
//|                                             liquidity_sweep.mqh |
//|                                          XAUUSD-GOD EA - Part F |
//|                                    Range Liquidity Sweep Signal  |
//+------------------------------------------------------------------+
#ifndef INC_LIQUIDITY_SWEEP_MQH
#define INC_LIQUIDITY_SWEEP_MQH

#include "types.mqh"
#include "config_inputs.mqh"
#include "constants.mqh"
#include "range_detector.mqh"
#include "indicators.mqh"
#include "filters.mqh"
#include "logging.mqh"

//+------------------------------------------------------------------+
//| ScanAndSignal_LiquiditySweep                                     |
//| Scans for liquidity sweep reversal entries in range              |
//| Returns Signal with market entry at close, SL, TP                |
//+------------------------------------------------------------------+
Signal ScanAndSignal_LiquiditySweep()
{
   Signal sig;
   sig.valid = false;
   sig.dir = DIR_NONE;
   sig.entry = 0.0;
   sig.sl = 0.0;
   sig.tp = 0.0;
   sig.reason = "";

   // 1) Build range box from closed bars
   double box_high = 0.0, box_low = 0.0;
   if(!BuildRangeBox(Range_Lookback_Bars, box_high, box_low))
   {
      LogEvent("LIQ", "No valid range box");
      return sig;
   }
   
   double box_width = box_high - box_low;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return sig;
   
   LogEvent("LIQ", "Range found: " + DoubleToString(box_high, 5) + " - " + DoubleToString(box_low, 5) + 
            " Width=" + DoubleToString(box_width/point, 1) + "pts");

   // 2) Check last CLOSED bar for sweep
   double h1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double l1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double c1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   if(h1 == 0.0 || h1 == EMPTY_VALUE || l1 == 0.0 || l1 == EMPTY_VALUE ||
      c1 == 0.0 || c1 == EMPTY_VALUE)
   {
      LogEvent("LIQ", "Invalid bar data");
      return sig;
   }

   double sweep_buffer = Sweep_Buffer_Points * point;
   bool is_high_sweep = (h1 > box_high + sweep_buffer) && (c1 < box_high);
   bool is_low_sweep = (l1 < box_low - sweep_buffer) && (c1 > box_low);

   if(!is_high_sweep && !is_low_sweep)
   {
      LogEvent("LIQ", "No sweep detected H=" + DoubleToString(h1, 5) + " L=" + DoubleToString(l1, 5));
      return sig;
   }

   Direction dir = DIR_NONE;
   if(is_high_sweep) dir = DIR_SHORT;
   if(is_low_sweep) dir = DIR_LONG;

   LogEvent("LIQ", "Sweep detected: " + (dir == DIR_LONG ? "LONG" : "SHORT"));

   // 3) Confirm re-entry bars
   if(Sweep_Reentry_Confirm_Bars > 0)
   {
      int confirm_bars = 0;
      for(int i = 1; i <= Sweep_Reentry_Confirm_Bars; i++)
      {
         double c = iClose(_Symbol, PERIOD_CURRENT, i);
         if(c == 0.0 || c == EMPTY_VALUE) return sig;
         
         if(dir == DIR_LONG && c > box_low) confirm_bars++;
         if(dir == DIR_SHORT && c < box_high) confirm_bars++;
      }
      
      if(confirm_bars < Sweep_Reentry_Confirm_Bars)
      {
         LogEvent("LIQ", "Confirm fail: " + IntegerToString(confirm_bars) + "/" + IntegerToString(Sweep_Reentry_Confirm_Bars));
         return sig;
      }
   }

   // 4) RSI confirmation
   if(Sweep_Use_RSI_Confirm)
   {
      if(!RSIConfirm(dir))
      {
         double rsi_val = RSI(1);
         LogEvent("LIQ", "RSI fail: " + DoubleToString(rsi_val, 2) + 
                  " Need: " + (dir == DIR_LONG ? "<" + IntegerToString(RSI_Buy_Threshold) : ">" + IntegerToString(RSI_Sell_Threshold)));
         return sig;
      }
   }

   // 5) ATR-based SL
   double atr1 = ATR(1);
   if(atr1 == EMPTY_VALUE || atr1 <= 0.0)
   {
      LogEvent("LIQ", "Invalid ATR");
      return sig;
   }
   
   double atr_points = atr1 / point;
   int sl_points = (int)MathRound(ATR_Mult_SL_Range * atr_points);
   sl_points = (int)MathMax((double)MIN_SL_POINTS, (double)sl_points);
   double sl_price_dist = sl_points * point;

   LogEvent("LIQ", "ATR=" + DoubleToString(atr1, 2) + " SL_pts=" + IntegerToString(sl_points));

   // 6) Build signal (market order)
   if(dir == DIR_LONG)
   {
      double entry = c1;  // Use last close as reference
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
      sig.reason = REASON_LIQ_SWEEP;
      
      LogEvent("LIQ", "✅ LONG signal: Entry=" + DoubleToString(entry, 5) + " SL=" + DoubleToString(sl, 5) + " TP=" + DoubleToString(tp, 5));
      return sig;
   }
   else if(dir == DIR_SHORT)
   {
      double entry = c1;  // Use last close as reference
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
      sig.reason = REASON_LIQ_SWEEP;
      
      LogEvent("LIQ", "✅ SHORT signal: Entry=" + DoubleToString(entry, 5) + " SL=" + DoubleToString(sl, 5) + " TP=" + DoubleToString(tp, 5));
      return sig;
   }

   return sig;
}

#endif // INC_LIQUIDITY_SWEEP_MQH
