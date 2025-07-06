//+------------------------------------------------------------------+
//|                                a4_DynamicWeightsFunctions.mqh |
//|                                    Copyright 2025, a4Trading |
//|                                        www.a4trading.com     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Dynamic Weight Adaptation Functions                             |
//+------------------------------------------------------------------+

// Global Performance Tracking Variables
CTradeResult g_TradeResults[];
CTradeSetup g_TradeSetups[];
CComponentPerformance g_MainEntryPerformance;
CComponentPerformance g_AIPerformance;
CComponentPerformance g_PriceActionPerformance;

// Weight adjustment tracking
datetime g_LastWeightUpdate = 0;
int g_WeightUpdateInterval = 10; // Update weights every 10 trades

//+------------------------------------------------------------------+
//| Initialize Performance Tracking System                          |
//+------------------------------------------------------------------+
void InitializePerformanceTracking()
{
    ArrayResize(g_TradeResults, 0);
    ArrayResize(g_TradeSetups, 0);
    
    // Initialize component performance structures
    InitializeComponentPerformance(g_MainEntryPerformance);
    InitializeComponentPerformance(g_AIPerformance);
    InitializeComponentPerformance(g_PriceActionPerformance);
    
    // Load historical performance data if available
    LoadPerformanceData();
}

//+------------------------------------------------------------------+
//| Initialize Component Performance Structure                      |
//+------------------------------------------------------------------+
void InitializeComponentPerformance(CComponentPerformance& performance)
{
    performance.totalTrades = 0;
    performance.successfulTrades = 0;
    performance.totalProfit = 0.0;
    performance.successRate = 0.0;
    performance.avgProfit = 0.0;
    performance.avgLoss = 0.0;
    performance.profitFactor = 1.0;
    performance.lastUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Record Trade Setup for Performance Analysis                     |
//+------------------------------------------------------------------+
void StoreTradeSetup(CTradeSetup& setup)
{
    int newIndex = ArraySize(g_TradeSetups);
    ArrayResize(g_TradeSetups, newIndex + 1);
    g_TradeSetups[newIndex] = setup;
    
    // Keep only recent setups (limit to 500 records)
    if(ArraySize(g_TradeSetups) > 500)
    {
        int excess = ArraySize(g_TradeSetups) - 500;
        for(int i = 0; i < ArraySize(g_TradeSetups) - excess; i++)
        {
            g_TradeSetups[i] = g_TradeSetups[i + excess];
        }
        ArrayResize(g_TradeSetups, 500);
    }
}

//+------------------------------------------------------------------+
//| Record Trade Result                                             |
//+------------------------------------------------------------------+
void RecordTradeResult(CTradeResult& tradeResult)
{
    int newIndex = ArraySize(g_TradeResults);
    ArrayResize(g_TradeResults, newIndex + 1);
    g_TradeResults[newIndex] = tradeResult;
    
    // Update component performances
    UpdateComponentPerformances(tradeResult);
    
    // Keep only recent results (limit to performance tracking period)
    int maxResults = InpPerformanceTrackingPeriod * 2; // Keep 2x tracking period
    if(ArraySize(g_TradeResults) > maxResults)
    {
        int excess = ArraySize(g_TradeResults) - maxResults;
        for(int i = 0; i < ArraySize(g_TradeResults) - excess; i++)
        {
            g_TradeResults[i] = g_TradeResults[i + excess];
        }
        ArrayResize(g_TradeResults, maxResults);
    }
    
    // Check if it's time to update weights
    if(ArraySize(g_TradeResults) % g_WeightUpdateInterval == 0)
    {
        UpdateDynamicWeights();
    }
    
    // Save performance data
    SavePerformanceData();
}

//+------------------------------------------------------------------+
//| Update Component Performances                                   |
//+------------------------------------------------------------------+
void UpdateComponentPerformances(CTradeResult& tradeResult)
{
    // Find matching trade setup
    CTradeSetup matchingSetup;
    bool setupFound = false;
    
    for(int i = ArraySize(g_TradeSetups) - 1; i >= 0; i--)
    {
        if(MathAbs(g_TradeSetups[i].entryPrice - tradeResult.entryPrice) < SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 5 &&
           MathAbs(g_TradeSetups[i].timestamp - tradeResult.timestamp) < 3600) // Within 1 hour
        {
            matchingSetup = g_TradeSetups[i];
            setupFound = true;
            break;
        }
    }
    
    if(!setupFound) return; // Can't analyze without setup data
    
    // Update Main Entry Performance based on score contribution
    if(matchingSetup.mainEntryScore > 0.5) // Consider only when main entry was strong
    {
        UpdateComponentPerformance(g_MainEntryPerformance, tradeResult, matchingSetup.mainEntryScore);
    }
    
    // Update AI Performance based on score contribution
    if(matchingSetup.aiScore > 0.3) // Consider only when AI had meaningful contribution
    {
        UpdateComponentPerformance(g_AIPerformance, tradeResult, matchingSetup.aiScore);
    }
    
    // Update Price Action Performance based on score contribution
    if(matchingSetup.priceActionScore > 0.3) // Consider only when PA had meaningful contribution
    {
        UpdateComponentPerformance(g_PriceActionPerformance, tradeResult, matchingSetup.priceActionScore);
    }
}

//+------------------------------------------------------------------+
//| Update Individual Component Performance                         |
//+------------------------------------------------------------------+
void UpdateComponentPerformance(CComponentPerformance& performance, CTradeResult& tradeResult, double componentScore)
{
    performance.totalTrades++;
    if(tradeResult.success)
        performance.successfulTrades++;
    
    performance.totalProfit += tradeResult.profit;
    performance.successRate = (double)performance.successfulTrades / (double)performance.totalTrades;
    
    // Calculate weighted profit based on component contribution
    double weightedProfit = tradeResult.profit * componentScore;
    
    if(tradeResult.success && tradeResult.profit > 0)
    {
        if(performance.avgProfit == 0)
            performance.avgProfit = weightedProfit;
        else
            performance.avgProfit = (performance.avgProfit * 0.9) + (weightedProfit * 0.1); // Exponential moving average
    }
    else if(tradeResult.profit < 0)
    {
        if(performance.avgLoss == 0)
            performance.avgLoss = MathAbs(weightedProfit);
        else
            performance.avgLoss = (performance.avgLoss * 0.9) + (MathAbs(weightedProfit) * 0.1);
    }
    
    // Calculate profit factor
    if(performance.avgLoss > 0)
        performance.profitFactor = performance.avgProfit / performance.avgLoss;
    else
        performance.profitFactor = performance.avgProfit > 0 ? 2.0 : 1.0;
    
    performance.lastUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Calculate Component Success Rate                                |
//+------------------------------------------------------------------+
double CalculateComponentSuccessRate(int componentType, int periods)
{
    if(ArraySize(g_TradeResults) < 5) return 0.5; // Not enough data, return neutral
    
    int totalTrades = 0;
    int successfulTrades = 0;
    int startIndex = MathMax(0, ArraySize(g_TradeResults) - periods);
    
    for(int i = startIndex; i < ArraySize(g_TradeResults); i++)
    {
        CTradeResult tradeResult = g_TradeResults[i];
        
        // Find corresponding setup
        CTradeSetup setup;
        bool setupFound = false;
        
        for(int j = ArraySize(g_TradeSetups) - 1; j >= 0; j--)
        {
            if(MathAbs(g_TradeSetups[j].entryPrice - tradeResult.entryPrice) < SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 5)
            {
                setup = g_TradeSetups[j];
                setupFound = true;
                break;
            }
        }
        
        if(!setupFound) continue;
        
        // Check if component contributed significantly to the trade
        bool componentContributed = false;
        switch(componentType)
        {
            case 0: // Main Entry
                componentContributed = (setup.mainEntryScore > 0.5);
                break;
            case 1: // AI
                componentContributed = (setup.aiScore > 0.3);
                break;
            case 2: // Price Action
                componentContributed = (setup.priceActionScore > 0.3);
                break;
        }
        
        if(componentContributed)
        {
            totalTrades++;
            if(tradeResult.success)
                successfulTrades++;
        }
    }
    
    return totalTrades > 0 ? (double)successfulTrades / (double)totalTrades : 0.5;
}

//+------------------------------------------------------------------+
//| Update Dynamic Weights Based on Performance                     |
//+------------------------------------------------------------------+
void UpdateDynamicWeights()
{
    if(!InpEnableDynamicWeights) return;
    if(ArraySize(g_TradeResults) < 10) return; // Need minimum data
    
    // Calculate recent performance for each component
    double mainEntrySuccess = CalculateComponentSuccessRate(0, InpPerformanceTrackingPeriod);
    double aiSuccess = CalculateComponentSuccessRate(1, InpPerformanceTrackingPeriod);
    double priceActionSuccess = CalculateComponentSuccessRate(2, InpPerformanceTrackingPeriod);
    
    // Calculate performance multipliers
    double mainEntryMultiplier = CalculatePerformanceMultiplier(mainEntrySuccess);
    double aiMultiplier = CalculatePerformanceMultiplier(aiSuccess);
    double priceActionMultiplier = CalculatePerformanceMultiplier(priceActionSuccess);
    
    // Calculate new weights with gradual adjustment
    double newMainEntryWeight = InpBaseMainEntryWeight * mainEntryMultiplier;
    double newAIWeight = InpBaseAIWeight * aiMultiplier;
    double newPriceActionWeight = InpBasePriceActionWeight * priceActionMultiplier;
    
    // Apply maximum deviation limits
    newMainEntryWeight = MathMax(InpBaseMainEntryWeight - InpMaxWeightDeviation,
                                MathMin(InpBaseMainEntryWeight + InpMaxWeightDeviation, newMainEntryWeight));
    newAIWeight = MathMax(InpBaseAIWeight - InpMaxWeightDeviation,
                         MathMin(InpBaseAIWeight + InpMaxWeightDeviation, newAIWeight));
    newPriceActionWeight = MathMax(InpBasePriceActionWeight - InpMaxWeightDeviation,
                                  MathMin(InpBasePriceActionWeight + InpMaxWeightDeviation, newPriceActionWeight));
    
    // Gradual adjustment using adjustment speed
    g_DynamicMainEntryWeight = g_DynamicMainEntryWeight + 
                              (newMainEntryWeight - g_DynamicMainEntryWeight) * InpWeightAdjustmentSpeed;
    g_DynamicAIWeight = g_DynamicAIWeight + 
                       (newAIWeight - g_DynamicAIWeight) * InpWeightAdjustmentSpeed;
    g_DynamicPriceActionWeight = g_DynamicPriceActionWeight + 
                                (newPriceActionWeight - g_DynamicPriceActionWeight) * InpWeightAdjustmentSpeed;
    
    // Normalize weights to ensure they sum to 1.0
    NormalizeWeights();
    
    // Log weight changes
    PrintWeightUpdate();
    
    g_LastWeightUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Calculate Performance Multiplier                                |
//+------------------------------------------------------------------+
double CalculatePerformanceMultiplier(double successRate)
{
    // Base multiplier of 1.0 for 60% success rate
    double baseSuccessRate = 0.60;
    double multiplier = 1.0;
    
    if(successRate > baseSuccessRate)
    {
        // Increase weight for better performance
        double excess = successRate - baseSuccessRate;
        multiplier = 1.0 + (excess * 2.0); // Up to 1.8x for 100% success
    }
    else if(successRate < baseSuccessRate)
    {
        // Decrease weight for worse performance
        double shortfall = baseSuccessRate - successRate;
        multiplier = 1.0 - (shortfall * 1.5); // Down to 0.1x for 0% success
    }
    
    // Ensure multiplier stays within reasonable bounds
    return MathMax(0.2, MathMin(2.0, multiplier));
}

//+------------------------------------------------------------------+
//| Normalize Weights to Sum to 1.0                                |
//+------------------------------------------------------------------+
void NormalizeWeights()
{
    double totalWeight = g_DynamicMainEntryWeight + g_DynamicAIWeight + g_DynamicPriceActionWeight;
    
    if(totalWeight > 0)
    {
        g_DynamicMainEntryWeight /= totalWeight;
        g_DynamicAIWeight /= totalWeight;
        g_DynamicPriceActionWeight /= totalWeight;
    }
    else
    {
        // Reset to base weights if something went wrong
        g_DynamicMainEntryWeight = InpBaseMainEntryWeight;
        g_DynamicAIWeight = InpBaseAIWeight;
        g_DynamicPriceActionWeight = InpBasePriceActionWeight;
    }
}

//+------------------------------------------------------------------+
//| Print Weight Update Information                                 |
//+------------------------------------------------------------------+
void PrintWeightUpdate()
{
    Print("=== Dynamic Weight Update ===");
    Print("Main Entry Weight: ", DoubleToString(g_DynamicMainEntryWeight, 3), 
          " (Base: ", DoubleToString(InpBaseMainEntryWeight, 3), ")");
    Print("AI Weight: ", DoubleToString(g_DynamicAIWeight, 3), 
          " (Base: ", DoubleToString(InpBaseAIWeight, 3), ")");
    Print("Price Action Weight: ", DoubleToString(g_DynamicPriceActionWeight, 3), 
          " (Base: ", DoubleToString(InpBasePriceActionWeight, 3), ")");
    Print("Total Trades Analyzed: ", ArraySize(g_TradeResults));
    Print("Main Entry Success Rate: ", DoubleToString(CalculateComponentSuccessRate(0, InpPerformanceTrackingPeriod) * 100, 1), "%");
    Print("AI Success Rate: ", DoubleToString(CalculateComponentSuccessRate(1, InpPerformanceTrackingPeriod) * 100, 1), "%");
    Print("Price Action Success Rate: ", DoubleToString(CalculateComponentSuccessRate(2, InpPerformanceTrackingPeriod) * 100, 1), "%");
    Print("=============================");
}

//+------------------------------------------------------------------+
//| Get Current Performance Summary                                  |
//+------------------------------------------------------------------+
string GetPerformanceSummary()
{
    string summary = "";
    
    summary += "=== Performance Summary ===\n";
    summary += "Total Trades: " + IntegerToString(ArraySize(g_TradeResults)) + "\n";
    
    if(ArraySize(g_TradeResults) > 0)
    {
        int wins = 0;
        double totalProfit = 0.0;
        
        for(int i = 0; i < ArraySize(g_TradeResults); i++)
        {
            if(g_TradeResults[i].success) wins++;
            totalProfit += g_TradeResults[i].profit;
        }
        
        double winRate = (double)wins / (double)ArraySize(g_TradeResults) * 100.0;
        
        summary += "Win Rate: " + DoubleToString(winRate, 1) + "%\n";
        summary += "Total Profit: " + DoubleToString(totalProfit, 2) + "\n";
        summary += "Current Weights:\n";
        summary += "  Main Entry: " + DoubleToString(g_DynamicMainEntryWeight, 3) + "\n";
        summary += "  AI: " + DoubleToString(g_DynamicAIWeight, 3) + "\n";
        summary += "  Price Action: " + DoubleToString(g_DynamicPriceActionWeight, 3) + "\n";
    }
    
    summary += "===========================";
    
    return summary;
}

//+------------------------------------------------------------------+
//| Save Performance Data to File                                   |
//+------------------------------------------------------------------+
void SavePerformanceData()
{
    string filename = "a4TradingSystem_Performance_" + Symbol() + ".csv";
    int fileHandle = FileOpen(filename, FILE_WRITE | FILE_CSV);
    
    if(fileHandle != INVALID_HANDLE)
    {
        // Write header
        FileWrite(fileHandle, "Timestamp", "EntryPrice", "ExitPrice", "Profit", "Success", 
                 "MainEntryScore", "AIScore", "PriceActionScore", "FinalStrength", "SignalType");
        
        // Write trade results
        for(int i = 0; i < ArraySize(g_TradeResults); i++)
        {
            CTradeResult tradeResult = g_TradeResults[i];
            FileWrite(fileHandle, 
                     TimeToString(tradeResult.timestamp),
                     DoubleToString(tradeResult.entryPrice, Digits()),
                     DoubleToString(tradeResult.exitPrice, Digits()),
                     DoubleToString(tradeResult.profit, 2),
                     tradeResult.success ? "1" : "0",
                     DoubleToString(tradeResult.mainEntryScore, 3),
                     DoubleToString(tradeResult.aiScore, 3),
                     DoubleToString(tradeResult.priceActionScore, 3),
                     DoubleToString(tradeResult.finalStrength, 3),
                     IntegerToString(tradeResult.signalType));
        }
        
        FileClose(fileHandle);
    }
}

//+------------------------------------------------------------------+
//| Load Performance Data from File                                 |
//+------------------------------------------------------------------+
void LoadPerformanceData()
{
    string filename = "a4TradingSystem_Performance_" + Symbol() + ".csv";
    int fileHandle = FileOpen(filename, FILE_READ | FILE_CSV);
    
    if(fileHandle != INVALID_HANDLE)
    {
        // Skip header
        if(!FileIsEnding(fileHandle))
        {
            string header = FileReadString(fileHandle);
        }
        
        // Read trade results
        ArrayResize(g_TradeResults, 0);
        
        while(!FileIsEnding(fileHandle))
        {
            string timestampStr = FileReadString(fileHandle);
            if(timestampStr == "") break;
            
            CTradeResult tradeResult;
            tradeResult.timestamp = StringToTime(timestampStr);
            tradeResult.entryPrice = StringToDouble(FileReadString(fileHandle));
            tradeResult.exitPrice = StringToDouble(FileReadString(fileHandle));
            tradeResult.profit = StringToDouble(FileReadString(fileHandle));
            tradeResult.success = StringToInteger(FileReadString(fileHandle)) == 1;
            tradeResult.mainEntryScore = StringToDouble(FileReadString(fileHandle));
            tradeResult.aiScore = StringToDouble(FileReadString(fileHandle));
            tradeResult.priceActionScore = StringToDouble(FileReadString(fileHandle));
            tradeResult.finalStrength = StringToDouble(FileReadString(fileHandle));
            tradeResult.signalType = (SIGNAL_TYPE)StringToInteger(FileReadString(fileHandle));
            
            int newIndex = ArraySize(g_TradeResults);
            ArrayResize(g_TradeResults, newIndex + 1);
            g_TradeResults[newIndex] = tradeResult;
        }
        
        FileClose(fileHandle);
        
        Print("Loaded ", ArraySize(g_TradeResults), " historical trade results");
        
        // Update weights based on loaded data
        if(ArraySize(g_TradeResults) >= 10)
        {
            UpdateDynamicWeights();
        }
    }
}

//+------------------------------------------------------------------+
//| Analyze Component Correlation                                   |
//+------------------------------------------------------------------+
double AnalyzeComponentCorrelation(int component1, int component2)
{
    if(ArraySize(g_TradeResults) < 20) return 0.0; // Need enough data
    
    double sum1 = 0.0, sum2 = 0.0, sum1sq = 0.0, sum2sq = 0.0, psum = 0.0;
    int n = 0;
    
    for(int i = 0; i < ArraySize(g_TradeResults); i++)
    {
        // Find corresponding setup
        CTradeSetup setup;
        bool setupFound = false;
        
        for(int j = ArraySize(g_TradeSetups) - 1; j >= 0; j--)
        {
            if(MathAbs(g_TradeSetups[j].entryPrice - g_TradeResults[i].entryPrice) < 
               SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 5)
            {
                setup = g_TradeSetups[j];
                setupFound = true;
                break;
            }
        }
        
        if(!setupFound) continue;
        
        double score1 = 0.0, score2 = 0.0;
        
        // Get component scores
        switch(component1)
        {
            case 0: score1 = setup.mainEntryScore; break;
            case 1: score1 = setup.aiScore; break;
            case 2: score1 = setup.priceActionScore; break;
        }
        
        switch(component2)
        {
            case 0: score2 = setup.mainEntryScore; break;
            case 1: score2 = setup.aiScore; break;
            case 2: score2 = setup.priceActionScore; break;
        }
        
        sum1 += score1;
        sum2 += score2;
        sum1sq += score1 * score1;
        sum2sq += score2 * score2;
        psum += score1 * score2;
        n++;
    }
    
    if(n < 10) return 0.0;
    
    // Calculate correlation coefficient
    double numerator = psum - (sum1 * sum2 / n);
    double denominator = MathSqrt((sum1sq - sum1 * sum1 / n) * (sum2sq - sum2 * sum2 / n));
    
    return denominator != 0.0 ? numerator / denominator : 0.0;
}

//+------------------------------------------------------------------+
//| Reset Performance Data                                          |
//+------------------------------------------------------------------+
void ResetPerformanceData()
{
    ArrayResize(g_TradeResults, 0);
    ArrayResize(g_TradeSetups, 0);
    
    // Reset weights to base values
    g_DynamicMainEntryWeight = InpBaseMainEntryWeight;
    g_DynamicAIWeight = InpBaseAIWeight;
    g_DynamicPriceActionWeight = InpBasePriceActionWeight;
    
    // Initialize component performances
    InitializeComponentPerformance(g_MainEntryPerformance);
    InitializeComponentPerformance(g_AIPerformance);
    InitializeComponentPerformance(g_PriceActionPerformance);
    
    Print("Performance data reset to initial state");
}

//+------------------------------------------------------------------+
//| Check if Weight Update is Due                                   |
//+------------------------------------------------------------------+
bool IsWeightUpdateDue()
{
    return (ArraySize(g_TradeResults) % g_WeightUpdateInterval == 0) && 
           (ArraySize(g_TradeResults) > 0);
}