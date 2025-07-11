//+------------------------------------------------------------------+
//|                                  a4_MarketRegimeFunctions.mqh |
//|                                    Copyright 2025, a4Trading |
//|                                        www.a4trading.com     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Market Regime Detection Functions                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect Current Market Regime                                   |
//+------------------------------------------------------------------+
MARKET_REGIME DetectMarketRegime()
{
    VOLATILITY_REGIME volRegime = GetVolatilityRegime();
    TREND_STATE trendState = GetTrendState();
    
    // Combine volatility and trend to determine regime
    if(trendState == TRENDING_STRONG)
    {
        switch(volRegime)
        {
            case VOL_LOW: return REGIME_TRENDING_LOW_VOL;
            case VOL_NORMAL: return REGIME_TRENDING_NORMAL_VOL;
            case VOL_HIGH: return REGIME_TRENDING_HIGH_VOL;
        }
    }
    else if(trendState == TRENDING_WEAK)
    {
        switch(volRegime)
        {
            case VOL_LOW: return REGIME_TRENDING_LOW_VOL;
            case VOL_NORMAL: return REGIME_RANGING_NORMAL_VOL;
            case VOL_HIGH: return REGIME_RANGING_HIGH_VOL;
        }
    }
    else // RANGING
    {
        switch(volRegime)
        {
            case VOL_LOW: return REGIME_RANGING_LOW_VOL;
            case VOL_NORMAL: return REGIME_RANGING_NORMAL_VOL;
            case VOL_HIGH: return REGIME_RANGING_HIGH_VOL;
        }
    }
    
    return REGIME_RANGING_NORMAL_VOL; // Default
}

//+------------------------------------------------------------------+
//| Get Volatility Regime                                          |
//+------------------------------------------------------------------+
VOLATILITY_REGIME GetVolatilityRegime()
{
    double currentATR[1];
    if(CopyBuffer(g_ATRHandle, 0, 0, 1, currentATR) <= 0)
        return VOL_NORMAL; // Default if no data
    
    double atrPercentile = CalculateATRPercentile(InpATRPeriod, InpATRLookback);
    
    if(atrPercentile < 0.20) return VOL_LOW;
    else if(atrPercentile > 0.80) return VOL_HIGH;
    else return VOL_NORMAL;
}

//+------------------------------------------------------------------+
//| Calculate ATR Percentile                                       |
//+------------------------------------------------------------------+
double CalculateATRPercentile(int periods, int lookback)
{
    double atrBuffer[];
    ArrayResize(atrBuffer, lookback);
    
    if(CopyBuffer(g_ATRHandle, 0, 0, lookback, atrBuffer) <= 0)
        return 0.5; // Default percentile
    
    double currentATR = atrBuffer[0];
    
    // Sort ATR values to find percentile
    ArraySort(atrBuffer);
    
    // Find position of current ATR in sorted array
    int position = 0;
    for(int i = 0; i < lookback; i++)
    {
        if(atrBuffer[i] <= currentATR)
            position = i;
        else
            break;
    }
    
    return (double)position / (double)(lookback - 1);
}

//+------------------------------------------------------------------+
//| Get Trend State                                                |
//+------------------------------------------------------------------+
TREND_STATE GetTrendState()
{
    double adxBuffer[1];
    
    if(CopyBuffer(g_ADXHandle, MAIN_LINE, 0, 1, adxBuffer) <= 0)
        return RANGING; // Default if no data
    
    double adxValue = adxBuffer[0];
    
    if(adxValue > InpTrendingADXLevel) return TRENDING_STRONG;
    else if(adxValue > InpWeakTrendADXLevel) return TRENDING_WEAK;
    else return RANGING;
}

