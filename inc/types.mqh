#ifndef INC_TYPES_MQH
#define INC_TYPES_MQH

enum Direction { DIR_NONE = -1, DIR_LONG = 0,  DIR_SHORT  = 1 };
enum OrderType { ORDER_MARKET = 0, ORDER_PENDING = 1 };
enum TPMode    { TP_NONE = 0, TP_FIXED = 1, TP_RR = 2 };
enum TrailMode { TRAIL_NONE = 0, TRAIL_FIXED_STEP = 1, TRAIL_ATR = 2 };

struct Settings {
   int    ADX_Period;
   double ADX_Trend_Threshold;
   int    EMA_Trend_Period;
   int    ATR_Period;
   double ATR_Mult_SL_Range;
   double ATR_Mult_SL_Trend;
   int    RSI_Period;
   int    RSI_Buy_Threshold;
   int    RSI_Sell_Threshold;
   int    Order_Type;
   int    Max_Slippage_Points;
   int    Order_Expiration_Min;
   int    Risk_Mode;
   double Fixed_Lot;
   double Risk_Percent;
   double Max_Daily_Drawdown_Percent;
   int    TP_Mode;
   int    TP_Fixed_Points;
   double RR_Target;
   bool   Use_Partials;
   double Partial1_Ratio;
   int    Partial1_Target_Points;
   int    Move_BE_After_Points;
   int    Trail_Mode;
   int    Trail_Start_Points;
   int    Trail_Step_Points;
   double Trail_ATR_Mult;
   int    Max_Spread_Points;
   int    Min_ATR_Points;
   bool   Trading_Day_Mon;
   bool   Trading_Day_Tue;
   bool   Trading_Day_Wed;
   bool   Trading_Day_Thu;
   bool   Trading_Day_Fri;
   string Friday_CloseTime;
   bool   Only_New_Bar;
   int    Magic_Offset;
   string Order_Comment;
};

struct Signal {
   bool       valid;
   Direction  dir;
   double     entry;
   double     sl;
   double     tp;
   string     reason;
};

struct PositionMeta {
   ulong     ticket;
   Direction dir;
   double    sl;
   double    tp;
   datetime  open_time;
   double    risk_money;
};

#endif // INC_TYPES_MQH
