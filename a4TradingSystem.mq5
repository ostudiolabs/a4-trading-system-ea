//+------------------------------------------------------------------+
//|                                           a4TradingSystem.mq5 |
//|                                    Copyright 2025, a4Trading |
//|                                        www.a4trading.com     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, a4Trading"
#property link      "www.a4trading.com"
#property version   "1.00"
#property description "a4 Trading System - Phase 1 Complete Implementation"
#property description "Enhanced EMA System with Price Action, AI Scoring, and Adaptive Weights"

//--- Enumerations (DEFINE ONCE HERE)
enum SIGNAL_TYPE
{
    SIGNAL_NONE = 0,
    SIGNAL_BUY = 1,
    SIGNAL_SELL = -1
};

enum MARKET_REGIME
{
    REGIME_TRENDING_LOW_VOL = 0,
    REGIME_TRENDING_NORMAL_VOL = 1,
    REGIME_TRENDING_HIGH_VOL = 2,
    REGIME_RANGING_LOW_VOL = 3,
    REGIME_RANGING_NORMAL_VOL = 4,
    REGIME_RANGING_HIGH_VOL = 5
};

enum VOLATILITY_REGIME
{
    VOL_LOW,
    VOL_NORMAL,
    VOL_HIGH
};

enum TREND_STATE
{
    TRENDING_STRONG,
    TRENDING_WEAK,
    RANGING
};

enum MARKET_SESSION
{
    SESSION_ASIAN,
    SESSION_EUROPEAN,
    SESSION_AMERICAN,
    SESSION_OVERLAP
};

enum PATTERN_TYPE
{
    PATTERN_NONE,
    PATTERN_BULLISH_ENGULFING,
    PATTERN_BEARISH_ENGULFING,
    PATTERN_HAMMER,
    PATTERN_SHOOTING_STAR,
    PATTERN_PINBAR_BULLISH,
    PATTERN_PINBAR_BEARISH,
    PATTERN_DOJI
};

//--- Structures (DEFINE ONCE HERE)
struct CTradeResult
{
    datetime timestamp;
    double entryPrice;
    double exitPrice;
    double profit;
    bool success;
    double mainEntryScore;
    double aiScore;
    double priceActionScore;
    double finalStrength;
    SIGNAL_TYPE signalType;
    MARKET_REGIME regime;
    double lotSize;
};

struct CTradeSetup
{
    datetime timestamp;
    SIGNAL_TYPE signalType;
    double finalStrength;
    double mainEntryScore;
    double aiScore;
    double priceActionScore;
    double entryPrice;
};

struct CComponentPerformance
{
    int totalTrades;
    int successfulTrades;
    double totalProfit;
    double successRate;
    double avgProfit;
    double avgLoss;
    double profitFactor;
    datetime lastUpdate;
};

struct SRLevel
{
    double price;
    int touches;
    datetime lastTouch;
    double strength;
    bool isBroken;
};

struct TimeframeData
{
    ENUM_TIMEFRAMES timeframe;
    int emaFastHandle;
    int emaMediumHandle;
    int emaSlowHandle;
    int atrHandle;
    int adxHandle;
    int rsiHandle;
    bool isValid;
};

//--- Include Files (after structure definitions)
#include "a4_EMAFunctions.mqh"
#include "a4_PriceActionFunctions.mqh"
#include "a4_MarketRegimeFunctions.mqh"
#include "a4_AIScoringFunctions.mqh"
#include "a4_DynamicWeightsFunctions.mqh"
#include "a4_MultiTimeframeFunctions.mqh"
#include "a4_TradeManagementFunctions.mqh"

//+------------------------------------------------------------------+
//| Input Parameters - User Friendly Organization                    |
//+------------------------------------------------------------------+

