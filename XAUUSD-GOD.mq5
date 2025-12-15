//+------------------------------------------------------------------+
//|                                                  XAUUSD-GOD.mq5 |
//|                                      XAUUSD Algorithmic Trading |
//|                                                   V2 - M5 SCALPER|
//+------------------------------------------------------------------+
#property copyright "XAUUSD-GOD"
#property link      ""
#property version   "2.00"
#property strict

// Global variables must be declared BEFORE includes that reference them
datetime g_lastBar_M5 = 0;
datetime g_noTradeUntil = 0;

#include <inc/types.mqh>
#include <inc/constants.mqh>
#include <inc/config_inputs.mqh>
#include <inc/utils.mqh>
#include <inc/logging.mqh>
#include <inc/indicators.mqh>
#include <inc/filters.mqh>
#include <inc/spread_vol_filter.mqh>
#include <inc/risk.mqh>
#include <inc/orders.mqh>
#include <inc/trade_manager.mqh>

input group "XAUUSD-GOD V2 Settings"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  LogInit("XAUUSD-GOD-M5-V2");
  const string sym = _Symbol;
  const ENUM_TIMEFRAMES tf = PERIOD_M5;

  if(!InitIndicators(sym, tf))
  {
    LogError("INIT","InitIndicators failed", GetLastError());
    return(INIT_FAILED);
  }

  if(!SymbolInfoInteger(sym, SYMBOL_TRADE_MODE)) 
  { 
    LogError("INIT","Trading not allowed for symbol", GetLastError()); 
  }

  datetime t0 = iTime(sym, PERIOD_M5, 0);
  if(t0 > 0) g_lastBar_M5 = t0;

  g_noTradeUntil = 0;
  EnsureTradeInit();

  LogEvent("INIT","OK - M5 Timeframe - Scalping Mode");
  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  FreeIndicators();
  LogEvent("DEINIT","done");
}

//+------------------------------------------------------------------+
//| Pre-trade gate check                                             |
//+------------------------------------------------------------------+
bool PreTradeGate(const datetime server_time)
{
  if(!TM_DD_GateOK()) return false;
  if(!TM_Week_GateOK()) return false;
  if(g_noTradeUntil > 0 && server_time < g_noTradeUntil) return false;
  if(!CanTradeNow(_Symbol, server_time)) return false;
  
  double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
  if(margin_level > 0.0 && margin_level < 200.0) return false;
  
  return true;
}

