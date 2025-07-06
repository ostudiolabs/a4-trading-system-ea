//+------------------------------------------------------------------+
//|                              a4_MultiTimeframeFunctions.mqh |
//|                                    Copyright 2025, a4Trading |
//|                                        www.a4trading.com     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Multi-Timeframe Analysis Functions                              |
//+------------------------------------------------------------------+

// Global timeframe data
TimeframeData g_HigherTFData;
TimeframeData g_LowerTFData;

//+------------------------------------------------------------------+
//| Initialize Timeframes                                           |
//+------------------------------------------------------------------+
void InitializeTimeframes()
{
    ENUM_TIMEFRAMES currentTF = Period();
    
    // Determine higher and lower timeframes
    g_HigherTF = GetHigherTimeframe(currentTF);
    g_LowerTF = GetLowerTimeframe(currentTF);
    
    // Initialize higher timeframe data
    InitializeTimeframeData(g_HigherTFData, g_HigherTF);
    
    // Initialize lower timeframe data
    InitializeTimeframeData(g_LowerTFData, g_LowerTF);
    
    Print("Multi-Timeframe Analysis Initialized:");
    Print("Current TF: ", EnumToString(currentTF));
    Print("Higher TF: ", EnumToString(g_HigherTF));
    Print("Lower TF: ", EnumToString(g_LowerTF));
}

//+------------------------------------------------------------------+
//| Get Higher Timeframe (4x current)                              |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetHigherTimeframe(ENUM_TIMEFRAMES currentTF)
{
    switch(currentTF)
    {
        case PERIOD_M1:  return PERIOD_M5;
        case PERIOD_M2:  return PERIOD_M15;
        case PERIOD_M3:  return PERIOD_M15;
        case PERIOD_M4:  return PERIOD_M15;
        case PERIOD_M5:  return PERIOD_M30;
        case PERIOD_M6:  return PERIOD_M30;
        case PERIOD_M10: return PERIOD_H1;
        case PERIOD_M12: return PERIOD_H1;
        case PERIOD_M15: return PERIOD_H1;
        case PERIOD_M20: return PERIOD_H2;
        case PERIOD_M30: return PERIOD_H2;
        case PERIOD_H1:  return PERIOD_H4;
        case PERIOD_H2:  return PERIOD_H12;
        case PERIOD_H3:  return PERIOD_H12;
        case PERIOD_H4:  return PERIOD_D1;
        case PERIOD_H6:  return PERIOD_D1;
        case PERIOD_H8:  return PERIOD_D1;
        case PERIOD_H12: return PERIOD_D1;
        case PERIOD_D1:  return PERIOD_W1;
        case PERIOD_W1:  return PERIOD_MN1;
        case PERIOD_MN1: return PERIOD_MN1; // Stay at monthly
        default:         return PERIOD_H4;   // Default
    }
}

//+------------------------------------------------------------------+
//| Get Lower Timeframe (1/4 current)                              |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetLowerTimeframe(ENUM_TIMEFRAMES currentTF)
{
    switch(currentTF)
    {
        case PERIOD_M1:  return PERIOD_M1;   // Stay at M1
        case PERIOD_M2:  return PERIOD_M1;
        case PERIOD_M3:  return PERIOD_M1;
        case PERIOD_M4:  return PERIOD_M1;
        case PERIOD_M5:  return PERIOD_M1;
        case PERIOD_M6:  return PERIOD_M1;
        case PERIOD_M10: return PERIOD_M2;
        case PERIOD_M12: return PERIOD_M3;
        case PERIOD_M15: return PERIOD_M3;
        case PERIOD_M20: return PERIOD_M5;
        case PERIOD_M30: return PERIOD_M6;
        case PERIOD_H1:  return PERIOD_M15;
        case PERIOD_H2:  return PERIOD_M30;
        case PERIOD_H3:  return PERIOD_M30;
        case PERIOD_H4:  return PERIOD_H1;
        case PERIOD_H6:  return PERIOD_H1;
        case PERIOD_H8:  return PERIOD_H2;
        case PERIOD_H12: return PERIOD_H3;
        case PERIOD_D1:  return PERIOD_H4;
        case PERIOD_W1:  return PERIOD_D1;
        case PERIOD_MN1: return PERIOD_W1;
        default:         return PERIOD_M15;  // Default
    }
}

