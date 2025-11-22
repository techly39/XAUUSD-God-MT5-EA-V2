#ifndef INC_TRADE_MANAGER_MQH
#define INC_TRADE_MANAGER_MQH

#include "types.mqh"
#include "config_inputs.mqh"
#include "constants.mqh"
#include "indicators.mqh"
#include "risk.mqh"
#include "logging.mqh"
#include "orders.mqh"
#include <Trade/Trade.mqh>

int    g_dd_day          = -1;
double g_dd_start_equity = 0.0;
double g_dd_peak_equity  = 0.0;

CTrade g_mgr_trade;
bool   g_mgr_trade_init = false;

void EnsureMgrTradeInit()
{
   if(!g_mgr_trade_init)
   {
      g_mgr_trade.SetExpertMagicNumber(MAGIC_BASE + Magic_Offset);
      g_mgr_trade.SetDeviationInPoints(Max_Slippage_Points);
      g_mgr_trade_init = true;
   }
}

double PointV()
{
   return SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}

bool NewServerDay(datetime tv)
{
   MqlDateTime dt; 
   TimeToStruct(tv, dt);
   return (g_dd_day != dt.day);
}

void DD_Reset(datetime tv)
{
   MqlDateTime dt;
   TimeToStruct(tv, dt);
   g_dd_day = dt.day;
   g_dd_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dd_peak_equity  = g_dd_start_equity;
}

void DD_UpdateInternal(datetime tv)
{
   if(NewServerDay(tv) || g_dd_day < 0) 
      DD_Reset(tv);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_dd_peak_equity) 
      g_dd_peak_equity = eq;
}

double DD_CurrentPercent()
{
   if(g_dd_peak_equity <= 0.0) 
      return 0.0;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd = (g_dd_peak_equity - eq) / g_dd_peak_equity * 100.0;
   if(dd < 0.0) 
      dd = 0.0;
   return dd;
}

bool ApplyBreakEven(ulong ticket, long pos_type, double entry_price, double ref_price, double cur_sl)
{
   if(Move_BE_After_Points <= 0) 
      return false;
   double point = PointV();
   double profit_pts = (pos_type == POSITION_TYPE_BUY) ? (ref_price - entry_price)/point : (entry_price - ref_price)/point;
   if(profit_pts < Move_BE_After_Points) 
      return false;

   double new_sl = cur_sl;
   if(pos_type == POSITION_TYPE_BUY)
   {
      double be = entry_price;
      if(cur_sl <= 0.0 || cur_sl < be) 
         new_sl = be;
   }
   else
   {
      double be = entry_price;
      if(cur_sl <= 0.0 || cur_sl > be) 
         new_sl = be;
   }
   if(new_sl == cur_sl) 
      return false;

   return ModifySLTP(ticket, new_sl, PositionGetDouble(POSITION_TP));
}

bool ApplyTrailing(ulong ticket, long pos_type, double ref_price, double cur_sl)
{
   if(Trail_Mode == 0) 
      return false;

   double point = PointV();
   double start_pts = (double)Trail_Start_Points;
   if(start_pts <= 0.0) 
      start_pts = 0.0;

   double desired_sl = cur_sl;
   if(Trail_Mode == 1)
   {
      if(Trail_Step_Points <= 0) 
         return false;
      if(pos_type == POSITION_TYPE_BUY)
      {
         double candidate = ref_price - (Trail_Step_Points * point);
         if(cur_sl <= 0.0 || candidate > cur_sl) 
            desired_sl = candidate;
      }
      else
      {
         double candidate = ref_price + (Trail_Step_Points * point);
         if(cur_sl <= 0.0 || candidate < cur_sl) 
            desired_sl = candidate;
      }
   }
   else if(Trail_Mode == 2)
   {
      double atr = ATR(1);
      if(atr == EMPTY_VALUE || Trail_ATR_Mult <= 0.0) 
         return false;
      double dist = Trail_ATR_Mult * atr;
      if(pos_type == POSITION_TYPE_BUY)
      {
         double candidate = ref_price - dist;
         if(cur_sl <= 0.0 || candidate > cur_sl) 
            desired_sl = candidate;
      }
      else
      {
         double candidate = ref_price + dist;
         if(cur_sl <= 0.0 || candidate < cur_sl) 
            desired_sl = candidate;
      }
   }

   if(desired_sl == cur_sl) 
      return false;

   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double profit_pts = (pos_type == POSITION_TYPE_BUY) ? (ref_price - entry)/point : (entry - ref_price)/point;
   if(start_pts > 0.0 && profit_pts < start_pts) 
      return false;

   return ModifySLTP(ticket, desired_sl, PositionGetDouble(POSITION_TP));
}