//+------------------------------------------------------------------+
//| Build signal based on M5 scalping logic                         |
//+------------------------------------------------------------------+
bool BuildSignal(Signal &out_sig)
{
  out_sig.valid = false; 
  out_sig.dir = DIR_NONE; 
  out_sig.entry = 0.0;
  out_sig.sl = 0.0;
  out_sig.tp = 0.0;
  out_sig.reason = REASON_SCALP;

  double adx = ADX(1);
  double rsi = RSI(1);
  double ema = EMA(1);
  
  if(adx == EMPTY_VALUE || rsi == EMPTY_VALUE || ema == EMPTY_VALUE)
  {
    LogEvent("SIGNAL", "Invalid indicator values");
    return false;
  }

  double c1 = iClose(_Symbol, PERIOD_M5, 1);
  double o1 = iOpen(_Symbol, PERIOD_M5, 1);
  double h1 = iHigh(_Symbol, PERIOD_M5, 1);
  double l1 = iLow(_Symbol, PERIOD_M5, 1);
  double c2 = iClose(_Symbol, PERIOD_M5, 2);
  double h2 = iHigh(_Symbol, PERIOD_M5, 2);
  double l2 = iLow(_Symbol, PERIOD_M5, 2);
  
  if(c1 == 0.0 || c1 == EMPTY_VALUE) return false;

  bool trendMode = (adx >= ADX_Trend_Threshold);
  Direction bias = DIR_NONE;
  
  if(trendMode)
  {
    if(c1 > ema) bias = DIR_LONG;
    else if(c1 < ema) bias = DIR_SHORT;
    
    double ema2 = EMA(2);
    if(ema2 != EMPTY_VALUE)
    {
      if(bias == DIR_LONG && ema < ema2) bias = DIR_NONE;
      if(bias == DIR_SHORT && ema > ema2) bias = DIR_NONE;
    }
  }

  LogEvent("SIGNAL", "ADX=" + DoubleToString(adx, 2) + " Mode=" + (trendMode ? "TREND" : "RANGE") + 
           " RSI=" + DoubleToString(rsi, 2) + " Bias=" + (bias == DIR_LONG ? "LONG" : (bias == DIR_SHORT ? "SHORT" : "NONE")));

  double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point <= 0.0) return false;

  if(trendMode && bias != DIR_NONE)
  {
    if(bias == DIR_LONG && rsi <= RSI_Buy_Threshold)
    {
      bool pullback = (c2 < c1) || (c1 < o1);
      bool reversal = (c1 > o1) && (c1 > h2);
      
      if(pullback && reversal)
      {
        double swing_low = MathMin(l1, l2);
        double sl_buffer = 5 * point;
        double sl_price = swing_low - sl_buffer;
        
        MqlTick tick;
        if(!SymbolInfoTick(_Symbol, tick)) return false;
        
        double entry = tick.ask;
        double sl_dist_pts = (entry - sl_price) / point;
        
        if(sl_dist_pts >= MIN_SL_POINTS)
        {
          double tp_price = entry + (1.5 * (entry - sl_price));
          double tp_dist_pts = (tp_price - entry) / point;
          
          if(tp_dist_pts >= MIN_TP_POINTS)
          {
            out_sig.valid = true;
            out_sig.dir = DIR_LONG;
            out_sig.entry = entry;
            out_sig.sl = sl_price;
            out_sig.tp = tp_price;
            
            LogEvent("SIGNAL", "LONG SCALP: Pullback reversal in uptrend (RSI=" + 
                     DoubleToString(rsi, 2) + " SL=" + DoubleToString(sl_dist_pts, 1) + "pts TP=" + 
                     DoubleToString(tp_dist_pts, 1) + "pts)");
            return true;
          }
        }
      }
    }
    
    if(bias == DIR_SHORT && rsi >= RSI_Sell_Threshold)
    {
      bool pullback = (c2 > c1) || (c1 > o1);
      bool reversal = (c1 < o1) && (c1 < l2);
      
      if(pullback && reversal)
      {
        double swing_high = MathMax(h1, h2);
        double sl_buffer = 5 * point;
        double sl_price = swing_high + sl_buffer;
        
        MqlTick tick;
        if(!SymbolInfoTick(_Symbol, tick)) return false;
        
        double entry = tick.bid;
        double sl_dist_pts = (sl_price - entry) / point;
        
        if(sl_dist_pts >= MIN_SL_POINTS)
        {
          double tp_price = entry - (1.5 * (sl_price - entry));
          double tp_dist_pts = (entry - tp_price) / point;
          
          if(tp_dist_pts >= MIN_TP_POINTS)
          {
            out_sig.valid = true;
            out_sig.dir = DIR_SHORT;
            out_sig.entry = entry;
            out_sig.sl = sl_price;
            out_sig.tp = tp_price;
            
            LogEvent("SIGNAL", "SHORT SCALP: Pullback reversal in downtrend (RSI=" + 
                     DoubleToString(rsi, 2) + " SL=" + DoubleToString(sl_dist_pts, 1) + "pts TP=" + 
                     DoubleToString(tp_dist_pts, 1) + "pts)");
            return true;
          }
        }
      }
    }
  }
  
  if(!trendMode)
  {
    if(rsi <= RSI_Buy_Threshold)
    {
      bool reversal = (c1 > o1) && (c1 > h2);
      
      if(reversal)
      {
        double swing_low = MathMin(l1, l2);
        double sl_buffer = 5 * point;
        double sl_price = swing_low - sl_buffer;
        
        MqlTick tick;
        if(!SymbolInfoTick(_Symbol, tick)) return false;
        
        double entry = tick.ask;
        double sl_dist_pts = (entry - sl_price) / point;
        
        if(sl_dist_pts >= MIN_SL_POINTS)
        {
          double tp_price = entry + (1.5 * (entry - sl_price));
          double tp_dist_pts = (tp_price - entry) / point;
          
          if(tp_dist_pts >= MIN_TP_POINTS)
          {
            out_sig.valid = true;
            out_sig.dir = DIR_LONG;
            out_sig.entry = entry;
            out_sig.sl = sl_price;
            out_sig.tp = tp_price;
            
            LogEvent("SIGNAL", "LONG SCALP: Range reversal from oversold (RSI=" + 
                     DoubleToString(rsi, 2) + " SL=" + DoubleToString(sl_dist_pts, 1) + "pts TP=" + 
                     DoubleToString(tp_dist_pts, 1) + "pts)");
            return true;
          }
        }
      }
    }
    
    if(rsi >= RSI_Sell_Threshold)
    {
      bool reversal = (c1 < o1) && (c1 < l2);
      
      if(reversal)
      {
        double swing_high = MathMax(h1, h2);
        double sl_buffer = 5 * point;
        double sl_price = swing_high + sl_buffer;
        
        MqlTick tick;
        if(!SymbolInfoTick(_Symbol, tick)) return false;
        
        double entry = tick.bid;
        double sl_dist_pts = (sl_price - entry) / point;
        
        if(sl_dist_pts >= MIN_SL_POINTS)
        {
          double tp_price = entry - (1.5 * (sl_price - entry));
          double tp_dist_pts = (entry - tp_price) / point;
          
          if(tp_dist_pts >= MIN_TP_POINTS)
          {
            out_sig.valid = true;
            out_sig.dir = DIR_SHORT;
            out_sig.entry = entry;
            out_sig.sl = sl_price;
            out_sig.tp = tp_price;
            
            LogEvent("SIGNAL", "SHORT SCALP: Range reversal from overbought (RSI=" + 
                     DoubleToString(rsi, 2) + " SL=" + DoubleToString(sl_dist_pts, 1) + "pts TP=" + 
                     DoubleToString(tp_dist_pts, 1) + "pts)");
            return true;
          }
        }
      }
    }
  }

  return false;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  const datetime now = TimeCurrent();

  TM_DD_Update(now);
  TM_ManageOpenPositions();

  if(!PreTradeGate(now))
  {
    return;
  }

  // One Position at a Time check
  int myPositions = 0;
  int total_positions = PositionsTotal();
  int pos_idx = total_positions - 1;

   while(pos_idx >= 0)
   {
      ulong ticket = PositionGetTicket(pos_idx);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MAGIC_BASE + Magic_Offset &&
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            myPositions++;
         }
      }
      pos_idx--;
   }

  if(myPositions > 0)
  {
    return;
  }

  if(!NewBarGuard(PERIOD_M5, g_lastBar_M5))
  {
    return;
  }

  Signal sig;

  if(!BuildSignal(sig) || !sig.valid)
  {
    return;
  }

  if(sig.sl <= 0.0 || sig.sl == EMPTY_VALUE)
  {
    LogError("TRADE", "Invalid SL=" + DoubleToString(sig.sl, 5), 0);
    return;
  }

  MqlTick tick;
  if(!SymbolInfoTick(_Symbol, tick))
  {
    LogEvent("TRADE", "tick fail");
    return;
  }

  double ref_price = (sig.dir == DIR_LONG) ? tick.ask : tick.bid;
  double lot = ComputeLot(ref_price, sig.sl);

  if(lot <= 0.0)
  {
    LogEvent("TRADE","lot=0; skip");
    return;
  }

  ulong ticket = 0;
  bool sent = ExecuteMarketOrder(sig, lot, ticket);

  if(sent)
  {
    LogEvent("TRADE","SENT: ticke t=" + (string)ticket + " reason=" + sig.reason + " lot=" + DoubleToString(lot, 2));
  }
  else
  {
    LogError("TRADE","send failed", GetLastError());
  }
}
//+------------------------------------------------------------------+