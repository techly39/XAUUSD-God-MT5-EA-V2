#ifndef INC_ORDERS_MQH
#define INC_ORDERS_MQH

#include <Trade/Trade.mqh>
#include "types.mqh"
#include "config_inputs.mqh"
#include "constants.mqh"
#include "utils.mqh"
#include "risk.mqh"
#include "logging.mqh"

static CTrade g_trade;
static bool   g_trade_init = false;

void EnsureTradeInit()
{
   if(!g_trade_init)
   {
      g_trade.SetExpertMagicNumber(MAGIC_BASE + Magic_Offset);
      g_trade.SetDeviationInPoints(Max_Slippage_Points);
      g_trade_init = true;
   }
}

bool GetStopsLevels(int &stops_level_pts, int &freeze_level_pts)
{
   stops_level_pts  = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   freeze_level_pts = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   return (stops_level_pts >= 0 && freeze_level_pts >= 0);
}

bool NormalizeAllPrices(const string symbol, double &entry, double &sl, double &tp)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(digits <= 0) return false;
   if(entry > 0.0) entry = NormalizeDouble(entry, digits);
   if(sl    > 0.0) sl    = NormalizeDouble(sl,    digits);
   if(tp    > 0.0) tp    = NormalizeDouble(tp,    digits);
   return true;
}

bool CheckDistanceOK(double dist_pts, double min_pts)
{
   return (dist_pts <= 0.0) ? true : (dist_pts >= min_pts);
}

bool RespectMinStopDistance(const string symbol, const double ref_price, const double sl, const double tp, const bool is_buy, const bool is_market)
{
   int stops_level_pts, freeze_pts;
   if(!GetStopsLevels(stops_level_pts, freeze_pts)) return false;
   double point   = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double min_pts = (double)MathMax(MIN_SL_POINTS, stops_level_pts);

   if(sl > 0.0)
   {
      double d = is_buy ? (ref_price - sl)/point : (sl - ref_price)/point;
      if(!CheckDistanceOK(d, min_pts)) return false;
   }
   if(tp > 0.0)
   {
      double d = is_buy ? (tp - ref_price)/point : (ref_price - tp)/point;
      if(!CheckDistanceOK(d, min_pts)) return false;
   }
   return true;
}

string BuildComment(const string reason)
{
   return Order_Comment + "|" + reason;
}

bool ExecuteMarketOrder(const Signal &sig, const double lot, ulong &ticket_out)
{
   EnsureTradeInit();
   ticket_out = 0;
   if(!sig.valid || lot <= 0.0) return false;
   if(!(sig.dir == DIR_LONG || sig.dir == DIR_SHORT)) return false;

   MqlTick t; 
   if(!SymbolInfoTick(_Symbol, t)) 
   { 
      LogError("ORDER","tick fail",GetLastError()); 
      return false; 
   }
   bool is_buy = (sig.dir == DIR_LONG);
   double ref  = is_buy ? t.ask : t.bid;

   double sl = sig.sl, tp = sig.tp, dummy=0.0;
   if(!NormalizeAllPrices(_Symbol, dummy, sl, tp)) return false;
   if(!RespectMinStopDistance(_Symbol, ref, sl, tp, is_buy, true)) return false;

   string cmt = BuildComment(sig.reason);
   bool ok = is_buy ? g_trade.Buy(lot, _Symbol, 0.0, sl, tp, cmt)
                    : g_trade.Sell(lot, _Symbol, 0.0, sl, tp, cmt);
   if(!ok)
   { 
      LogError("ORDER","market send fail",GetLastError()); 
      return false; 
   }

   ulong deal  = g_trade.ResultDeal();
   ulong order = g_trade.ResultOrder();
   ticket_out  = (deal != 0 ? deal : order);
   LogEvent("ORDER","market ok: ticket=" + (string)ticket_out + " " + cmt);
   return (ticket_out != 0);
}

bool ExecutePendingOrder(const Signal &sig, const double lot, const int expiration_min, ulong &ticket_out)
{
   EnsureTradeInit();
   ticket_out = 0;
   if(!sig.valid || lot <= 0.0) return false;
   if(!(sig.dir == DIR_LONG || sig.dir == DIR_SHORT)) return false;
   if(sig.entry <= 0.0) return false;

   double entry = sig.entry, sl = sig.sl, tp = sig.tp;
   if(!NormalizeAllPrices(_Symbol, entry, sl, tp)) return false;

   bool is_buy = (sig.dir == DIR_LONG);
   if(!RespectMinStopDistance(_Symbol, entry, sl, tp, is_buy, false)) return false;

   datetime exp = (expiration_min > 0) ? (TimeCurrent() + expiration_min*60) : 0;
   string   cmt = BuildComment(sig.reason);

   bool ok = is_buy ? g_trade.BuyStop(lot, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, exp, cmt)
                    : g_trade.SellStop(lot, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, exp, cmt);
   if(!ok)
   { 
      LogError("ORDER","pending send fail",GetLastError()); 
      return false; 
   }

   ticket_out = g_trade.ResultOrder();
   LogEvent("ORDER","pending ok: ticket=" + (string)ticket_out + " " + cmt);
   return (ticket_out != 0);
}

bool ModifySLTP(const ulong ticket, const double sl, const double tp)
{
   EnsureTradeInit();

   double sln = sl, tpn = tp, entry_dummy=0.0;
   if(!NormalizeAllPrices(_Symbol, entry_dummy, sln, tpn)) return false;

   if(PositionSelectByTicket(ticket))
   {
      MqlTick t; 
      if(!SymbolInfoTick(_Symbol, t)) return false;
      long  type = PositionGetInteger(POSITION_TYPE);
      bool  is_buy = (type == POSITION_TYPE_BUY);
      double ref   = is_buy ? t.ask : t.bid;
      if(!RespectMinStopDistance(_Symbol, ref, sln, tpn, is_buy, true)) return false;
      bool ok = g_trade.PositionModify(ticket, sln, tpn);
      if(!ok)
      { 
         LogError("ORDER","pos modify fail",GetLastError()); 
         return false; 
      }
      LogEvent("ORDER","pos modify ok: ticket=" + (string)ticket);
      return true;
   }

   if(!OrderSelect(ticket)) return false;
   double price = OrderGetDouble(ORDER_PRICE_OPEN);
   long   type  = (long)OrderGetInteger(ORDER_TYPE);
   bool   is_buy = (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_LIMIT);
   if(!RespectMinStopDistance(_Symbol, price, sln, tpn, is_buy, false)) return false;
   
   datetime exp = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
   ENUM_ORDER_TYPE_TIME type_time = (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);

   bool ok = g_trade.OrderModify(ticket, price, sln, tpn, type_time, exp);
   if(!ok)
   { 
      LogError("ORDER","pend modify fail",GetLastError()); 
      return false; 
   }
   LogEvent("ORDER","pend modify ok: ticket=" + (string)ticket);
   return true;
}

bool CancelPending(const ulong ticket)
{
   EnsureTradeInit();
   if(!OrderSelect(ticket)) return false;
   ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   if(t != ORDER_TYPE_BUY_STOP && t != ORDER_TYPE_SELL_STOP && t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT)
      return false;
   bool ok = g_trade.OrderDelete(ticket);
   if(!ok)
   { 
      LogError("ORDER","delete fail",GetLastError()); 
      return false; 
   }
   LogEvent("ORDER","delete ok: ticket=" + (string)ticket);
   return true;
}

#endif // INC_ORDERS_MQH