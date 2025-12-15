//+------------------------------------------------------------------+
//|                                                         risk.mqh |
//|                                         XAUUSD-GOD Risk Manager  |
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

   if(min_vol <= 0.0 || max_vol <= 0.0 || lot_step <= 0.0)
      return false;

   return true;
}

bool PointValuePerLot(const string symbol, double &value_per_point)
{
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point      = SymbolInfoDouble(symbol, SYMBOL_POINT);

   if(tick_value <= 0.0 || tick_size <= 0.0 || point <= 0.0)
      return false;

   value_per_point = tick_value * (point / tick_size);
   return true;
}

double ComputeLot(const double entry_price, const double sl_price)
{
   double min_vol, max_vol, lot_step;
   if(!SymbolVolumeSpecs(min_vol, max_vol, lot_step))
      return 0.0;

   double lot = 0.0;

   if(Risk_Mode == 0)
   {
      lot = Fixed_Lot;
   }
   else
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity <= 0.0 || Risk_Percent <= 0.0)
         return 0.0;

      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0)
         return 0.0;

      double distance_points = MathAbs(entry_price - sl_price) / point;

      if(distance_points < 1.0)
         return 0.0;

      double value_per_point;
      if(!PointValuePerLot(_Symbol, value_per_point))
         return 0.0;
      if(value_per_point <= 0.0)
         return 0.0;

      double money_risk = equity * (Risk_Percent / 100.0);
      double lot_raw = money_risk / (distance_points * value_per_point);
      lot = lot_raw;
   }

   if(lot < min_vol)
      return 0.0;
   if(lot > max_vol)
      lot = max_vol;

   // Normalize to lot step
   double normalized = MathFloor((lot - min_vol) / lot_step) * lot_step + min_vol;
   lot = NormalizeDouble(normalized, 2);

   return lot;
}

#endif // INC_RISK_MQH