//--- === GENERAL SETTINGS ===
input group "=== GENERAL SETTINGS ==="
input bool InpEnableTrading = true;                    // Enable Trading
input double InpLotSize = 0.01;                       // Lot Size
input int InpMaxTrades = 1;                           // Maximum Open Trades
input int InpMagicNumber = 123456;                    // Magic Number

//--- === EMA SYSTEM SETTINGS ===
input group "=== EMA SYSTEM SETTINGS ==="
input int InpFastEMAPeriod = 12;                      // Fast EMA Period (8-15)
input int InpMediumEMAPeriod = 26;                    // Medium EMA Period (21-34)
input int InpSlowEMAPeriod = 50;                      // Slow EMA Period (45-89)
input bool InpUseDynamicEMAPeriods = true;            // Use Dynamic EMA Periods
input double InpEMAAlignmentWeight = 0.35;            // EMA Alignment Weight
input double InpCrossoverWeight = 0.25;               // Crossover Quality Weight
input double InpPriceEMAWeight = 0.15;                // Price-EMA Relation Weight
input double InpEMAPriceActionWeight = 0.25;          // EMA Price Action Weight

//--- === PRICE ACTION SETTINGS ===
input group "=== PRICE ACTION SETTINGS ==="
input bool InpEnablePriceAction = true;               // Enable Price Action Analysis
input int InpCandlestickLookback = 5;                 // Candlestick Pattern Lookback
input int InpSRLevelLookback = 20;                    // Support/Resistance Lookback
input double InpMinPatternStrength = 0.5;             // Minimum Pattern Strength
input bool InpCheckKeyLevels = true;                  // Check Key Levels for Patterns

//--- === MARKET REGIME SETTINGS ===
input group "=== MARKET REGIME SETTINGS ==="
input int InpATRPeriod = 14;                          // ATR Period for Volatility
input int InpATRLookback = 100;                       // ATR Lookback for Percentile
input int InpADXPeriod = 14;                          // ADX Period for Trend Strength
input double InpTrendingADXLevel = 25.0;              // Strong Trending ADX Level
input double InpWeakTrendADXLevel = 15.0;             // Weak Trend ADX Level
input bool InpSkipRangingHighVol = true;              // Skip Trading in Ranging High Volatility

//--- === AI SCORING SETTINGS ===
input group "=== AI SCORING SETTINGS ==="
input bool InpEnableAIScoring = true;                 // Enable AI Scoring System
input int InpRSIPeriod = 14;                          // RSI Period
input int InpStochasticKPeriod = 14;                  // Stochastic %K Period
input int InpStochasticDPeriod = 3;                   // Stochastic %D Period
input int InpWilliamsRPeriod = 14;                    // Williams %R Period
input int InpROCPeriod = 12;                          // Rate of Change Period
input int InpMACDFastEMA = 12;                        // MACD Fast EMA
input int InpMACDSlowEMA = 26;                        // MACD Slow EMA
input int InpMACDSignalSMA = 9;                       // MACD Signal SMA

//--- === DYNAMIC WEIGHTS SETTINGS ===
input group "=== DYNAMIC WEIGHTS SETTINGS ==="
input bool InpEnableDynamicWeights = true;            // Enable Dynamic Weight Adaptation
input int InpPerformanceTrackingPeriod = 50;          // Performance Tracking Period (trades)
input double InpWeightAdjustmentSpeed = 0.1;          // Weight Adjustment Speed (0.05-0.2)
input double InpMaxWeightDeviation = 0.2;             // Maximum Weight Deviation
input double InpBaseMainEntryWeight = 0.50;           // Base Main Entry Weight
input double InpBaseAIWeight = 0.30;                  // Base AI Weight
input double InpBasePriceActionWeight = 0.20;         // Base Price Action Weight

//--- === MULTI-TIMEFRAME SETTINGS ===
input group "=== MULTI-TIMEFRAME SETTINGS ==="
input bool InpEnableMultiTimeframe = true;            // Enable Multi-Timeframe Analysis
input bool InpRequireHTFAlignment = true;             // Require Higher TF Alignment
input double InpMinHTFAlignment = 0.5;                // Minimum Higher TF Alignment Score
input double InpLTFRefinementWeight = 0.2;            // Lower TF Refinement Weight

