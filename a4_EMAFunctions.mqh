//+------------------------------------------------------------------+
//|                                           a4_EMAFunctions.mqh |
//|                                    Copyright 2025, a4Trading |
//|                                        www.a4trading.com     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| EMA System Functions - Enhanced Multi-EMA Analysis              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Main Entry Score                                      |
//+------------------------------------------------------------------+
double CalculateMainEntryScore()
{
    double score = 0.0;
    
    // 1. EMA Alignment (35% of main score)
    double emaAlignment = CalculateEMAAlignment();
    score += emaAlignment * InpEMAAlignmentWeight;
    
    // 2. Crossover Quality (25% of main score)
    double crossoverQuality = CalculateCrossoverQuality();
    score += crossoverQuality * InpCrossoverWeight;
    
    // 3. Price-EMA Relation (15% of main score)
    double priceEMARelation = CalculatePriceEMARelation();
    score += priceEMARelation * InpPriceEMAWeight;
    
    // 4. EMA Price Action (25% of main score)
    double emaPriceAction = CalculateEMAPriceAction();
    score += emaPriceAction * InpEMAPriceActionWeight;
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Calculate EMA Alignment Score (0.0 - 1.0)                      |
//+------------------------------------------------------------------+
double CalculateEMAAlignment()
{
    double score = 0.0;
    
    // Check if we have enough data
    if(ArraySize(g_FastEMABuffer) < 10 || 
       ArraySize(g_MediumEMABuffer) < 10 || 
       ArraySize(g_SlowEMABuffer) < 10)
        return 0.0;
    
    // Current EMA values
    double fastEMA = g_FastEMABuffer[0];
    double mediumEMA = g_MediumEMABuffer[0];
    double slowEMA = g_SlowEMABuffer[0];
    
    // 1. EMA Order Alignment (40% of score)
    double orderScore = 0.0;
    if(fastEMA > mediumEMA && mediumEMA > slowEMA)
        orderScore = 1.0; // Perfect bullish alignment
    else if(fastEMA < mediumEMA && mediumEMA < slowEMA)
        orderScore = 1.0; // Perfect bearish alignment
    else if(fastEMA > mediumEMA || mediumEMA > slowEMA)
        orderScore = 0.5; // Partial alignment
    
    score += orderScore * 0.40;
    
    // 2. EMA Rising/Falling Consistency (30% of score)
    double trendScore = 0.0;
    bool fastRising = IsEMARising(g_FastEMABuffer, 3);
    bool mediumRising = IsEMARising(g_MediumEMABuffer, 3);
    bool slowRising = IsEMARising(g_SlowEMABuffer, 5);
    
    if((fastRising && mediumRising && slowRising) || 
       (!fastRising && !mediumRising && !slowRising))
        trendScore = 1.0; // All EMAs trending same direction
    else if((fastRising && mediumRising) || (mediumRising && slowRising))
        trendScore = 0.7; // Majority trending same direction
    else if(fastRising == mediumRising || mediumRising == slowRising)
        trendScore = 0.4; // Some alignment
    
    score += trendScore * 0.30;
    
    // 3. EMA Spacing Quality (30% of score)
    double spacingScore = CalculateEMASpacing();
    score += spacingScore * 0.30;
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Check if EMA is Rising                                          |
//+------------------------------------------------------------------+
bool IsEMARising(double& emaArray[], int period)
{
    if(ArraySize(emaArray) < period + 1) return false;
    
    int risingCount = 0;
    for(int i = 0; i < period; i++)
    {
        if(emaArray[i] > emaArray[i + 1])
            risingCount++;
    }
    
    return (risingCount >= period * 0.7); // At least 70% of periods rising
}

//+------------------------------------------------------------------+
//| Calculate EMA Spacing Quality                                   |
//+------------------------------------------------------------------+
double CalculateEMASpacing()
{
    if(ArraySize(g_FastEMABuffer) < 2 || 
       ArraySize(g_MediumEMABuffer) < 2 || 
       ArraySize(g_SlowEMABuffer) < 2)
        return 0.0;
    
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double fastEMA = g_FastEMABuffer[0];
    double mediumEMA = g_MediumEMABuffer[0];
    double slowEMA = g_SlowEMABuffer[0];
    
    // Calculate spacing as percentage
    double fastMediumSpacing = MathAbs(fastEMA - mediumEMA) / currentPrice * 100;
    double mediumSlowSpacing = MathAbs(mediumEMA - slowEMA) / currentPrice * 100;
    
    // Optimal spacing is between 0.1% and 0.5% for each pair
    double spacingScore = 0.0;
    
    // Score fast-medium spacing
    if(fastMediumSpacing >= 0.05 && fastMediumSpacing <= 0.3)
        spacingScore += 0.5;
    else if(fastMediumSpacing >= 0.03 && fastMediumSpacing <= 0.5)
        spacingScore += 0.3;
    
    // Score medium-slow spacing
    if(mediumSlowSpacing >= 0.1 && mediumSlowSpacing <= 0.5)
        spacingScore += 0.5;
    else if(mediumSlowSpacing >= 0.05 && mediumSlowSpacing <= 0.8)
        spacingScore += 0.3;
    
    return MathMax(0.0, MathMin(1.0, spacingScore));
}

//+------------------------------------------------------------------+
//| Calculate Crossover Quality Score                               |
//+------------------------------------------------------------------+
double CalculateCrossoverQuality()
{
    if(ArraySize(g_FastEMABuffer) < 10 || ArraySize(g_MediumEMABuffer) < 10)
        return 0.0;
    
    double score = 0.0;
    
    // 1. Detect recent crossover (within last 3 bars)
    bool recentCrossover = false;
    bool bullishCrossover = false;
    
    for(int i = 0; i < 3; i++)
    {
        if(FastEMACrossedAbove(i) || FastEMACrossedBelow(i))
        {
            recentCrossover = true;
            bullishCrossover = FastEMACrossedAbove(i);
            break;
        }
    }
    
    if(!recentCrossover) return 0.0;
    
    // 2. Check convergence before crossover (20% of score)
    double convergenceScore = CalculateConvergenceQuality();
    score += convergenceScore * 0.20;
    
    // 3. Check volume at crossover (25% of score)
    double volumeScore = CalculateVolumeAtCrossover();
    score += volumeScore * 0.25;
    
    // 4. Check sustainability after crossover (30% of score)
    double sustainabilityScore = ValidateCrossoverSustainability();
    score += sustainabilityScore * 0.30;
    
    // 5. Check angle of crossover (25% of score)
    double angleScore = CalculateCrossoverAngle();
    score += angleScore * 0.25;
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Check if Fast EMA crossed above Medium EMA at specific bar     |
//+------------------------------------------------------------------+
bool FastEMACrossedAbove(int barIndex = 0)
{
    if(ArraySize(g_FastEMABuffer) <= barIndex + 1 || 
       ArraySize(g_MediumEMABuffer) <= barIndex + 1)
        return false;
    
    return (g_FastEMABuffer[barIndex] > g_MediumEMABuffer[barIndex] && 
            g_FastEMABuffer[barIndex + 1] <= g_MediumEMABuffer[barIndex + 1]);
}

//+------------------------------------------------------------------+
//| Check if Fast EMA crossed below Medium EMA at specific bar     |
//+------------------------------------------------------------------+
bool FastEMACrossedBelow(int barIndex = 0)
{
    if(ArraySize(g_FastEMABuffer) <= barIndex + 1 || 
       ArraySize(g_MediumEMABuffer) <= barIndex + 1)
        return false;
    
    return (g_FastEMABuffer[barIndex] < g_MediumEMABuffer[barIndex] && 
            g_FastEMABuffer[barIndex + 1] >= g_MediumEMABuffer[barIndex + 1]);
}

//+------------------------------------------------------------------+
//| Calculate Convergence Quality before Crossover                  |
//+------------------------------------------------------------------+
double CalculateConvergenceQuality()
{
    if(ArraySize(g_FastEMABuffer) < 10 || ArraySize(g_MediumEMABuffer) < 10)
        return 0.0;
    
    // Look at convergence over last 5-10 bars
    double totalConvergence = 0.0;
    int periods = 5;
    
    for(int i = 1; i <= periods; i++)
    {
        double previousSpread = MathAbs(g_FastEMABuffer[i] - g_MediumEMABuffer[i]);
        double currentSpread = MathAbs(g_FastEMABuffer[i-1] - g_MediumEMABuffer[i-1]);
        
        if(previousSpread > 0 && currentSpread < previousSpread)
            totalConvergence += (previousSpread - currentSpread) / previousSpread;
    }
    
    return MathMax(0.0, MathMin(1.0, totalConvergence / periods));
}

//+------------------------------------------------------------------+
//| Calculate Volume at Crossover                                   |
//+------------------------------------------------------------------+
double CalculateVolumeAtCrossover()
{
    // Get volume data for last few bars
    double currentVolume = (double)iVolume(Symbol(), Period(), 0);
    
    // Calculate average volume over last 10 bars
    double avgVolume = 0.0;
    for(int i = 1; i <= 10; i++)
    {
        avgVolume += (double)iVolume(Symbol(), Period(), i);
    }
    avgVolume /= 10.0;
    
    if(avgVolume == 0) return 0.5; // Default score if no volume data
    
    double volumeRatio = currentVolume / avgVolume;
    
    // Score based on volume increase
    if(volumeRatio >= 1.5) return 1.0;      // 50%+ volume increase
    else if(volumeRatio >= 1.2) return 0.8;  // 20%+ volume increase
    else if(volumeRatio >= 1.0) return 0.6;  // Above average volume
    else if(volumeRatio >= 0.8) return 0.4;  // Slightly below average
    else return 0.2; // Low volume
}

//+------------------------------------------------------------------+
//| Validate Crossover Sustainability                               |
//+------------------------------------------------------------------+
double ValidateCrossoverSustainability()
{
    if(ArraySize(g_FastEMABuffer) < 5 || ArraySize(g_MediumEMABuffer) < 5)
        return 0.0;
    
    // Check if EMAs continue in crossover direction
    bool isBullishCrossover = g_FastEMABuffer[0] > g_MediumEMABuffer[0];
    double sustainabilityScore = 0.0;
    
    // Check momentum continuation (3 bars after crossover)
    int confirmationBars = 0;
    for(int i = 0; i < 3; i++)
    {
        if(isBullishCrossover && g_FastEMABuffer[i] > g_MediumEMABuffer[i])
            confirmationBars++;
        else if(!isBullishCrossover && g_FastEMABuffer[i] < g_MediumEMABuffer[i])
            confirmationBars++;
    }
    
    sustainabilityScore = (double)confirmationBars / 3.0;
    
    // Check if distance is increasing
    double currentDistance = MathAbs(g_FastEMABuffer[0] - g_MediumEMABuffer[0]);
    double previousDistance = MathAbs(g_FastEMABuffer[1] - g_MediumEMABuffer[1]);
    
    if(currentDistance > previousDistance)
        sustainabilityScore += 0.2; // Bonus for increasing separation
    
    return MathMax(0.0, MathMin(1.0, sustainabilityScore));
}

//+------------------------------------------------------------------+
//| Calculate Crossover Angle                                       |
//+------------------------------------------------------------------+
double CalculateCrossoverAngle()
{
    if(ArraySize(g_FastEMABuffer) < 5 || ArraySize(g_MediumEMABuffer) < 5)
        return 0.0;
    
    // Calculate slope of both EMAs
    double fastSlope = (g_FastEMABuffer[0] - g_FastEMABuffer[2]) / 2.0;
    double mediumSlope = (g_MediumEMABuffer[0] - g_MediumEMABuffer[2]) / 2.0;
    
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double fastSlopePercent = (fastSlope / currentPrice) * 10000; // Convert to percentage
    double mediumSlopePercent = (mediumSlope / currentPrice) * 10000;
    
    // Calculate angle between slopes
    double angleDifference = MathAbs(fastSlopePercent - mediumSlopePercent);
    
    // Score based on angle - steeper is better for momentum
    if(angleDifference >= 5.0) return 1.0;      // Very steep angle
    else if(angleDifference >= 3.0) return 0.8;  // Good angle
    else if(angleDifference >= 1.5) return 0.6;  // Moderate angle
    else if(angleDifference >= 0.5) return 0.4;  // Shallow angle
    else return 0.2; // Very shallow
}

//+------------------------------------------------------------------+
//| Calculate Price-EMA Relationship Score                          |
//+------------------------------------------------------------------+
double CalculatePriceEMARelation()
{
    if(ArraySize(g_SlowEMABuffer) < 5) return 0.0;
    
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double slowEMA = g_SlowEMABuffer[0];
    double score = 0.0;
    
    // 1. Distance from Slow EMA (40% of score)
    double distanceScore = CalculateOptimalEMADistance(currentPrice, slowEMA);
    score += distanceScore * 0.40;
    
    // 2. Price Bouncing from EMA (30% of score)
    double bounceScore = IsPriceBouncing(slowEMA) ? 1.0 : 0.0;
    score += bounceScore * 0.30;
    
    // 3. Price Respecting EMA Level (30% of score)
    double respectScore = IsPriceRespecting(slowEMA) ? 1.0 : 0.0;
    score += respectScore * 0.30;
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Calculate EMA Price Action                                      |
//+------------------------------------------------------------------+
double CalculateEMAPriceAction()
{
    // This is a placeholder for EMA-based price action analysis
    // In a full implementation, this would analyze price action relative to EMAs
    return 0.5; // Neutral score for now
}

//+------------------------------------------------------------------+
//| Calculate Optimal EMA Distance                                  |
//+------------------------------------------------------------------+
double CalculateOptimalEMADistance(double price, double emaLevel)
{
    if(emaLevel == 0) return 0.0;
    
    double distance = MathAbs(price - emaLevel) / emaLevel * 100; // Percentage distance
    
    // Optimal distance is 0.1% to 0.8% from EMA
    if(distance >= 0.05 && distance <= 0.5) return 1.0;      // Perfect distance
    else if(distance >= 0.02 && distance <= 0.8) return 0.8;  // Good distance
    else if(distance >= 0.01 && distance <= 1.2) return 0.6;  // Acceptable distance
    else if(distance >= 0.005 && distance <= 2.0) return 0.4; // Far but okay
    else return 0.2; // Too close or too far
}

//+------------------------------------------------------------------+
//| Check if Price is Bouncing from EMA                            |
//+------------------------------------------------------------------+
bool IsPriceBouncing(double emaLevel)
{
    // Check if price recently touched EMA and bounced
    for(int i = 0; i < 3; i++)
    {
        double high = iHigh(Symbol(), Period(), i);
        double low = iLow(Symbol(), Period(), i);
        double close = iClose(Symbol(), Period(), i);
        
        // Check if price touched EMA level
        if((low <= emaLevel && close > emaLevel) || // Bullish bounce
           (high >= emaLevel && close < emaLevel))   // Bearish bounce
        {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check if Price is Respecting EMA Level                         |
//+------------------------------------------------------------------+
bool IsPriceRespecting(double emaLevel)
{
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    
    // Check price behavior around EMA over last 5 bars
    int respectCount = 0;
    bool isAboveEMA = currentPrice > emaLevel;
    
    for(int i = 0; i < 5; i++)
    {
        double close = iClose(Symbol(), Period(), i);
        
        if(isAboveEMA && close > emaLevel) respectCount++;
        else if(!isAboveEMA && close < emaLevel) respectCount++;
    }
    
    return (respectCount >= 4); // Price respected EMA in 80% of recent bars
}

//+------------------------------------------------------------------+
//| Update Dynamic EMA Periods Based on Volatility                 |
//+------------------------------------------------------------------+
void UpdateDynamicEMAPeriods()
{
    if(!InpUseDynamicEMAPeriods) return;
    
    // Get current volatility
    double atr[1];
    if(CopyBuffer(g_ATRHandle, 0, 0, 1, atr) <= 0) return;
    
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double volatilityPercent = (atr[0] / currentPrice) * 100;
    
    // Adjust EMA periods based on volatility
    int newFastPeriod, newMediumPeriod, newSlowPeriod;
    
    if(volatilityPercent > 1.5) // High volatility
    {
        newFastPeriod = 15;
        newMediumPeriod = 34;
        newSlowPeriod = 89;
    }
    else if(volatilityPercent > 0.8) // Medium volatility
    {
        newFastPeriod = 12;
        newMediumPeriod = 26;
        newSlowPeriod = 50;
    }
    else // Low volatility
    {
        newFastPeriod = 8;
        newMediumPeriod = 21;
        newSlowPeriod = 45;
    }
    
    // Recreate handles if periods changed significantly
    static int lastFastPeriod = InpFastEMAPeriod;
    static int lastMediumPeriod = InpMediumEMAPeriod;
    static int lastSlowPeriod = InpSlowEMAPeriod;
    
    if(MathAbs(newFastPeriod - lastFastPeriod) > 2 ||
       MathAbs(newMediumPeriod - lastMediumPeriod) > 3 ||
       MathAbs(newSlowPeriod - lastSlowPeriod) > 5)
    {
        // Release old handles
        if(g_FastEMAHandle != INVALID_HANDLE) IndicatorRelease(g_FastEMAHandle);
        if(g_MediumEMAHandle != INVALID_HANDLE) IndicatorRelease(g_MediumEMAHandle);
        if(g_SlowEMAHandle != INVALID_HANDLE) IndicatorRelease(g_SlowEMAHandle);
        
        // Create new handles
        g_FastEMAHandle = iMA(Symbol(), Period(), newFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
        g_MediumEMAHandle = iMA(Symbol(), Period(), newMediumPeriod, 0, MODE_EMA, PRICE_CLOSE);
        g_SlowEMAHandle = iMA(Symbol(), Period(), newSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
        
        lastFastPeriod = newFastPeriod;
        lastMediumPeriod = newMediumPeriod;
        lastSlowPeriod = newSlowPeriod;
    }
}

//+------------------------------------------------------------------+
//| Initialize Technical Indicators                                 |
//+------------------------------------------------------------------+
bool InitializeTechnicalIndicators()
{
    g_ATRHandle = iATR(Symbol(), Period(), InpATRPeriod);
    g_ADXHandle = iADX(Symbol(), Period(), InpADXPeriod);
    g_RSIHandle = iRSI(Symbol(), Period(), InpRSIPeriod, PRICE_CLOSE);
    g_StochasticHandle = iStochastic(Symbol(), Period(), InpStochasticKPeriod, InpStochasticDPeriod, 3, MODE_SMA, STO_LOWHIGH);
    g_WilliamsRHandle = iWPR(Symbol(), Period(), InpWilliamsRPeriod);
    g_MACDHandle = iMACD(Symbol(), Period(), InpMACDFastEMA, InpMACDSlowEMA, InpMACDSignalSMA, PRICE_CLOSE);
    
    return (g_ATRHandle != INVALID_HANDLE && 
            g_ADXHandle != INVALID_HANDLE && 
            g_RSIHandle != INVALID_HANDLE && 
            g_StochasticHandle != INVALID_HANDLE && 
            g_WilliamsRHandle != INVALID_HANDLE && 
            g_MACDHandle != INVALID_HANDLE);
}

//+------------------------------------------------------------------+
//| Check if we have bullish EMA setup                             |
//+------------------------------------------------------------------+
bool IsBullishEMASetup()
{
    if(ArraySize(g_FastEMABuffer) < 2 || 
       ArraySize(g_MediumEMABuffer) < 2 || 
       ArraySize(g_SlowEMABuffer) < 2)
        return false;
    
    return (g_FastEMABuffer[0] > g_MediumEMABuffer[0] && 
            g_MediumEMABuffer[0] > g_SlowEMABuffer[0] &&
            IsEMARising(g_FastEMABuffer, 2) &&
            IsEMARising(g_MediumEMABuffer, 3));
}

//+------------------------------------------------------------------+
//| Check if we have bearish EMA setup                             |
//+------------------------------------------------------------------+
bool IsBearishEMASetup()
{
    if(ArraySize(g_FastEMABuffer) < 2 || 
       ArraySize(g_MediumEMABuffer) < 2 || 
       ArraySize(g_SlowEMABuffer) < 2)
        return false;
    
    return (g_FastEMABuffer[0] < g_MediumEMABuffer[0] && 
            g_MediumEMABuffer[0] < g_SlowEMABuffer[0] &&
            !IsEMARising(g_FastEMABuffer, 2) &&
            !IsEMARising(g_MediumEMABuffer, 3));
}

//+------------------------------------------------------------------+
//| Get Signal Direction                                            |
//+------------------------------------------------------------------+
SIGNAL_TYPE GetSignalDirection(double mainEntry, double aiScore, double paScore)
{
    // Check EMA alignment for direction
    bool bullishEMA = IsBullishEMASetup();
    bool bearishEMA = IsBearishEMASetup();
    
    // Check AI signals if enabled
    bool bullishAI = InpEnableAIScoring ? IsBullishAISignal() : true;
    bool bearishAI = InpEnableAIScoring ? IsBearishAISignal() : true;
    
    // Check price action signals if enabled
    bool bullishPA = InpEnablePriceAction ? IsBullishPriceAction() : true;
    bool bearishPA = InpEnablePriceAction ? IsBearishPriceAction() : true;
    
    // Determine final direction
    if(bullishEMA && bullishAI && bullishPA)
        return SIGNAL_BUY;
    else if(bearishEMA && bearishAI && bearishPA)
        return SIGNAL_SELL;
    else
        return SIGNAL_NONE;
}