bool ApplyPartial(string symbol, ulong ticket, long pos_type, double entry_price, double ref_price)
{
   if(!Use_Partials) 
      return false;
   if(Partial1_Ratio <= 0.0 || Partial1_Ratio >= 1.0) 
      return false;
   if(Partial1_Target_Points <= 0) 
      return false;

   double point = PointV();
   double profit_pts = (pos_type == POSITION_TYPE_BUY) ? (ref_price - entry_price)/point : (entry_price - ref_price)/point;
   if(profit_pts < Partial1_Target_Points) 
      return false;

   double pos_vol = PositionGetDouble(POSITION_VOLUME);
   double min_vol, max_vol, lot_step;
   if(!SymbolVolumeSpecs(min_vol, max_vol, lot_step)) 
      return false;

   double target_vol = pos_vol * (1.0 - Partial1_Ratio);
   double snapped_target = MathFloor((target_vol - min_vol)/lot_step) * lot_step + min_vol;
   snapped_target = NormalizeDouble(snapped_target, 2);
   if(snapped_target < min_vol) 
      snapped_target = min_vol;

   double to_close = pos_vol - snapped_target;
   if(to_close <= 0.0) 
      return false;

   EnsureMgrTradeInit();
   bool ok = g_mgr_trade.PositionClosePartial(symbol, to_close);
   if(!ok) 
   { 
      LogError("TM", "partial close fail", GetLastError()); 
      return false; 
   }
   LogEvent("TM", "partial close ok vol=" + DoubleToString(to_close, 2));
   return true;
}

void TM_DD_Update(datetime tv)
{
   DD_UpdateInternal(tv);
}

bool TM_DD_GateOK()
{
   if(Max_Daily_Drawdown_Percent <= 0.0) 
      return true;
   double dd = DD_CurrentPercent();
   return (dd < Max_Daily_Drawdown_Percent);
}

bool TM_ManageOpenPositions()
{
   bool changed = false;
   MqlTick tick; 
   if(!SymbolInfoTick(_Symbol, tick)) 
      return false;

   int total = PositionsTotal();
   int lp = total - 1;
   while(lp >= 0)
   {
      ulong ticket = PositionGetTicket(lp);
      if(ticket > 0)
      {
         if(!PositionSelectByTicket(ticket)) continue;
         string sym = PositionGetString(POSITION_SYMBOL);
         if(sym == _Symbol)
         {
            long magic = PositionGetInteger(POSITION_MAGIC);
            if(magic == (MAGIC_BASE + Magic_Offset))
            {
               ulong  ticket   = (ulong)PositionGetInteger(POSITION_TICKET);
               long   pos_type = PositionGetInteger(POSITION_TYPE);
               double entry    = PositionGetDouble(POSITION_PRICE_OPEN);
               double cur_sl   = PositionGetDouble(POSITION_SL);
               double ref      = (pos_type == POSITION_TYPE_BUY) ? tick.ask : tick.bid;

               if(ApplyBreakEven(ticket, pos_type, entry, ref, cur_sl)) 
                  changed = true;

               cur_sl = PositionGetDouble(POSITION_SL);

               if(ApplyTrailing(ticket, pos_type, ref, cur_sl)) 
                  changed = true;

               if(ApplyPartial(sym, ticket, pos_type, entry, ref)) 
                  changed = true;
            }
         }
      }
      lp--;
   }
   return changed;
}

#endif // INC_TRADE_MANAGER_MQH