//--- === SIGNAL THRESHOLD SETTINGS ===
input group "=== SIGNAL THRESHOLD SETTINGS ==="
input double InpMainEntryThreshold = 0.30;            // Main Entry Validation Threshold
input double InpFinalSignalThreshold = 0.65;          // Final Signal Threshold
input bool InpUseAdaptiveThreshold = true;            // Use Adaptive Threshold
input double InpVolatilityThresholdAdjustment = 0.1;  // Volatility Threshold Adjustment
input double InpSessionThresholdAdjustment = 0.05;    // Session Threshold Adjustment

//--- === RISK MANAGEMENT SETTINGS ===
input group "=== RISK MANAGEMENT SETTINGS ==="
input double InpStopLossATRMultiplier = 2.0;          // Stop Loss ATR Multiplier
input double InpTakeProfitATRMultiplier = 3.0;        // Take Profit ATR Multiplier
input bool InpUseTrailingStop = true;                 // Use Trailing Stop
input double InpTrailingStopATRMultiplier = 1.5;      // Trailing Stop ATR Multiplier
input int InpMaxSpreadPoints = 30;                    // Maximum Spread (points)

//--- === TIME FILTER SETTINGS ===
input group "=== TIME FILTER SETTINGS ==="
input bool InpEnableTimeFilter = false;               // Enable Time Filter
input int InpStartHour = 8;                           // Start Trading Hour
input int InpEndHour = 22;                            // End Trading Hour
input bool InpTradeFriday = true;                     // Trade on Friday
input bool InpTradeMonday = true;                     // Trade on Monday

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
int g_MagicNumber;
double g_LotSize;
int g_MaxTrades;

// EMA Handles and Buffers
int g_FastEMAHandle, g_MediumEMAHandle, g_SlowEMAHandle;
double g_FastEMABuffer[], g_MediumEMABuffer[], g_SlowEMABuffer[];

// Technical Indicator Handles
int g_ATRHandle, g_ADXHandle, g_RSIHandle, g_StochasticHandle;
int g_WilliamsRHandle, g_MACDHandle, g_VolumeHandle;

// Dynamic Weights
double g_DynamicMainEntryWeight, g_DynamicAIWeight, g_DynamicPriceActionWeight;

// Performance Tracking
CTradeResult g_TradeHistory[];
int g_TotalTrades;

