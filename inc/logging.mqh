#ifndef INC_LOGGING_MQH
#define INC_LOGGING_MQH

static string g_log_prefix = "";

void LogInit(const string prefix)
{
   g_log_prefix = prefix;
}

void LogEvent(const string tag, const string msg)
{
   Print("[" + g_log_prefix + "][" + tag + "] " + msg);
}

void LogError(const string tag, const string msg, const int last_error)
{
   Print("[" + g_log_prefix + "][" + tag + "] " + msg + " (err=" + IntegerToString(last_error) + ")");
}

#endif // INC_LOGGING_MQH