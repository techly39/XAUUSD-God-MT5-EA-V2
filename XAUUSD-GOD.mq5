//+------------------------------------------------------------------+
//|                                                  XAUUSD-GOD.mq5 |
//|                                      XAUUSD Algorithmic Trading |
//|                                                   FIXED VERSION  |
//+------------------------------------------------------------------+
#property copyright "XAUUSD-GOD"
#property link      ""
#property version   "1.01"
#property strict

#include <inc/types.mqh>
#include <inc/constants.mqh>
#include <inc/config_inputs.mqh>
#include <inc/utils.mqh>
#include <inc/logging.mqh>
#include <inc/indicators.mqh>
#include <inc/regime.mqh>
#include <inc/filters.mqh>
#include <inc/spread_vol_filter.mqh>
#include <inc/range_detector.mqh>
#include <inc/liquidity_sweep.mqh>
#include <inc/breakout.mqh>
#include <inc/risk.mqh>
#include <inc/orders.mqh>
#include <inc/trade_manager.mqh>

input group "XAUUSD-GOD Settings"

datetime g_lastBar_M15 = 0;  // FIXED: Changed from M5 to M15

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  LogInit("XAUUSD-GOD-M15");
  const string sym = _Symbol;
  const ENUM_TIMEFRAMES tf = PERIOD_M15;  // FIXED: Explicitly M15

  if(!InitIndicators(sym, tf))
  {
    LogError("INIT","InitIndicators failed", GetLastError());
    return(INIT_FAILED);
  }

  if(!SymbolInfoInteger(sym, SYMBOL_TRADE_MODE)) 
  { 
    LogError("INIT","Trading not allowed for symbol", GetLastError()); 
  }

  datetime t0 = iTime(sym, PERIOD_M15, 0);  // FIXED: M15
  if(t0 > 0) g_lastBar_M15 = t0;

  LogEvent("INIT","OK - M15 Timeframe");
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
  if(!TM_DD_GateOK())        return false;
  if(!CanTradeNow(_Symbol, server_time)) return false;
  return true;
}

//+------------------------------------------------------------------+
//| Build signal based on regime                                     |
//+------------------------------------------------------------------+
bool BuildSignal(Signal &out_sig)
{
  out_sig.valid = false; 
  out_sig.dir = DIR_NONE; 
  out_sig.entry = 0.0;
  out_sig.sl = 0.0;
  out_sig.tp = 0.0;
  out_sig.reason = "";

  Regime r = DetectRegime();
  LogEvent("SIGNAL", "Regime=" + (r == REGIME_RANGE ? "RANGE" : "TREND"));
  
  if(r == REGIME_RANGE)
  {
    Signal s = ScanAndSignal_LiquiditySweep();
    if(s.valid)
    {
      out_sig = s;
      return true;
    }
    return false;
  }
  else
  {
    Signal s = ScanAndSignal_Breakout();
    if(s.valid)
    {
      out_sig = s;
      return true;
    }
    return false;
  }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  const datetime now = TimeCurrent();

  TM_DD_Update(now);
  TM_ManageOpenPositions();

  if(!NewBarGuard(PERIOD_M15, g_lastBar_M15)) return;  // FIXED: M15

  if(!PreTradeGate(now)) 
  {
    int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    double dd = DD_CurrentPercent();
    double atr_val = ATR(1);
    string reason = "";
    
    if(!TM_DD_GateOK())
      reason += "DD=" + DoubleToString(dd, 2) + "% ";
    
    reason += "Spread=" + IntegerToString(spread);
    if(atr_val != EMPTY_VALUE)
      reason += " ATR=" + DoubleToString(atr_val, 2);
    
    LogEvent("GATE", "Blocked: " + reason);
    return;
  }

  Signal sig;
  
  if(!BuildSignal(sig) || !sig.valid) 
  {
    Regime r = DetectRegime();
    double adx_val = ADX(1);
    string regime_str = (r == REGIME_RANGE ? "RANGE" : "TREND");
    string msg = "No signal - Regime=" + regime_str;
    
    if(adx_val != EMPTY_VALUE)
      msg += " ADX=" + DoubleToString(adx_val, 2);
    
    LogEvent("SIGNAL", msg);
    return;
  }

  MqlTick tick;
  if(!SymbolInfoTick(_Symbol, tick))
  {
    LogEvent("TRADE", "tick fail");
    return;
  }

  double ref_price = (sig.entry > 0.0) ? sig.entry : ((sig.dir == DIR_LONG) ? tick.ask : tick.bid);
  
  if(sig.sl <= 0.0 || sig.sl == EMPTY_VALUE)
  {
    LogError("TRADE", "Invalid SL=" + DoubleToString(sig.sl, 5), 0);
    return;
  }

  double lot = ComputeLot(ref_price, sig.sl);
  if(lot <= 0.0) 
  { 
    LogEvent("TRADE","lot=0; skip"); 
    return; 
  }

  ulong ticket = 0;
  bool sent = false;

  if(sig.reason == REASON_LIQ_SWEEP)
  {
    sent = ExecuteMarketOrder(sig, lot, ticket);
  }
  else if(sig.reason == REASON_TREND_BO)
  {
    sent = ExecutePendingOrder(sig, lot, Order_Expiration_Min, ticket);
  }
  else
  {
    LogEvent("TRADE","unknown reason; skip");
    return;
  }

  if(sent)
    LogEvent("TRADE","✅ SENT: ticket=" + (string)ticket + " reason=" + sig.reason + " lot=" + DoubleToString(lot, 2));
  else
    LogError("TRADE","send failed", GetLastError());
}
//+------------------------------------------------------------------+