// Timeframe Variables
ENUM_TIMEFRAMES g_HigherTF, g_LowerTF;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize global variables
    g_MagicNumber = InpMagicNumber;
    g_LotSize = InpLotSize;
    g_MaxTrades = InpMaxTrades;
    
    // Initialize dynamic weights
    g_DynamicMainEntryWeight = InpBaseMainEntryWeight;
    g_DynamicAIWeight = InpBaseAIWeight;
    g_DynamicPriceActionWeight = InpBasePriceActionWeight;
    
    // Initialize timeframes
    InitializeTimeframes();
    
    // Initialize performance tracking
    InitializePerformanceTracking();
    
    // Initialize trade management
    InitializeTradeManagement();
    
    // Initialize EMA handles
    if(!InitializeEMAHandles())
    {
        Print("Error initializing EMA handles");
        return INIT_FAILED;
    }
    
    // Initialize technical indicator handles
    if(!InitializeTechnicalIndicators())
    {
        Print("Error initializing technical indicators");
        return INIT_FAILED;
    }
    
    // Set array properties
    SetArrayProperties();
    
    Print("a4 Trading System initialized successfully");
    Print("Current Symbol: ", Symbol());
    Print("Current Timeframe: ", EnumToString(Period()));
    Print("Higher Timeframe: ", EnumToString(g_HigherTF));
    Print("Lower Timeframe: ", EnumToString(g_LowerTF));
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up handles
    if(g_FastEMAHandle != INVALID_HANDLE) IndicatorRelease(g_FastEMAHandle);
    if(g_MediumEMAHandle != INVALID_HANDLE) IndicatorRelease(g_MediumEMAHandle);
    if(g_SlowEMAHandle != INVALID_HANDLE) IndicatorRelease(g_SlowEMAHandle);
    if(g_ATRHandle != INVALID_HANDLE) IndicatorRelease(g_ATRHandle);
    if(g_ADXHandle != INVALID_HANDLE) IndicatorRelease(g_ADXHandle);
    if(g_RSIHandle != INVALID_HANDLE) IndicatorRelease(g_RSIHandle);
    if(g_StochasticHandle != INVALID_HANDLE) IndicatorRelease(g_StochasticHandle);
    if(g_WilliamsRHandle != INVALID_HANDLE) IndicatorRelease(g_WilliamsRHandle);
    if(g_MACDHandle != INVALID_HANDLE) IndicatorRelease(g_MACDHandle);
    
    // Cleanup timeframe data
    CleanupTimeframeData();
    
    Print("a4 Trading System deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if trading is enabled
    if(!InpEnableTrading) return;
    
    // Check if new bar
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(Symbol(), Period(), 0);
    if(currentBarTime == lastBarTime) return;
    lastBarTime = currentBarTime;
    
    // Update all indicators
    if(!UpdateIndicators()) return;
    
    // Apply time filter
    if(InpEnableTimeFilter && !IsTimeToTrade()) return;
    
    // Check spread
    if(!IsSpreadAcceptable()) return;
    
    // Check maximum trades
    if(GetOpenTrades() >= g_MaxTrades) return;
    
    // === MAIN TRADING LOGIC ===
    
    // 1. Market Regime Check
    MARKET_REGIME currentRegime = DetectMarketRegime();
    if(InpSkipRangingHighVol && currentRegime == REGIME_RANGING_HIGH_VOL)
    {
        return; // Skip trading in bad conditions
    }
    double regimeMultiplier = GetRegimeMultiplier(currentRegime);
    
    // 2. Multi-timeframe Alignment Check
    double htfAlignment = 1.0;
    double ltfRefinement = 1.0;
    
    if(InpEnableMultiTimeframe)
    {
        htfAlignment = GetHTFTrendScore();
        if(InpRequireHTFAlignment && htfAlignment < InpMinHTFAlignment)
        {
            return; // Higher timeframe not aligned
        }
        ltfRefinement = GetLTFEntryQuality();
    }
    
    // 3. Main Trading Entry Calculation
    double mainEntryScore = CalculateMainEntryScore();
    
    // 4. Main Entry Validation
    if(mainEntryScore < InpMainEntryThreshold)
    {
        return; // Main entry signal too weak
    }
    
    // 5. Supporting Confirmation Signals
    double aiScore = 0.0;
    double supportingPAScore = 0.0;
    
    if(InpEnableAIScoring)
    {
        aiScore = CalculateEnhancedAIScore() * g_DynamicAIWeight;
    }
    
    if(InpEnablePriceAction)
    {
        supportingPAScore = CalculateAdvancedPriceAction() * g_DynamicPriceActionWeight;
    }
    
    // 6. Final Signal Calculation
    double rawStrength = (mainEntryScore * g_DynamicMainEntryWeight) + 
                        (aiScore * g_DynamicAIWeight) + 
                        (supportingPAScore * g_DynamicPriceActionWeight);
    
    // Apply multi-timeframe adjustments
    double adjustedStrength = rawStrength * htfAlignment * ltfRefinement;
    
    // Apply market regime adjustment
    double finalStrength = adjustedStrength * regimeMultiplier;
    
    // 7. Entry Decision
    double adaptiveThreshold = InpFinalSignalThreshold;
    
    if(InpUseAdaptiveThreshold)
    {
        adaptiveThreshold *= GetVolatilityAdjustment();
        adaptiveThreshold *= GetSessionAdjustment();
    }
    
    // Determine signal direction
    SIGNAL_TYPE signalType = GetSignalDirection(mainEntryScore, aiScore, supportingPAScore);
    
    // Final entry decision
    bool shouldEnter = (finalStrength >= adaptiveThreshold) &&
                      (signalType != SIGNAL_NONE) &&
                      CheckRiskManagement();
    
    if(shouldEnter)
    {
        // Place order
        if(signalType == SIGNAL_BUY)
        {
            if(ExecuteBuyOrder(g_LotSize, finalStrength))
            {
                RecordTradeSetup(signalType, finalStrength, mainEntryScore, aiScore, supportingPAScore);
            }
        }
        else if(signalType == SIGNAL_SELL)
        {
            if(ExecuteSellOrder(g_LotSize, finalStrength))
            {
                RecordTradeSetup(signalType, finalStrength, mainEntryScore, aiScore, supportingPAScore);
            }
        }
    }
    
    // Manage existing trades
    ManageOpenTrades();
}

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
bool InitializeEMAHandles()
{
    g_FastEMAHandle = iMA(Symbol(), Period(), InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    g_MediumEMAHandle = iMA(Symbol(), Period(), InpMediumEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    g_SlowEMAHandle = iMA(Symbol(), Period(), InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    
    return (g_FastEMAHandle != INVALID_HANDLE && 
            g_MediumEMAHandle != INVALID_HANDLE && 
            g_SlowEMAHandle != INVALID_HANDLE);
}

void SetArrayProperties()
{
    ArraySetAsSeries(g_FastEMABuffer, true);
    ArraySetAsSeries(g_MediumEMABuffer, true);
    ArraySetAsSeries(g_SlowEMABuffer, true);
}

bool UpdateIndicators()
{
    // Update EMA buffers
    if(CopyBuffer(g_FastEMAHandle, 0, 0, 50, g_FastEMABuffer) <= 0) return false;
    if(CopyBuffer(g_MediumEMAHandle, 0, 0, 50, g_MediumEMABuffer) <= 0) return false;
    if(CopyBuffer(g_SlowEMAHandle, 0, 0, 50, g_SlowEMABuffer) <= 0) return false;
    
    return true;
}

bool IsTimeToTrade()
{
    MqlDateTime time;
    TimeToStruct(TimeCurrent(), time);
    
    // Check day of week
    if(!InpTradeMonday && time.day_of_week == 1) return false;
    if(!InpTradeFriday && time.day_of_week == 5) return false;
    
    // Check trading hours
    if(time.hour < InpStartHour || time.hour >= InpEndHour) return false;
    
    return true;
}

bool IsSpreadAcceptable()
{
    double spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
    return (spread <= InpMaxSpreadPoints);
}

int GetOpenTrades()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == Symbol() && 
               PositionGetInteger(POSITION_MAGIC) == g_MagicNumber)
            {
                count++;
            }
        }
    }
    return count;
}

void ManageOpenTrades()
{
    UpdateTrailingStops();
    CheckEarlyExitConditions();
}

void RecordTradeSetup(SIGNAL_TYPE signalType, double finalStrength, double mainScore, double aiScore, double paScore)
{
    CTradeSetup setup;
    setup.timestamp = TimeCurrent();
    setup.signalType = signalType;
    setup.finalStrength = finalStrength;
    setup.mainEntryScore = mainScore;
    setup.aiScore = aiScore;
    setup.priceActionScore = paScore;
    setup.entryPrice = SymbolInfoDouble(Symbol(), signalType == SIGNAL_BUY ? SYMBOL_ASK : SYMBOL_BID);
    
    StoreTradeSetup(setup);
}