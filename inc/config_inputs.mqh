#ifndef INC_CONFIG_INPUTS_MQH
#define INC_CONFIG_INPUTS_MQH

// ================== CORE INDICATORS (M15 SCALPING V2) ==================
input group "Indicators"
input int    EMA_Trend_Period      = 50;    // Primary trend EMA for M15
input int    ADX_Period            = 14;
input double ADX_Trend_Threshold   = 20.0;  // Lowered for sensitivity
input int    RSI_Period            = 14;
input int    RSI_Buy_Threshold     = 30;    // Classic oversold level
input int    RSI_Sell_Threshold    = 70;    // Classic overbought level
input int    ATR_Period            = 14;

// ================== SESSION FILTERS ==================
input group "Trading Sessions"
input bool   Use_Session_Filter = true;
input int    Session_Start_Hour  = 7;       // London open (GMT)
input int    Session_End_Hour    = 18;      // NY close (GMT)

// ================== TRADING SCHEDULE ==================
input group "Trading Days"
input bool   Trading_Day_Mon = true;
input bool   Trading_Day_Tue = true;
input bool   Trading_Day_Wed = true;
input bool   Trading_Day_Thu = true;
input bool   Trading_Day_Fri = true;
input string Friday_CloseTime = "21:00";

// ================== RISK / SIZING ==================
input group "Position Sizing"
input int    Risk_Mode                  = 1;     // 1 = Percent risk mode (default)
input double Risk_Percent               = 0.5;   // Reduced to 0.5% per trade
input double Fixed_Lot                  = 0.01;  // Used when Risk_Mode = 0

// ================== RISK LIMITS ==================
input group "Risk Limits"
input double Max_Daily_Drawdown_Percent = 3.0;   // Reduced from 5.0%
input double Max_Weekly_Drawdown_Percent = 7.0;  // New weekly limit
input int    Consecutive_Loss_Limit = 10;        // Pause after N losses
input int    Loss_Pause_Duration_Min = 120;      // Pause duration (2 hours)

// ================== STOPS / TARGETS ==================
input group "Stop Loss & Take Profit"
input double ATR_Mult_SL_Trend = 1.50;  // SL multiplier for trend mode
input double ATR_Mult_SL_Range = 1.20;  // SL multiplier for range mode
input int    TP_Mode         = 1;       // 1 = RR mode (default)
input double RR_Target       = 1.5;     // Target 1.5R (reduced from 2.0)
input int    TP_Fixed_Points = 200;     // Fixed TP (used when TP_Mode != 1)

// ================== EXECUTION GATES ==================
input group "Market Condition Filters"
input int    Min_ATR_Points     = 100;  // Minimum ATR to trade ($1.00)
input int    Max_Spread_Points  = 50;   // Maximum spread allowed ($0.50)

// ================== TRADE MANAGEMENT (OPTIONAL) ==================
input group "Trade Management"
input int    Trail_Mode             = 0;     // 0 = No trailing (default)
input int    Trail_Start_Points     = 150;   // Points before trailing starts
input int    Trail_Step_Points      = 120;   // Fixed step trailing
input double Trail_ATR_Mult         = 1.00;  // ATR trailing multiplier
input int    Move_BE_After_Points   = 150;   // Breakeven trigger
input bool   Use_Partials           = false; // Partial close disabled
input double Partial1_Ratio         = 0.50;  // First partial ratio
input int    Partial1_Target_Points = 200;   // First partial trigger

// ================== HOUSEKEEPING ==================
input group "Order Execution"
input int    Magic_Offset          = 1;
input int    Max_Slippage_Points   = 50;
input int    Order_Expiration_Min  = 30;
input string Order_Comment         = "XAUUSD-GOD-v2";
input bool   Only_New_Bar          = true;

// ================== Section: Edge Case Protections (all optional per PDF 5.1) =================================
input group "Edge-Case Protections (Optional)"

input double SpreadSpike_Multiplier = 3.0;           // Spread spike multiplier (≥1.0)
input int    SpreadSpike_Pause_Minutes = 10;         // Pause duration in minutes
input int    SpreadSpike_MinSamples = 30;            // Min data points for MA (1-60)

input int    FlashCrash_Threshold_Pips = 500;        // M1 range threshold in pips
input int    FlashCrash_Pause_Minutes = 30;          // Pause duration in minutes
#endif // INC_CONFIG_INPUTS_MQH