//+------------------------------------------------------------------+
//| Initialize Timeframe Data                                       |
//+------------------------------------------------------------------+
void InitializeTimeframeData(TimeframeData& tfData, ENUM_TIMEFRAMES timeframe)
{
    tfData.timeframe = timeframe;
    tfData.isValid = false;
    
    // Create indicator handles for this timeframe
    tfData.emaFastHandle = iMA(Symbol(), timeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    tfData.emaMediumHandle = iMA(Symbol(), timeframe, InpMediumEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    tfData.emaSlowHandle = iMA(Symbol(), timeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    tfData.atrHandle = iATR(Symbol(), timeframe, InpATRPeriod);
    tfData.adxHandle = iADX(Symbol(), timeframe, InpADXPeriod);
    tfData.rsiHandle = iRSI(Symbol(), timeframe, InpRSIPeriod, PRICE_CLOSE);
    
    // Check if all handles are valid
    if(tfData.emaFastHandle != INVALID_HANDLE &&
       tfData.emaMediumHandle != INVALID_HANDLE &&
       tfData.emaSlowHandle != INVALID_HANDLE &&
       tfData.atrHandle != INVALID_HANDLE &&
       tfData.adxHandle != INVALID_HANDLE &&
       tfData.rsiHandle != INVALID_HANDLE)
    {
        tfData.isValid = true;
    }
    else
    {
        Print("Warning: Could not initialize all indicators for timeframe ", EnumToString(timeframe));
    }
}

//+------------------------------------------------------------------+
//| Get Higher Timeframe Trend Score                               |
//+------------------------------------------------------------------+
double GetHTFTrendScore()
{
    if(!InpEnableMultiTimeframe || !g_HigherTFData.isValid)
        return 1.0; // Neutral if disabled or invalid
    
    double score = 0.0;
    
    // 1. Higher TF EMA Alignment (40% of HTF score)
    double htfEMAAlignment = GetHTFEMAAlignment();
    score += htfEMAAlignment * 0.40;
    
    // 2. Higher TF Trend Direction (35% of HTF score)
    double htfTrendDirection = GetHTFTrendDirection();
    score += htfTrendDirection * 0.35;
    
    // 3. Higher TF Momentum Confirmation (25% of HTF score)
    double htfMomentum = GetHTFMomentumConfirmation();
    score += htfMomentum * 0.25;
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Get Higher Timeframe EMA Alignment                             |
//+------------------------------------------------------------------+
double GetHTFEMAAlignment()
{
    double fastEMA[3], mediumEMA[3], slowEMA[3];
    
    if(CopyBuffer(g_HigherTFData.emaFastHandle, 0, 0, 3, fastEMA) <= 0 ||
       CopyBuffer(g_HigherTFData.emaMediumHandle, 0, 0, 3, mediumEMA) <= 0 ||
       CopyBuffer(g_HigherTFData.emaSlowHandle, 0, 0, 3, slowEMA) <= 0)
        return 0.5; // Neutral if no data
    
    double score = 0.0;
    
    // Check EMA order alignment
    if((fastEMA[0] > mediumEMA[0] && mediumEMA[0] > slowEMA[0]) ||
       (fastEMA[0] < mediumEMA[0] && mediumEMA[0] < slowEMA[0]))
    {
        score += 0.6; // Good alignment
        
        // Check if alignment is strengthening
        if(ArraySize(fastEMA) >= 2 && ArraySize(mediumEMA) >= 2 && ArraySize(slowEMA) >= 2)
        {
            double prevFastMediumGap = MathAbs(fastEMA[1] - mediumEMA[1]);
            double currentFastMediumGap = MathAbs(fastEMA[0] - mediumEMA[0]);
            
            if(currentFastMediumGap > prevFastMediumGap)
                score += 0.3; // Strengthening alignment
            else
                score += 0.1; // Stable alignment
        }
    }
    else
    {
        score = 0.2; // Poor alignment
    }
    
    // Check EMA trend consistency
    bool fastRising = ArraySize(fastEMA) >= 2 && fastEMA[0] > fastEMA[1];
    bool mediumRising = ArraySize(mediumEMA) >= 2 && mediumEMA[0] > mediumEMA[1];
    bool slowRising = ArraySize(slowEMA) >= 2 && slowEMA[0] > slowEMA[1];
    
    if((fastRising && mediumRising && slowRising) ||
       (!fastRising && !mediumRising && !slowRising))
    {
        score += 0.1; // Bonus for trend consistency
    }
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Get Higher Timeframe Trend Direction                           |
//+------------------------------------------------------------------+
double GetHTFTrendDirection()
{
    double adxBuffer[3], plusDI[3], minusDI[3];
    
    if(CopyBuffer(g_HigherTFData.adxHandle, MAIN_LINE, 0, 3, adxBuffer) <= 0 ||
       CopyBuffer(g_HigherTFData.adxHandle, PLUSDI_LINE, 0, 3, plusDI) <= 0 ||
       CopyBuffer(g_HigherTFData.adxHandle, MINUSDI_LINE, 0, 3, minusDI) <= 0)
        return 0.5; // Neutral if no data
    
    double currentADX = adxBuffer[0];
    double currentPlusDI = plusDI[0];
    double currentMinusDI = minusDI[0];
    
    double score = 0.0;
    
    // Score based on ADX strength
    if(currentADX > 30)
        score += 0.5; // Strong trend
    else if(currentADX > 25)
        score += 0.4; // Good trend
    else if(currentADX > 20)
        score += 0.3; // Moderate trend
    else
        score += 0.1; // Weak trend
    
    // Score based on DI separation
    double diSeparation = MathAbs(currentPlusDI - currentMinusDI);
    if(diSeparation > 15)
        score += 0.3; // Clear direction
    else if(diSeparation > 10)
        score += 0.2; // Some direction
    else
        score += 0.1; // Weak direction
    
    // Check if trend is strengthening
    if(ArraySize(adxBuffer) >= 2)
    {
        if(adxBuffer[0] > adxBuffer[1])
            score += 0.2; // Strengthening trend
        else
            score += 0.1; // Stable/weakening trend
    }
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Get Higher Timeframe Momentum Confirmation                     |
//+------------------------------------------------------------------+
double GetHTFMomentumConfirmation()
{
    double rsiBuffer[3];
    
    if(CopyBuffer(g_HigherTFData.rsiHandle, 0, 0, 3, rsiBuffer) <= 0)
        return 0.5; // Neutral if no data
    
    double currentRSI = rsiBuffer[0];
    double score = 0.0;
    
    // Score based on RSI level (momentum strength)
    if(currentRSI > 50 && currentRSI < 70)
        score += 0.5; // Good bullish momentum
    else if(currentRSI < 50 && currentRSI > 30)
        score += 0.5; // Good bearish momentum
    else if(currentRSI >= 45 && currentRSI <= 55)
        score += 0.4; // Neutral momentum
    else if(currentRSI > 70 || currentRSI < 30)
        score += 0.2; // Extreme levels - caution
    else
        score += 0.3; // Other levels
    
    // Check RSI trend
    if(ArraySize(rsiBuffer) >= 2)
    {
        bool rsiRising = rsiBuffer[0] > rsiBuffer[1];
        
        if((currentRSI > 50 && rsiRising) || (currentRSI < 50 && !rsiRising))
            score += 0.3; // RSI trend matches direction
        else
            score += 0.1; // RSI trend doesn't match
    }
    
    // Price vs Higher TF EMA confirmation
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double htfSlowEMA[1];
    
    if(CopyBuffer(g_HigherTFData.emaSlowHandle, 0, 0, 1, htfSlowEMA) > 0)
    {
        if((currentPrice > htfSlowEMA[0] && currentRSI > 50) ||
           (currentPrice < htfSlowEMA[0] && currentRSI < 50))
            score += 0.2; // Price and momentum aligned
    }
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Get Lower Timeframe Entry Quality                              |
//+------------------------------------------------------------------+
double GetLTFEntryQuality()
{
    if(!InpEnableMultiTimeframe || !g_LowerTFData.isValid)
        return 1.0; // Neutral if disabled or invalid
    
    double score = 0.0;
    
    // 1. Lower TF Entry Timing (40% of LTF score)
    double ltfTiming = GetLTFEntryTiming();
    score += ltfTiming * 0.40;
    
    // 2. Lower TF Short-term Momentum (35% of LTF score)
    double ltfMomentum = GetLTFMomentum();
    score += ltfMomentum * 0.35;
    
    // 3. Lower TF Price Action Quality (25% of LTF score)
    double ltfPriceAction = GetLTFPriceActionQuality();
    score += ltfPriceAction * 0.25;
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Get Lower Timeframe Entry Timing                               |
//+------------------------------------------------------------------+
double GetLTFEntryTiming()
{
    double fastEMA[5], mediumEMA[5];
    
    if(CopyBuffer(g_LowerTFData.emaFastHandle, 0, 0, 5, fastEMA) <= 0 ||
       CopyBuffer(g_LowerTFData.emaMediumHandle, 0, 0, 5, mediumEMA) <= 0)
        return 0.5; // Neutral if no data
    
    double score = 0.0;
    
    // Check for recent crossover in lower timeframe
    bool recentBullishCrossover = false;
    bool recentBearishCrossover = false;
    
    for(int i = 0; i < 3; i++) // Check last 3 bars
    {
        if(i < ArraySize(fastEMA) - 1 && i < ArraySize(mediumEMA) - 1)
        {
            if(fastEMA[i] > mediumEMA[i] && fastEMA[i + 1] <= mediumEMA[i + 1])
                recentBullishCrossover = true;
            if(fastEMA[i] < mediumEMA[i] && fastEMA[i + 1] >= mediumEMA[i + 1])
                recentBearishCrossover = true;
        }
    }
    
    if(recentBullishCrossover || recentBearishCrossover)
    {
        score += 0.7; // Good timing - recent crossover
        
        // Check if crossover is gaining momentum
        if(ArraySize(fastEMA) >= 2 && ArraySize(mediumEMA) >= 2)
        {
            double currentGap = MathAbs(fastEMA[0] - mediumEMA[0]);
            double previousGap = MathAbs(fastEMA[1] - mediumEMA[1]);
            
            if(currentGap > previousGap)
                score += 0.2; // Gaining momentum
        }
    }
    else
    {
        // No recent crossover - check current alignment quality
        if(fastEMA[0] > mediumEMA[0])
            score += 0.4; // Fast above medium - bullish bias
        else
            score += 0.4; // Fast below medium - bearish bias
    }
    
    // Check EMA angle/slope for timing
    if(ArraySize(fastEMA) >= 3)
    {
        double emaSlope = (fastEMA[0] - fastEMA[2]) / 2.0;
        double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double slopePercent = (emaSlope / currentPrice) * 10000; // Convert to percentage
        
        if(MathAbs(slopePercent) > 1.0)
            score += 0.1; // Good momentum
    }
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Get Lower Timeframe Momentum                                   |
//+------------------------------------------------------------------+
double GetLTFMomentum()
{
    double rsiBuffer[5];
    
    if(CopyBuffer(g_LowerTFData.rsiHandle, 0, 0, 5, rsiBuffer) <= 0)
        return 0.5; // Neutral if no data
    
    double currentRSI = rsiBuffer[0];
    double score = 0.0;
    
    // Score based on RSI momentum level
    if(currentRSI > 55 && currentRSI < 75)
        score += 0.5; // Good bullish momentum
    else if(currentRSI < 45 && currentRSI > 25)
        score += 0.5; // Good bearish momentum
    else if(currentRSI >= 45 && currentRSI <= 55)
        score += 0.4; // Neutral momentum
    else
        score += 0.2; // Extreme levels
    
    // Check RSI momentum direction
    if(ArraySize(rsiBuffer) >= 3)
    {
        bool rsiAccelerating = false;
        
        // Check if RSI is accelerating in current direction
        if(currentRSI > 50)
        {
            // Bullish - check if momentum is increasing
            if(rsiBuffer[0] > rsiBuffer[1] && rsiBuffer[1] > rsiBuffer[2])
                rsiAccelerating = true;
        }
        else
        {
            // Bearish - check if momentum is increasing
            if(rsiBuffer[0] < rsiBuffer[1] && rsiBuffer[1] < rsiBuffer[2])
                rsiAccelerating = true;
        }
        
        if(rsiAccelerating)
            score += 0.3; // Accelerating momentum
        else
            score += 0.1; // Stable momentum
    }
    
    // Check for momentum divergence with current timeframe
    double currentTFRSI[1];
    
    if(CopyBuffer(g_RSIHandle, 0, 0, 1, currentTFRSI) > 0)
    {
        double rsiDifference = MathAbs(currentRSI - currentTFRSI[0]);
        
        if(rsiDifference < 5.0)
            score += 0.2; // RSI aligned between timeframes
        else if(rsiDifference < 10.0)
            score += 0.1; // Some divergence
        else
            score += 0.05; // Significant divergence
    }
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Get Lower Timeframe Price Action Quality                       |
//+------------------------------------------------------------------+
double GetLTFPriceActionQuality()
{
    double score = 0.0;
    
    // Check recent candle formations on lower timeframe
    double ltfOpen = iOpen(Symbol(), g_LowerTFData.timeframe, 0);
    double ltfHigh = iHigh(Symbol(), g_LowerTFData.timeframe, 0);
    double ltfLow = iLow(Symbol(), g_LowerTFData.timeframe, 0);
    double ltfClose = iClose(Symbol(), g_LowerTFData.timeframe, 0);
    
    // Check candle body vs shadow ratio
    double bodySize = MathAbs(ltfClose - ltfOpen);
    double totalRange = ltfHigh - ltfLow;
    
    if(totalRange > 0)
    {
        double bodyRatio = bodySize / totalRange;
        
        if(bodyRatio > 0.6)
            score += 0.4; // Strong directional candle
        else if(bodyRatio > 0.4)
            score += 0.3; // Good directional candle
        else if(bodyRatio > 0.2)
            score += 0.2; // Moderate candle
        else
            score += 0.1; // Weak/doji candle
    }
    
    // Check immediate price momentum
    double prevClose = iClose(Symbol(), g_LowerTFData.timeframe, 1);
    if(prevClose != 0)
    {
        double priceChange = (ltfClose - prevClose) / prevClose * 100;
        
        if(MathAbs(priceChange) > 0.1)
            score += 0.3; // Good momentum
        else if(MathAbs(priceChange) > 0.05)
            score += 0.2; // Some momentum
        else
            score += 0.1; // Low momentum
    }
    
    // Check for immediate support/resistance interaction
    double atrBuffer[1];
    
    if(CopyBuffer(g_LowerTFData.atrHandle, 0, 0, 1, atrBuffer) > 0)
    {
        double ltfATR = atrBuffer[0];
        
        // Check if price is near recent high/low
        double recentHigh = ltfHigh;
        double recentLow = ltfLow;
        
        for(int i = 1; i <= 5; i++)
        {
            double high = iHigh(Symbol(), g_LowerTFData.timeframe, i);
            double low = iLow(Symbol(), g_LowerTFData.timeframe, i);
            
            if(high > recentHigh) recentHigh = high;
            if(low < recentLow) recentLow = low;
        }
        
        // Check position relative to recent range
        double rangePosition = (ltfClose - recentLow) / (recentHigh - recentLow);
        
        if(rangePosition > 0.7 || rangePosition < 0.3)
            score += 0.2; // Near range extremes
        else
            score += 0.1; // Middle of range
    }
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Check Multi-Timeframe Alignment                                |
//+------------------------------------------------------------------+
bool IsMultiTimeframeAligned()
{
    if(!InpEnableMultiTimeframe) return true;
    
    double htfScore = GetHTFTrendScore();
    double ltfScore = GetLTFEntryQuality();
    
    // Check if both timeframes meet minimum requirements
    bool htfAligned = htfScore >= InpMinHTFAlignment;
    bool ltfGood = ltfScore >= 0.4; // Minimum LTF quality
    
    return htfAligned && ltfGood;
}

//+------------------------------------------------------------------+
//| Get Multi-Timeframe Signal Strength                            |
//+------------------------------------------------------------------+
double GetMultiTimeframeSignalStrength()
{
    if(!InpEnableMultiTimeframe) return 1.0;
    
    double htfScore = GetHTFTrendScore();
    double ltfScore = GetLTFEntryQuality();
    
    // Combine scores with higher weight on HTF
    double combinedScore = (htfScore * 0.7) + (ltfScore * 0.3);
    
    return MathMax(0.0, MathMin(1.0, combinedScore));
}

//+------------------------------------------------------------------+
//| Get Timeframe Consensus                                         |
//+------------------------------------------------------------------+
int GetTimeframeConsensus()
{
    int bullishCount = 0;
    int bearishCount = 0;
    
    // Current timeframe signals
    if(IsBullishEMASetup()) bullishCount++;
    else if(IsBearishEMASetup()) bearishCount++;
    
    // Higher timeframe signals
    if(InpEnableMultiTimeframe && g_HigherTFData.isValid)
    {
        if(IsHTFBullish()) bullishCount++;
        else if(IsHTFBearish()) bearishCount++;
    }
    
    // Lower timeframe signals
    if(InpEnableMultiTimeframe && g_LowerTFData.isValid)
    {
        if(IsLTFBullish()) bullishCount++;
        else if(IsLTFBearish()) bearishCount++;
    }
    
    if(bullishCount > bearishCount) return 1;  // Bullish consensus
    else if(bearishCount > bullishCount) return -1; // Bearish consensus
    else return 0; // No consensus
}

//+------------------------------------------------------------------+
//| Helper Functions for Timeframe Direction                       |
//+------------------------------------------------------------------+
bool IsHTFBullish()
{
    double fastEMA[1], mediumEMA[1], slowEMA[1];
    
    if(CopyBuffer(g_HigherTFData.emaFastHandle, 0, 0, 1, fastEMA) <= 0 ||
       CopyBuffer(g_HigherTFData.emaMediumHandle, 0, 0, 1, mediumEMA) <= 0 ||
       CopyBuffer(g_HigherTFData.emaSlowHandle, 0, 0, 1, slowEMA) <= 0)
        return false;
    
    return (fastEMA[0] > mediumEMA[0] && mediumEMA[0] > slowEMA[0]);
}

bool IsHTFBearish()
{
    double fastEMA[1], mediumEMA[1], slowEMA[1];
    
    if(CopyBuffer(g_HigherTFData.emaFastHandle, 0, 0, 1, fastEMA) <= 0 ||
       CopyBuffer(g_HigherTFData.emaMediumHandle, 0, 0, 1, mediumEMA) <= 0 ||
       CopyBuffer(g_HigherTFData.emaSlowHandle, 0, 0, 1, slowEMA) <= 0)
        return false;
    
    return (fastEMA[0] < mediumEMA[0] && mediumEMA[0] < slowEMA[0]);
}

bool IsLTFBullish()
{
    double fastEMA[1], mediumEMA[1];
    
    if(CopyBuffer(g_LowerTFData.emaFastHandle, 0, 0, 1, fastEMA) <= 0 ||
       CopyBuffer(g_LowerTFData.emaMediumHandle, 0, 0, 1, mediumEMA) <= 0)
        return false;
    
    return (fastEMA[0] > mediumEMA[0]);
}

bool IsLTFBearish()
{
    double fastEMA[1], mediumEMA[1];
    
    if(CopyBuffer(g_LowerTFData.emaFastHandle, 0, 0, 1, fastEMA) <= 0 ||
       CopyBuffer(g_LowerTFData.emaMediumHandle, 0, 0, 1, mediumEMA) <= 0)
        return false;
    
    return (fastEMA[0] < mediumEMA[0]);
}

//+------------------------------------------------------------------+
//| Cleanup Timeframe Data                                         |
//+------------------------------------------------------------------+
void CleanupTimeframeData()
{
    // Release higher timeframe handles
    if(g_HigherTFData.emaFastHandle != INVALID_HANDLE) IndicatorRelease(g_HigherTFData.emaFastHandle);
    if(g_HigherTFData.emaMediumHandle != INVALID_HANDLE) IndicatorRelease(g_HigherTFData.emaMediumHandle);
    if(g_HigherTFData.emaSlowHandle != INVALID_HANDLE) IndicatorRelease(g_HigherTFData.emaSlowHandle);
    if(g_HigherTFData.atrHandle != INVALID_HANDLE) IndicatorRelease(g_HigherTFData.atrHandle);
    if(g_HigherTFData.adxHandle != INVALID_HANDLE) IndicatorRelease(g_HigherTFData.adxHandle);
    if(g_HigherTFData.rsiHandle != INVALID_HANDLE) IndicatorRelease(g_HigherTFData.rsiHandle);
    
    // Release lower timeframe handles
    if(g_LowerTFData.emaFastHandle != INVALID_HANDLE) IndicatorRelease(g_LowerTFData.emaFastHandle);
    if(g_LowerTFData.emaMediumHandle != INVALID_HANDLE) IndicatorRelease(g_LowerTFData.emaMediumHandle);
    if(g_LowerTFData.emaSlowHandle != INVALID_HANDLE) IndicatorRelease(g_LowerTFData.emaSlowHandle);
    if(g_LowerTFData.atrHandle != INVALID_HANDLE) IndicatorRelease(g_LowerTFData.atrHandle);
    if(g_LowerTFData.adxHandle != INVALID_HANDLE) IndicatorRelease(g_LowerTFData.adxHandle);
    if(g_LowerTFData.rsiHandle != INVALID_HANDLE) IndicatorRelease(g_LowerTFData.rsiHandle);
}