//+------------------------------------------------------------------+
//| Get Current Market Session                                      |
//+------------------------------------------------------------------+
MARKET_SESSION GetCurrentSession()
{
    MqlDateTime time;
    TimeToStruct(TimeCurrent(), time);
    
    // Convert to GMT/UTC for session detection
    int hour = time.hour;
    
    // Define session times (GMT)
    // Asian: 23:00-08:00 GMT
    // European: 07:00-16:00 GMT  
    // American: 13:00-22:00 GMT
    
    if((hour >= 23) || (hour < 8))
        return SESSION_ASIAN;
    else if(hour >= 7 && hour < 13)
        return SESSION_EUROPEAN;
    else if(hour >= 13 && hour < 16)
        return SESSION_OVERLAP; // European-American overlap
    else if(hour >= 16 && hour < 22)
        return SESSION_AMERICAN;
    else
        return SESSION_ASIAN; // Default
}

//+------------------------------------------------------------------+
//| Get Regime Multiplier for Signal Strength                      |
//+------------------------------------------------------------------+
double GetRegimeMultiplier(MARKET_REGIME regime)
{
    switch(regime)
    {
        case REGIME_TRENDING_LOW_VOL:     return 1.2;  // Best conditions
        case REGIME_TRENDING_NORMAL_VOL:  return 1.1;  // Good conditions
        case REGIME_TRENDING_HIGH_VOL:    return 1.0;  // Acceptable conditions
        case REGIME_RANGING_LOW_VOL:      return 0.9;  // Reduced signals
        case REGIME_RANGING_NORMAL_VOL:   return 0.8;  // Further reduced
        case REGIME_RANGING_HIGH_VOL:     return 0.0;  // Avoid trading
        default:                          return 1.0;
    }
}

//+------------------------------------------------------------------+
//| Get Volatility Adjustment for Adaptive Threshold               |
//+------------------------------------------------------------------+
double GetVolatilityAdjustment()
{
    VOLATILITY_REGIME volRegime = GetVolatilityRegime();
    
    switch(volRegime)
    {
        case VOL_LOW:    return 0.95;  // Lower threshold in low volatility
        case VOL_NORMAL: return 1.0;   // Normal threshold
        case VOL_HIGH:   return 1.1;   // Higher threshold in high volatility
        default:         return 1.0;
    }
}

//+------------------------------------------------------------------+
//| Get Session Adjustment for Adaptive Threshold                  |
//+------------------------------------------------------------------+
double GetSessionAdjustment()
{
    MARKET_SESSION session = GetCurrentSession();
    
    switch(session)
    {
        case SESSION_ASIAN:    return 1.05; // Slightly higher threshold (less active)
        case SESSION_EUROPEAN: return 0.98; // Slightly lower threshold (active)
        case SESSION_AMERICAN: return 0.95; // Lower threshold (most active)
        case SESSION_OVERLAP:  return 0.90; // Lowest threshold (highest activity)
        default:               return 1.0;
    }
}

