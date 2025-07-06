//+------------------------------------------------------------------+
//|                                     a4_AIScoringFunctions.mqh |
//|                                    Copyright 2025, a4Trading |
//|                                        www.a4trading.com     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| AI Scoring System Functions - Enhanced Technical Analysis       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Enhanced AI Score                                     |
//+------------------------------------------------------------------+
double CalculateEnhancedAIScore()
{
    if(!InpEnableAIScoring) return 0.5; // Neutral score if disabled
    
    double score = 0.0;
    
    // 1. Momentum Cluster Analysis (40% of AI score)
    double momentumScore = CalculateMomentumEnsemble();
    score += momentumScore * 0.40;
    
    // 2. Trend Cluster Analysis (35% of AI score)
    double trendScore = CalculateTrendEnsemble();
    score += trendScore * 0.35;
    
    // 3. Volume Cluster Analysis (25% of AI score)
    double volumeScore = CalculateVolumeEnsemble();
    score += volumeScore * 0.25;
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Calculate Momentum Ensemble Score                               |
//+------------------------------------------------------------------+
double CalculateMomentumEnsemble()
{
    double score = 0.0;
    int validIndicators = 0;
    
    // 1. RSI Analysis (25% of momentum score)
    double rsiScore = ScoreRSIContinuous();
    if(rsiScore >= 0.0)
    {
        score += rsiScore * 0.25;
        validIndicators++;
    }
    
    // 2. Stochastic Analysis (25% of momentum score)
    double stochasticScore = ScoreStochasticContinuous();
    if(stochasticScore >= 0.0)
    {
        score += stochasticScore * 0.25;
        validIndicators++;
    }
    
    // 3. Williams %R Analysis (25% of momentum score)
    double williamsScore = ScoreWilliamsRContinuous();
    if(williamsScore >= 0.0)
    {
        score += williamsScore * 0.25;
        validIndicators++;
    }
    
    // 4. Rate of Change Analysis (25% of momentum score)
    double rocScore = ScoreROCContinuous();
    if(rocScore >= 0.0)
    {
        score += rocScore * 0.25;
        validIndicators++;
    }
    
    // Return weighted average if we have valid indicators
    return validIndicators > 0 ? score * (4.0 / validIndicators) : 0.5;
}

//+------------------------------------------------------------------+
//| Calculate Trend Ensemble Score                                  |
//+------------------------------------------------------------------+
double CalculateTrendEnsemble()
{
    double score = 0.0;
    int validIndicators = 0;
    
    // 1. MACD Analysis (40% of trend score)
    double macdScore = ScoreMACDTrend();
    if(macdScore >= 0.0)
    {
        score += macdScore * 0.40;
        validIndicators++;
    }
    
    // 2. ADX Analysis (35% of trend score)
    double adxScore = ScoreADXTrend();
    if(adxScore >= 0.0)
    {
        score += adxScore * 0.35;
        validIndicators++;
    }
    
    // 3. Parabolic SAR Analysis (25% of trend score)
    double sarScore = ScoreParabolicSAR();
    if(sarScore >= 0.0)
    {
        score += sarScore * 0.25;
        validIndicators++;
    }
    
    // Return weighted average if we have valid indicators
    return validIndicators > 0 ? score * (validIndicators == 3 ? 1.0 : validIndicators == 2 ? 1.2 : 1.6) : 0.5;
}

//+------------------------------------------------------------------+
//| Calculate Volume Ensemble Score                                 |
//+------------------------------------------------------------------+
double CalculateVolumeEnsemble()
{
    double score = 0.0;
    int validIndicators = 0;
    
    // 1. On Balance Volume Analysis (40% of volume score)
    double obvScore = ScoreOBV();
    if(obvScore >= 0.0)
    {
        score += obvScore * 0.40;
        validIndicators++;
    }
    
    // 2. Volume Rate of Change (35% of volume score)
    double volumeROCScore = ScoreVolumeROC();
    if(volumeROCScore >= 0.0)
    {
        score += volumeROCScore * 0.35;
        validIndicators++;
    }
    
    // 3. Volume Confirmation (25% of volume score)
    double volumeConfirmScore = ScoreVolumeConfirmation();
    if(volumeConfirmScore >= 0.0)
    {
        score += volumeConfirmScore * 0.25;
        validIndicators++;
    }
    
    // Return weighted average if we have valid indicators
    return validIndicators > 0 ? score * (validIndicators == 3 ? 1.0 : validIndicators == 2 ? 1.2 : 1.6) : 0.5;
}

//+------------------------------------------------------------------+
//| RSI Continuous Scoring (0.0 - 1.0)                            |
//+------------------------------------------------------------------+
double ScoreRSIContinuous()
{
    double rsiBuffer[5];
    
    if(CopyBuffer(g_RSIHandle, 0, 0, 5, rsiBuffer) <= 0)
        return -1.0; // Invalid data
    
    double currentRSI = rsiBuffer[0];
    double score = 0.0;
    
    // 1. RSI Level Score (50% of RSI score)
    double levelScore = 0.0;
    if(currentRSI >= 45 && currentRSI <= 55)
        levelScore = 1.0; // Neutral - best for trend continuation
    else if(currentRSI >= 40 && currentRSI <= 60)
        levelScore = 0.8; // Good range
    else if(currentRSI >= 35 && currentRSI <= 65)
        levelScore = 0.6; // Acceptable range
    else if(currentRSI >= 30 && currentRSI <= 70)
        levelScore = 0.4; // Approaching extremes
    else if(currentRSI >= 25 && currentRSI <= 75)
        levelScore = 0.2; // Extreme but could reverse
    else
        levelScore = 0.1; // Very extreme
    
    score += levelScore * 0.50;
    
    // 2. RSI Momentum Score (30% of RSI score)
    double momentumScore = 0.0;
    if(ArraySize(rsiBuffer) >= 3)
    {
        bool rising = rsiBuffer[0] > rsiBuffer[1] && rsiBuffer[1] > rsiBuffer[2];
        bool falling = rsiBuffer[0] < rsiBuffer[1] && rsiBuffer[1] < rsiBuffer[2];
        
        if(rising && currentRSI > 50)
            momentumScore = 1.0; // Strong bullish momentum
        else if(falling && currentRSI < 50)
            momentumScore = 1.0; // Strong bearish momentum
        else if(rising || falling)
            momentumScore = 0.7; // Some momentum
        else
            momentumScore = 0.3; // No clear momentum
    }
    
    score += momentumScore * 0.30;
    
    // 3. RSI Divergence Detection (20% of RSI score)
    double divergenceScore = DetectRSIDivergence();
    score += divergenceScore * 0.20;
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Stochastic Continuous Scoring                                  |
//+------------------------------------------------------------------+
double ScoreStochasticContinuous()
{
    double stochKBuffer[5], stochDBuffer[5];
    
    if(CopyBuffer(g_StochasticHandle, MAIN_LINE, 0, 5, stochKBuffer) <= 0 ||
       CopyBuffer(g_StochasticHandle, SIGNAL_LINE, 0, 5, stochDBuffer) <= 0)
        return -1.0; // Invalid data
    
    double currentK = stochKBuffer[0];
    double currentD = stochDBuffer[0];
    double score = 0.0;
    
    // 1. Stochastic Level Score (40% of stochastic score)
    double levelScore = 0.0;
    if(currentK >= 40 && currentK <= 60)
        levelScore = 1.0; // Good middle range
    else if(currentK >= 30 && currentK <= 70)
        levelScore = 0.8; // Acceptable range
    else if(currentK >= 20 && currentK <= 80)
        levelScore = 0.6; // Getting extreme
    else if(currentK >= 15 && currentK <= 85)
        levelScore = 0.4; // Very extreme
    else
        levelScore = 0.2; // Extremely overbought/oversold
    
    score += levelScore * 0.40;
    
    // 2. K/D Crossover Score (35% of stochastic score)
    double crossoverScore = 0.0;
    if(ArraySize(stochKBuffer) >= 2 && ArraySize(stochDBuffer) >= 2)
    {
        bool kCrossedAboveD = (currentK > currentD) && (stochKBuffer[1] <= stochDBuffer[1]);
        bool kCrossedBelowD = (currentK < currentD) && (stochKBuffer[1] >= stochDBuffer[1]);
        
        if(kCrossedAboveD && currentK < 80)
            crossoverScore = 1.0; // Bullish crossover not overbought
        else if(kCrossedBelowD && currentK > 20)
            crossoverScore = 1.0; // Bearish crossover not oversold
        else if(currentK > currentD && currentK > 50)
            crossoverScore = 0.7; // K above D in bullish territory
        else if(currentK < currentD && currentK < 50)
            crossoverScore = 0.7; // K below D in bearish territory
        else
            crossoverScore = 0.4; // Mixed signals
    }
    
    score += crossoverScore * 0.35;
    
    // 3. Stochastic Momentum (25% of stochastic score)
    double momentumScore = 0.0;
    if(ArraySize(stochKBuffer) >= 3)
    {
        bool kRising = stochKBuffer[0] > stochKBuffer[1] && stochKBuffer[1] > stochKBuffer[2];
        bool kFalling = stochKBuffer[0] < stochKBuffer[1] && stochKBuffer[1] < stochKBuffer[2];
        
        if(kRising && currentK > currentD)
            momentumScore = 1.0;
        else if(kFalling && currentK < currentD)
            momentumScore = 1.0;
        else if(kRising || kFalling)
            momentumScore = 0.6;
        else
            momentumScore = 0.3;
    }
    
    score += momentumScore * 0.25;
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Williams %R Continuous Scoring                                 |
//+------------------------------------------------------------------+
double ScoreWilliamsRContinuous()
{
    double williamsBuffer[5];
    
    if(CopyBuffer(g_WilliamsRHandle, 0, 0, 5, williamsBuffer) <= 0)
        return -1.0; // Invalid data
    
    double currentWilliams = williamsBuffer[0];
    double score = 0.0;
    
    // Williams %R is typically negative, ranging from 0 to -100
    // Convert to positive scale for easier analysis
    double adjustedWilliams = MathAbs(currentWilliams);
    
    // 1. Williams %R Level Score (60% of Williams score)
    double levelScore = 0.0;
    if(adjustedWilliams >= 40 && adjustedWilliams <= 60)
        levelScore = 1.0; // Middle range - good for trend continuation
    else if(adjustedWilliams >= 30 && adjustedWilliams <= 70)
        levelScore = 0.8; // Good range
    else if(adjustedWilliams >= 20 && adjustedWilliams <= 80)
        levelScore = 0.6; // Acceptable range
    else if(adjustedWilliams >= 15 && adjustedWilliams <= 85)
        levelScore = 0.4; // Getting extreme
    else
        levelScore = 0.2; // Very extreme
    
    score += levelScore * 0.60;
    
    // 2. Williams %R Momentum (40% of Williams score)
    double momentumScore = 0.0;
    if(ArraySize(williamsBuffer) >= 3)
    {
        bool rising = williamsBuffer[0] > williamsBuffer[1] && williamsBuffer[1] > williamsBuffer[2];
        bool falling = williamsBuffer[0] < williamsBuffer[1] && williamsBuffer[1] < williamsBuffer[2];
        
        // Remember Williams %R is inverted (higher values = more bearish)
        if(rising && adjustedWilliams < 50) // Rising from oversold
            momentumScore = 1.0;
        else if(falling && adjustedWilliams > 50) // Falling from overbought
            momentumScore = 1.0;
        else if(rising || falling)
            momentumScore = 0.6;
        else
            momentumScore = 0.3;
    }
    
    score += momentumScore * 0.40;
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Rate of Change Continuous Scoring                              |
//+------------------------------------------------------------------+
double ScoreROCContinuous()
{
    // Calculate ROC manually since it's not always available as a standard indicator
    double rocValue = CalculateROC(InpROCPeriod);
    if(rocValue == EMPTY_VALUE) return -1.0;
    
    double score = 0.0;
    
    // 1. ROC Level Score (50% of ROC score)
    double levelScore = 0.0;
    double absROC = MathAbs(rocValue);
    
    if(absROC >= 0.1 && absROC <= 0.5)
        levelScore = 1.0; // Good momentum range
    else if(absROC >= 0.05 && absROC <= 1.0)
        levelScore = 0.8; // Acceptable momentum
    else if(absROC >= 0.02 && absROC <= 2.0)
        levelScore = 0.6; // Some momentum
    else if(absROC <= 0.02)
        levelScore = 0.3; // Very low momentum
    else
        levelScore = 0.4; // Very high momentum - could be unstable
    
    score += levelScore * 0.50;
    
    // 2. ROC Direction Score (50% of ROC score)
    double directionScore = 0.0;
    
    // Calculate ROC trend
    double prevROC = CalculateROC(InpROCPeriod, 1);
    if(prevROC != EMPTY_VALUE)
    {
        if(rocValue > 0 && rocValue > prevROC)
            directionScore = 1.0; // Increasing positive momentum
        else if(rocValue < 0 && rocValue < prevROC)
            directionScore = 1.0; // Increasing negative momentum
        else if(rocValue > 0)
            directionScore = 0.7; // Positive but weakening
        else if(rocValue < 0)
            directionScore = 0.7; // Negative but weakening
        else
            directionScore = 0.2; // No momentum
    }
    else
    {
        directionScore = rocValue > 0 ? 0.6 : rocValue < 0 ? 0.6 : 0.2;
    }
    
    score += directionScore * 0.50;
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Calculate Rate of Change                                        |
//+------------------------------------------------------------------+
double CalculateROC(int period, int shift = 0)
{
    if(Bars(Symbol(), Period()) < period + shift + 1)
        return EMPTY_VALUE;
    
    double currentPrice = iClose(Symbol(), Period(), shift);
    double pastPrice = iClose(Symbol(), Period(), shift + period);
    
    if(pastPrice == 0) return EMPTY_VALUE;
    
    return ((currentPrice - pastPrice) / pastPrice) * 100.0;
}

//+------------------------------------------------------------------+
//| MACD Trend Scoring                                             |
//+------------------------------------------------------------------+
double ScoreMACDTrend()
{
    double macdBuffer[5], signalBuffer[5];
    
    if(CopyBuffer(g_MACDHandle, MAIN_LINE, 0, 5, macdBuffer) <= 0 ||
       CopyBuffer(g_MACDHandle, SIGNAL_LINE, 0, 5, signalBuffer) <= 0)
        return -1.0; // Invalid data
    
    double currentMACD = macdBuffer[0];
    double currentSignal = signalBuffer[0];
    double score = 0.0;
    
    // 1. MACD vs Signal Line (40% of MACD score)
    double crossoverScore = 0.0;
    if(ArraySize(macdBuffer) >= 2 && ArraySize(signalBuffer) >= 2)
    {
        bool macdAboveSignal = currentMACD > currentSignal;
        bool recentCrossover = (currentMACD > currentSignal) != (macdBuffer[1] > signalBuffer[1]);
        
        if(recentCrossover && macdAboveSignal)
            crossoverScore = 1.0; // Recent bullish crossover
        else if(recentCrossover && !macdAboveSignal)
            crossoverScore = 1.0; // Recent bearish crossover
        else if(macdAboveSignal && currentMACD > 0)
            crossoverScore = 0.8; // MACD above signal and zero
        else if(!macdAboveSignal && currentMACD < 0)
            crossoverScore = 0.8; // MACD below signal and zero
        else if(macdAboveSignal)
            crossoverScore = 0.6; // MACD above signal
        else
            crossoverScore = 0.6; // MACD below signal
    }
    
    score += crossoverScore * 0.40;
    
    // 2. MACD vs Zero Line (30% of MACD score)
    double zeroLineScore = 0.0;
    if(currentMACD > 0)
        zeroLineScore = 0.8; // Above zero - bullish
    else
        zeroLineScore = 0.8; // Below zero - bearish
    
    // Bonus for distance from zero
    double macdDistance = MathAbs(currentMACD);
    if(macdDistance > 0.0001) // Significant distance from zero
        zeroLineScore += 0.2;
    
    score += zeroLineScore * 0.30;
    
    // 3. MACD Momentum (30% of MACD score)
    double momentumScore = 0.0;
    if(ArraySize(macdBuffer) >= 3)
    {
        bool macdRising = macdBuffer[0] > macdBuffer[1] && macdBuffer[1] > macdBuffer[2];
        bool macdFalling = macdBuffer[0] < macdBuffer[1] && macdBuffer[1] < macdBuffer[2];
        
        if(macdRising && currentMACD > currentSignal)
            momentumScore = 1.0; // Strong bullish momentum
        else if(macdFalling && currentMACD < currentSignal)
            momentumScore = 1.0; // Strong bearish momentum
        else if(macdRising || macdFalling)
            momentumScore = 0.6; // Some momentum
        else
            momentumScore = 0.3; // No clear momentum
    }
    
    score += momentumScore * 0.30;
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| ADX Trend Scoring                                              |
//+------------------------------------------------------------------+
double ScoreADXTrend()
{
    double adxBuffer[5], plusDIBuffer[5], minusDIBuffer[5];
    
    if(CopyBuffer(g_ADXHandle, MAIN_LINE, 0, 5, adxBuffer) <= 0 ||
       CopyBuffer(g_ADXHandle, PLUSDI_LINE, 0, 5, plusDIBuffer) <= 0 ||
       CopyBuffer(g_ADXHandle, MINUSDI_LINE, 0, 5, minusDIBuffer) <= 0)
        return -1.0; // Invalid data
    
    double currentADX = adxBuffer[0];
    double currentPlusDI = plusDIBuffer[0];
    double currentMinusDI = minusDIBuffer[0];
    double score = 0.0;
    
    // 1. ADX Strength Level (40% of ADX score)
    double strengthScore = 0.0;
    if(currentADX > 40)
        strengthScore = 1.0; // Very strong trend
    else if(currentADX > 30)
        strengthScore = 0.9; // Strong trend
    else if(currentADX > 25)
        strengthScore = 0.8; // Good trend
    else if(currentADX > 20)
        strengthScore = 0.6; // Moderate trend
    else if(currentADX > 15)
        strengthScore = 0.4; // Weak trend
    else
        strengthScore = 0.2; // Very weak/no trend
    
    score += strengthScore * 0.40;
    
    // 2. DI Direction and Separation (35% of ADX score)
    double directionScore = 0.0;
    double diSeparation = MathAbs(currentPlusDI - currentMinusDI);
    
    if(diSeparation > 20)
        directionScore = 1.0; // Clear directional bias
    else if(diSeparation > 15)
        directionScore = 0.8; // Good directional bias
    else if(diSeparation > 10)
        directionScore = 0.6; // Some directional bias
    else if(diSeparation > 5)
        directionScore = 0.4; // Weak directional bias
    else
        directionScore = 0.2; // No clear direction
    
    score += directionScore * 0.35;
    
    // 3. ADX Momentum (25% of ADX score)
    double momentumScore = 0.0;
    if(ArraySize(adxBuffer) >= 3)
    {
        bool adxRising = adxBuffer[0] > adxBuffer[1] && adxBuffer[1] > adxBuffer[2];
        bool adxFalling = adxBuffer[0] < adxBuffer[1] && adxBuffer[1] < adxBuffer[2];
        
        if(adxRising && currentADX > 20)
            momentumScore = 1.0; // Strengthening trend
        else if(adxRising)
            momentumScore = 0.7; // Building trend
        else if(adxFalling && currentADX > 25)
            momentumScore = 0.6; // Weakening but still strong
        else if(adxFalling)
            momentumScore = 0.3; // Weakening trend
        else
            momentumScore = 0.5; // Stable trend
    }
    
    score += momentumScore * 0.25;
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Parabolic SAR Scoring                                          |
//+------------------------------------------------------------------+
double ScoreParabolicSAR()
{
    // Create Parabolic SAR handle if not exists
    static int sarHandle = INVALID_HANDLE;
    if(sarHandle == INVALID_HANDLE)
    {
        sarHandle = iSAR(Symbol(), Period(), 0.02, 0.2);
        if(sarHandle == INVALID_HANDLE) return -1.0;
    }
    
    double sarBuffer[5];
    
    if(CopyBuffer(sarHandle, 0, 0, 5, sarBuffer) <= 0)
        return -1.0; // Invalid data
    
    double currentSAR = sarBuffer[0];
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double score = 0.0;
    
    // 1. Price vs SAR Position (70% of SAR score)
    double positionScore = 0.0;
    if(currentPrice > currentSAR)
        positionScore = 1.0; // Price above SAR - bullish
    else
        positionScore = 1.0; // Price below SAR - bearish
    
    score += positionScore * 0.70;
    
    // 2. SAR Trend Consistency (30% of SAR score)
    double consistencyScore = 0.0;
    if(ArraySize(sarBuffer) >= 3)
    {
        bool sarDescending = sarBuffer[0] < sarBuffer[1] && sarBuffer[1] < sarBuffer[2];
        bool sarAscending = sarBuffer[0] > sarBuffer[1] && sarBuffer[1] > sarBuffer[2];
        
        if((currentPrice > currentSAR && sarDescending) ||
           (currentPrice < currentSAR && sarAscending))
            consistencyScore = 1.0; // SAR trend consistent with price position
        else
            consistencyScore = 0.5; // Mixed signals
    }
    
    score += consistencyScore * 0.30;
    
    return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Volume Analysis Functions                                       |
//+------------------------------------------------------------------+

double ScoreOBV()
{
    // Calculate OBV manually
    double obvValue = CalculateOBV();
    if(obvValue == EMPTY_VALUE) return -1.0;
    
    // Get OBV trend
    double obvTrend = CalculateOBVTrend();
    
    double score = 0.0;
    
    // Score based on OBV trend alignment with price
    double currentPrice = iClose(Symbol(), Period(), 0);
    double previousPrice = iClose(Symbol(), Period(), 5);
    
    bool priceRising = currentPrice > previousPrice;
    bool obvRising = obvTrend > 0;
    
    if((priceRising && obvRising) || (!priceRising && !obvRising))
        score = 1.0; // OBV confirms price movement
    else
        score = 0.3; // OBV diverges from price
    
    return score;
}

double ScoreVolumeROC()
{
    double currentVolume = (double)iVolume(Symbol(), Period(), 0);
    double pastVolume = (double)iVolume(Symbol(), Period(), 5);
    
    if(pastVolume == 0) return -1.0;
    
    double volumeROC = ((currentVolume - pastVolume) / pastVolume) * 100.0;
    
    double score = 0.0;
    
    // Score based on volume increase
    if(volumeROC > 50) score = 1.0;      // Very high volume
    else if(volumeROC > 20) score = 0.8;  // High volume
    else if(volumeROC > 0) score = 0.6;   // Above average volume
    else if(volumeROC > -20) score = 0.4; // Below average volume
    else score = 0.2; // Very low volume
    
    return score;
}

double ScoreVolumeConfirmation()
{
    double currentVolume = (double)iVolume(Symbol(), Period(), 0);
    
    // Calculate average volume
    double avgVolume = 0.0;
    for(int i = 1; i <= 10; i++)
        avgVolume += (double)iVolume(Symbol(), Period(), i);
    avgVolume /= 10.0;
    
    if(avgVolume == 0) return 0.5;
    
    double volumeRatio = currentVolume / avgVolume;
    
    // Score based on volume confirmation
    if(volumeRatio >= 1.5) return 1.0;
    else if(volumeRatio >= 1.2) return 0.8;
    else if(volumeRatio >= 1.0) return 0.6;
    else if(volumeRatio >= 0.8) return 0.4;
    else return 0.2;
}

//+------------------------------------------------------------------+
//| Helper Functions                                                |
//+------------------------------------------------------------------+

double DetectRSIDivergence()
{
    // Simplified divergence detection
    // In a full implementation, this would be more sophisticated
    return 0.5; // Neutral score for now
}

double CalculateOBV()
{
    static double lastOBV = 0.0;
    static datetime lastTime = 0;
    
    datetime currentTime = iTime(Symbol(), Period(), 0);
    if(currentTime == lastTime) return lastOBV;
    
    double currentClose = iClose(Symbol(), Period(), 0);
    double previousClose = iClose(Symbol(), Period(), 1);
    double currentVolume = (double)iVolume(Symbol(), Period(), 0);
    
    if(currentClose > previousClose)
        lastOBV += currentVolume;
    else if(currentClose < previousClose)
        lastOBV -= currentVolume;
    
    lastTime = currentTime;
    return lastOBV;
}

double CalculateOBVTrend()
{
    double currentOBV = CalculateOBV();
    
    // Calculate OBV from 5 bars ago
    double pastClose1 = iClose(Symbol(), Period(), 5);
    double pastClose2 = iClose(Symbol(), Period(), 6);
    double pastVolume = (double)iVolume(Symbol(), Period(), 5);
    
    double pastOBVChange = 0.0;
    if(pastClose1 > pastClose2)
        pastOBVChange = pastVolume;
    else if(pastClose1 < pastClose2)
        pastOBVChange = -pastVolume;
    
    return currentOBV - pastOBVChange; // Simplified trend calculation
}

//+------------------------------------------------------------------+
//| AI Signal Direction Functions                                   |
//+------------------------------------------------------------------+
bool IsBullishAISignal()
{
    double momentumScore = CalculateMomentumEnsemble();
    double trendScore = CalculateTrendEnsemble();
    
    return (momentumScore > 0.6 && trendScore > 0.6);
}

bool IsBearishAISignal()
{
    double momentumScore = CalculateMomentumEnsemble();
    double trendScore = CalculateTrendEnsemble();
    
    return (momentumScore > 0.6 && trendScore > 0.6);
}