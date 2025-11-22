//+------------------------------------------------------------------+
//|                                               risk_debug.mqh     |
//|                                    DIAGNOSTIC VERSION WITH LOGS  |
//+------------------------------------------------------------------+
#ifndef INC_RISK_MQH
#define INC_RISK_MQH

#include "config_inputs.mqh"
#include "types.mqh"

bool SymbolVolumeSpecs(double &min_vol, double &max_vol, double &lot_step)
{
   min_vol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   max_vol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   Print("[RISK] Volume specs: Min=", min_vol, " Max=", max_vol, " Step=", lot_step);
   
   if(min_vol <= 0.0 || max_vol <= 0.0 || lot_step <= 0.0)
   {
      Print("[RISK] ❌ Invalid volume specs");
      return false;
   }
   
   return true;
}

bool PointValuePerLot(const string symbol, double &value_per_point)
{
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point      = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(tick_value <= 0.0 || tick_size <= 0.0 || point <= 0.0)
   {
      Print("[RISK] ❌ Invalid tick specs: TickVal=", tick_value, " TickSize=", tick_size, " Point=", point);
      return false;
   }
   
   value_per_point = tick_value * (point / tick_size);
   Print("[RISK] Point value per lot: ", value_per_point);
   return true;
}

double ComputeLot(const double entry_price, const double sl_price)
{
   Print("[RISK] === ComputeLot Called ===");
   Print("[RISK] Entry=", entry_price, " SL=", sl_price);
   Print("[RISK] Risk_Mode=", Risk_Mode, " Fixed_Lot=", Fixed_Lot, " Risk_Percent=", Risk_Percent);
   
   double min_vol, max_vol, lot_step;
   if(!SymbolVolumeSpecs(min_vol, max_vol, lot_step))
   {
      Print("[RISK] ❌ SymbolVolumeSpecs failed");
      return 0.0;
   }
   
   double lot = 0.0;
   
   if(Risk_Mode == 0)
   {
      lot = Fixed_Lot;
      Print("[RISK] Fixed lot mode: lot=", lot);
   }
   else
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity <= 0.0 || Risk_Percent <= 0.0)
      {
         Print("[RISK] ❌ Invalid equity or risk percent: Equity=", equity, " Risk%=", Risk_Percent);
         return 0.0;
      }
      
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0)
      {
         Print("[RISK] ❌ Invalid point: ", point);
         return 0.0;
      }
      
      double distance_points = MathAbs(entry_price - sl_price) / point;
      Print("[RISK] Distance in points: ", distance_points);
      
      if(distance_points < 1.0)
      {
         Print("[RISK] ❌ Distance too small: ", distance_points);
         return 0.0;
      }
      
      double value_per_point;
      if(!PointValuePerLot(_Symbol, value_per_point))
      {
         Print("[RISK] ❌ PointValuePerLot failed");
         return 0.0;
      }
      if(value_per_point <= 0.0)
      {
         Print("[RISK] ❌ Invalid value per point: ", value_per_point);
         return 0.0;
      }
      
      double money_risk = equity * (Risk_Percent / 100.0);
      Print("[RISK] Money at risk: $", money_risk);
      
      double lot_raw = money_risk / (distance_points * value_per_point);
      Print("[RISK] Raw lot calculated: ", lot_raw);
      lot = lot_raw;
   }
   
   Print("[RISK] Before bounds check: lot=", lot);
   
   if(lot < min_vol)
   {
      Print("[RISK] ❌ Lot ", lot, " below minimum ", min_vol, " - RETURNING 0");
      return 0.0;
   }
   if(lot > max_vol)
   {
      Print("[RISK] ⚠️ Lot ", lot, " above maximum ", max_vol, " - capping to max");
      lot = max_vol;
   }
   
   // Normalize to lot step
   double normalized = MathFloor((lot - min_vol) / lot_step) * lot_step + min_vol;
   Print("[RISK] After normalization: ", normalized);
   
   lot = NormalizeDouble(normalized, 2);
   Print("[RISK] ✅ Final lot: ", lot);
   
   return lot;
}

#endif // INC_RISK_MQH