//+------------------------------------------------------------------+
//| Advanced Volatility Analysis                                   |
//+------------------------------------------------------------------+
double CalculateVolatilityScore()
{
    double atrBuffer[20];
    
    if(CopyBuffer(g_ATRHandle, 0, 0, 20, atrBuffer) <= 0)
        return 0.5; // Default score
    
    double currentATR = atrBuffer[0];
    
    // Calculate ATR trend (increasing or decreasing volatility)
    double atrSum1 = 0.0, atrSum2 = 0.0;
    
    for(int i = 0; i < 5; i++)
        atrSum1 += atrBuffer[i];
    
    for(int i = 5; i < 10; i++)
        atrSum2 += atrBuffer[i];
    
    double atrTrend = (atrSum1 / 5.0) / (atrSum2 / 5.0);
    
    // Calculate volatility clustering
    double volatilityClustering = CalculateVolatilityClustering(atrBuffer);
    
    // Calculate percentile rank
    double percentileRank = CalculateATRPercentile(InpATRPeriod, InpATRLookback);
    
    // Combine factors for volatility score
    double score = 0.0;
    
    // ATR trend component (30%)
    if(atrTrend > 1.1) score += 0.3;        // Increasing volatility
    else if(atrTrend > 0.95) score += 0.2;  // Stable volatility
    else score += 0.1;                      // Decreasing volatility
    
    // Volatility clustering component (35%)
    score += volatilityClustering * 0.35;
    
    // Percentile rank component (35%)
    if(percentileRank > 0.8) score += 0.1;      // Very high volatility - reduce score
    else if(percentileRank > 0.6) score += 0.35; // High volatility - full score
    else if(percentileRank > 0.4) score += 0.30; // Medium volatility
    else if(percentileRank > 0.2) score += 0.25; // Low volatility
    else score += 0.15;                          // Very low volatility
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Calculate Volatility Clustering                                |
//+------------------------------------------------------------------+
double CalculateVolatilityClustering(double& atrArray[])
{
    int size = ArraySize(atrArray);
    if(size < 10) return 0.5;
    
    double avgATR = 0.0;
    for(int i = 0; i < size; i++)
        avgATR += atrArray[i];
    avgATR /= size;
    
    // Calculate how many consecutive periods have similar volatility
    int clusterCount = 0;
    int maxCluster = 0;
    double tolerance = avgATR * 0.2; // 20% tolerance
    
    for(int i = 1; i < size; i++)
    {
        if(MathAbs(atrArray[i] - atrArray[i-1]) <= tolerance)
        {
            clusterCount++;
        }
        else
        {
            if(clusterCount > maxCluster)
                maxCluster = clusterCount;
            clusterCount = 0;
        }
    }
    
    if(clusterCount > maxCluster)
        maxCluster = clusterCount;
    
    return MathMin(1.0, (double)maxCluster / (double)(size / 2));
}

//+------------------------------------------------------------------+
//| Advanced Trend Strength Analysis                               |
//+------------------------------------------------------------------+
double CalculateTrendStrengthScore()
{
    double adxBuffer[10], plusDIBuffer[10], minusDIBuffer[10];
    
    if(CopyBuffer(g_ADXHandle, MAIN_LINE, 0, 10, adxBuffer) <= 0 ||
       CopyBuffer(g_ADXHandle, PLUSDI_LINE, 0, 10, plusDIBuffer) <= 0 ||
       CopyBuffer(g_ADXHandle, MINUSDI_LINE, 0, 10, minusDIBuffer) <= 0)
        return 0.5; // Default score
    
    double currentADX = adxBuffer[0];
    double currentPlusDI = plusDIBuffer[0];
    double currentMinusDI = minusDIBuffer[0];
    
    double score = 0.0;
    
    // ADX level component (40%)
    if(currentADX > 40) score += 0.40;
    else if(currentADX > 30) score += 0.35;
    else if(currentADX > 25) score += 0.30;
    else if(currentADX > 20) score += 0.20;
    else if(currentADX > 15) score += 0.10;
    else score += 0.05;
    
    // DI separation component (30%)
    double diSeparation = MathAbs(currentPlusDI - currentMinusDI);
    if(diSeparation > 20) score += 0.30;
    else if(diSeparation > 15) score += 0.25;
    else if(diSeparation > 10) score += 0.20;
    else if(diSeparation > 5) score += 0.15;
    else score += 0.05;
    
    // ADX trend component (30%)
    bool adxRising = true;
    for(int i = 1; i < 5; i++)
    {
        if(adxBuffer[i-1] <= adxBuffer[i])
        {
            adxRising = false;
            break;
        }
    }
    
    if(adxRising) score += 0.30;
    else score += 0.15;
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Get Trend Direction Multiplier                                 |
//+------------------------------------------------------------------+
double GetTrendMultiplier()
{
    TREND_STATE trendState = GetTrendState();
    
    switch(trendState)
    {
        case TRENDING_STRONG: return 1.2;  // Strong trend - enhance signals
        case TRENDING_WEAK:   return 1.0;  // Weak trend - normal signals
        case RANGING:         return 0.8;  // Range - reduce signals
        default:              return 1.0;
    }
}

//+------------------------------------------------------------------+
//| Session-based Market Activity Analysis                         |
//+------------------------------------------------------------------+
double GetSessionActivityScore()
{
    MARKET_SESSION session = GetCurrentSession();
    MqlDateTime time;
    TimeToStruct(TimeCurrent(), time);
    
    double baseScore = 0.5;
    
    switch(session)
    {
        case SESSION_ASIAN:
            // Asian session - generally lower activity
            baseScore = 0.4;
            // Peak activity in middle of session
            if(time.hour >= 1 && time.hour <= 5)
                baseScore += 0.2;
            break;
            
        case SESSION_EUROPEAN:
            // European session - good activity
            baseScore = 0.7;
            // Peak activity in early European hours
            if(time.hour >= 8 && time.hour <= 11)
                baseScore += 0.2;
            break;
            
        case SESSION_AMERICAN:
            // American session - high activity
            baseScore = 0.8;
            // Peak activity in early American hours
            if(time.hour >= 14 && time.hour <= 17)
                baseScore += 0.2;
            break;
            
        case SESSION_OVERLAP:
            // European-American overlap - highest activity
            baseScore = 0.9;
            baseScore += 0.1; // Always bonus during overlap
            break;
    }
    
    return MathMax(0.0, MathMin(1.0, baseScore));
}

//+------------------------------------------------------------------+
//| Check if Market Conditions are Suitable for Trading           |
//+------------------------------------------------------------------+
bool IsMarketSuitableForTrading()
{
    MARKET_REGIME regime = DetectMarketRegime();
    
    // Skip trading in ranging high volatility
    if(InpSkipRangingHighVol && regime == REGIME_RANGING_HIGH_VOL)
        return false;
    
    // Check spread conditions
    double spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
    double averageSpread = GetAverageSpread();
    
    // Don't trade if spread is too high
    if(spread > averageSpread * 2.0)
        return false;
    
    // Check session activity
    double sessionActivity = GetSessionActivityScore();
    if(sessionActivity < 0.3)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Get Average Spread over Recent Period                          |
//+------------------------------------------------------------------+
double GetAverageSpread()
{
    static double spreadHistory[100];
    static int spreadIndex = 0;
    static bool spreadArrayFilled = false;
    
    double currentSpread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
    
    // Store current spread
    spreadHistory[spreadIndex] = currentSpread;
    spreadIndex = (spreadIndex + 1) % 100;
    
    if(spreadIndex == 0) spreadArrayFilled = true;
    
    // Calculate average
    double sum = 0.0;
    int count = spreadArrayFilled ? 100 : spreadIndex;
    
    for(int i = 0; i < count; i++)
        sum += spreadHistory[i];
    
    return count > 0 ? sum / count : currentSpread;
}

//+------------------------------------------------------------------+
//| Market Hours Analysis                                           |
//+------------------------------------------------------------------+
bool IsOptimalTradingTime()
{
    MqlDateTime time;
    TimeToStruct(TimeCurrent(), time);
    
    // Avoid trading during major news times (simplified)
    // This would be enhanced with a news calendar in production
    
    // Avoid trading 30 minutes before and after major session opens/closes
    int hour = time.hour;
    int minute = time.min; // Fixed: use 'min' instead of 'minute'
    
    // European open (8:00 GMT) ±30 minutes
    if((hour == 7 && minute >= 30) || (hour == 8 && minute <= 30))
        return false;
    
    // American open (13:00 GMT) ±30 minutes  
    if((hour == 12 && minute >= 30) || (hour == 13 && minute <= 30))
        return false;
    
    // European close (16:00 GMT) ±30 minutes
    if((hour == 15 && minute >= 30) || (hour == 16 && minute <= 30))
        return false;
    
    // American close (22:00 GMT) ±30 minutes
    if((hour == 21 && minute >= 30) || (hour == 22 && minute <= 30))
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Regime Change Detection                                         |
//+------------------------------------------------------------------+
bool IsRegimeChanging()
{
    static MARKET_REGIME lastRegime = REGIME_TRENDING_NORMAL_VOL;
    MARKET_REGIME currentRegime = DetectMarketRegime();
    
    bool regimeChanged = (currentRegime != lastRegime);
    lastRegime = currentRegime;
    
    return regimeChanged;
}