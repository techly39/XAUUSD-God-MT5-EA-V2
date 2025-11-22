#ifndef INC_CONFIG_INPUTS_MQH
#define INC_CONFIG_INPUTS_MQH

// ================== CORE INDICATORS (M15 SCALPING) ==================
input int    EMA_Trend_Period      = 200;
input int    EMA_Intraday_Period   = 50;
input int    ADX_Period            = 14;
input double ADX_Trend_Threshold   = 25.0;  // BACK TO ORIGINAL
input int    RSI_Period            = 14;
input int    RSI_Buy_Threshold     = 35;
input int    RSI_Sell_Threshold    = 70;
input int    RSI_Exit              = 50;
input int    ATR_Period            = 14;

// ================== BREAKOUT ENGINE ==================
input int    Breakout_Lookback          = 20;
input int    Breakout_CloseBeyond_Points= 3;     // BACK TO ORIGINAL
input int    Pending_Offset_Points      = 5;
input bool   Breakout_Use_ADX_Filter    = false;
input bool   Breakout_Use_Volume_Filter = true;  // ENABLE VOLUME FILTER
input int    Vol_MA_Period              = 20;
input double Vol_Min_Ratio              = 1.5;

// ================== LIQUIDITY-SWEEP ENGINE ==================
input int    Range_Lookback_Bars   = 12;
input int    Range_Min_Width_Points= 100;  // BACK TO ORIGINAL
input int    Range_Max_Width_Points= 800;  // BACK TO ORIGINAL
input int    Sweep_Buffer_Points   = 20;
input int    Sweep_Reentry_Confirm_Bars = 1;
input bool   Sweep_Use_RSI_Confirm = true;  // ENABLE RSI CONFIRMATION

// ================== SESSION FILTERS ==================
input bool   Use_Session_Filter = true;
input int    Session_Start_Hour  = 7;   // BACK TO ORIGINAL (London open)
input int    Session_End_Hour    = 18;  // BACK TO ORIGINAL (NY close)

// ================== RISK / SIZING ==================
input int    Risk_Mode                  = 0;
input double Risk_Percent               = 2.0;
input double Fixed_Lot                  = 0.01;
input double Max_Daily_Drawdown_Percent = 5.0;

// ================== STOPS / TARGETS ==================
input double ATR_Mult_SL_Trend = 1.50;
input double ATR_Mult_SL_Range = 1.20;

// ================== EXECUTION GATES ==================
input int    Min_ATR_Points     = 100;  // BACK TO ORIGINAL
input int    Max_Spread_Points  = 1500;

// ================== MANAGEMENT ==================
input int    Trail_Mode             = 2;    // KEEP ATR TRAILING
input int    Trail_Start_Points     = 150;
input int    Trail_Step_Points      = 120;
input double Trail_ATR_Mult         = 1.00;

input int    Move_BE_After_Points   = 150;
input bool   Use_Partials           = false; // KEEP DISABLED
input double Partial1_Ratio         = 0.50;
input int    Partial1_Target_Points = 200;

// ================== PROFIT TARGETS ==================
input int    TP_Mode         = 1;   // RR mode
input int    TP_Fixed_Points = 200;
input double RR_Target       = 2.0; // Target 2:1 RR

// ================== HOUSEKEEPING ==================
input int    Magic_Offset          = 1;
input int    Max_Slippage_Points   = 50;
input int    Order_Expiration_Min  = 30;
input string Order_Comment         = "XAUUSD-GOD-M15";

// ================== TRADING SCHEDULE ==================
input bool   Trading_Day_Mon = true;
input bool   Trading_Day_Tue = true;
input bool   Trading_Day_Wed = true;
input bool   Trading_Day_Thu = true;
input bool   Trading_Day_Fri = true;
input string Friday_CloseTime = "21:00";

// ================== MISC ==================
input bool   Only_New_Bar = true;
input int    Order_Type   = 0;

#endif
