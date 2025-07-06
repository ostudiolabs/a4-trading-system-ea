//+------------------------------------------------------------------+
//|                               a4_TradeManagementFunctions.mqh |
//|                                    Copyright 2025, a4Trading |
//|                                        www.a4trading.com     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Trade Management Functions                                      |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>

// Global trade management objects
CTrade g_Trade;

//+------------------------------------------------------------------+
//| Initialize Trade Management                                     |
//+------------------------------------------------------------------+
void InitializeTradeManagement()
{
    g_Trade.SetExpertMagicNumber(g_MagicNumber);
    g_Trade.SetDeviationInPoints(10);
    g_Trade.SetTypeFilling(ORDER_FILLING_IOC);
    g_Trade.LogLevel(LOG_LEVEL_ERRORS);
}

//+------------------------------------------------------------------+
//| Execute Buy Order                                               |
//+------------------------------------------------------------------+
bool ExecuteBuyOrder(double lotSize, double signalStrength)
{
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    
    // Calculate stop loss and take profit
    double stopLoss = CalculateStopLoss(SIGNAL_BUY, currentPrice);
    double takeProfit = CalculateTakeProfit(SIGNAL_BUY, currentPrice);
    
    // Validate order parameters
    if(!ValidateOrderParameters(SIGNAL_BUY, lotSize, currentPrice, stopLoss, takeProfit))
        return false;
    
    // Place the order
    bool result = g_Trade.Buy(lotSize, Symbol(), currentPrice, stopLoss, takeProfit, 
                             CreateOrderComment(SIGNAL_BUY, signalStrength));
    
    if(result)
    {
        Print("BUY order placed successfully. Price: ", DoubleToString(currentPrice, Digits()),
              ", SL: ", DoubleToString(stopLoss, Digits()),
              ", TP: ", DoubleToString(takeProfit, Digits()),
              ", Signal Strength: ", DoubleToString(signalStrength, 3));
        
        // Record trade opening
        RecordTradeOpening(SIGNAL_BUY, currentPrice, stopLoss, takeProfit, lotSize, signalStrength);
    }
    else
    {
        Print("Failed to place BUY order. Error: ", GetLastError());
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Execute Sell Order                                              |
//+------------------------------------------------------------------+
bool ExecuteSellOrder(double lotSize, double signalStrength)
{
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    
    // Calculate stop loss and take profit
    double stopLoss = CalculateStopLoss(SIGNAL_SELL, currentPrice);
    double takeProfit = CalculateTakeProfit(SIGNAL_SELL, currentPrice);
    
    // Validate order parameters
    if(!ValidateOrderParameters(SIGNAL_SELL, lotSize, currentPrice, stopLoss, takeProfit))
        return false;
    
    // Place the order
    bool result = g_Trade.Sell(lotSize, Symbol(), currentPrice, stopLoss, takeProfit,
                              CreateOrderComment(SIGNAL_SELL, signalStrength));
    
    if(result)
    {
        Print("SELL order placed successfully. Price: ", DoubleToString(currentPrice, Digits()),
              ", SL: ", DoubleToString(stopLoss, Digits()),
              ", TP: ", DoubleToString(takeProfit, Digits()),
              ", Signal Strength: ", DoubleToString(signalStrength, 3));
        
        // Record trade opening
        RecordTradeOpening(SIGNAL_SELL, currentPrice, stopLoss, takeProfit, lotSize, signalStrength);
    }
    else
    {
        Print("Failed to place SELL order. Error: ", GetLastError());
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss                                             |
//+------------------------------------------------------------------+
double CalculateStopLoss(SIGNAL_TYPE signalType, double entryPrice)
{
    double atr[1];
    if(CopyBuffer(g_ATRHandle, 0, 0, 1, atr) <= 0)
    {
        // Fallback to fixed stop loss if ATR not available
        double fixedSL = entryPrice * 0.01; // 1% stop loss
        return signalType == SIGNAL_BUY ? entryPrice - fixedSL : entryPrice + fixedSL;
    }
    
    double stopDistance = atr[0] * InpStopLossATRMultiplier;
    
    // Ensure minimum stop distance
    double minStopDistance = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    if(stopDistance < minStopDistance)
        stopDistance = minStopDistance * 1.5;
    
    if(signalType == SIGNAL_BUY)
        return NormalizeDouble(entryPrice - stopDistance, Digits());
    else
        return NormalizeDouble(entryPrice + stopDistance, Digits());
}

//+------------------------------------------------------------------+
//| Calculate Take Profit                                           |
//+------------------------------------------------------------------+
double CalculateTakeProfit(SIGNAL_TYPE signalType, double entryPrice)
{
    double atr[1];
    if(CopyBuffer(g_ATRHandle, 0, 0, 1, atr) <= 0)
    {
        // Fallback to fixed take profit if ATR not available
        double fixedTP = entryPrice * 0.02; // 2% take profit
        return signalType == SIGNAL_BUY ? entryPrice + fixedTP : entryPrice - fixedTP;
    }
    
    double profitDistance = atr[0] * InpTakeProfitATRMultiplier;
    
    if(signalType == SIGNAL_BUY)
        return NormalizeDouble(entryPrice + profitDistance, Digits());
    else
        return NormalizeDouble(entryPrice - profitDistance, Digits());
}

//+------------------------------------------------------------------+
//| Validate Order Parameters                                       |
//+------------------------------------------------------------------+
bool ValidateOrderParameters(SIGNAL_TYPE signalType, double lotSize, double price, 
                           double stopLoss, double takeProfit)
{
    // Check lot size
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    
    if(lotSize < minLot || lotSize > maxLot)
    {
        Print("Invalid lot size: ", lotSize, ". Min: ", minLot, ", Max: ", maxLot);
        return false;
    }
    
    // Normalize lot size to lot step
    lotSize = NormalizeDouble(MathRound(lotSize / lotStep) * lotStep, 2);
    
    // Check stop levels
    long stopLevel = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
    double stopLevelPoints = stopLevel * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    
    if(signalType == SIGNAL_BUY)
    {
        if(stopLoss > 0 && (price - stopLoss) < stopLevelPoints)
        {
            Print("Stop loss too close to entry price. Required distance: ", stopLevelPoints);
            return false;
        }
        if(takeProfit > 0 && (takeProfit - price) < stopLevelPoints)
        {
            Print("Take profit too close to entry price. Required distance: ", stopLevelPoints);
            return false;
        }
    }
    else // SIGNAL_SELL
    {
        if(stopLoss > 0 && (stopLoss - price) < stopLevelPoints)
        {
            Print("Stop loss too close to entry price. Required distance: ", stopLevelPoints);
            return false;
        }
        if(takeProfit > 0 && (price - takeProfit) < stopLevelPoints)
        {
            Print("Take profit too close to entry price. Required distance: ", stopLevelPoints);
            return false;
        }
    }
    
    // Check margin requirements
    double margin = 0.0;
    if(!OrderCalcMargin(signalType == SIGNAL_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                       Symbol(), lotSize, price, margin))
    {
        Print("Failed to calculate margin requirement");
        return false;
    }
    
    double freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
    if(margin > freeMargin * 0.8) // Use max 80% of free margin
    {
        Print("Insufficient margin. Required: ", margin, ", Available: ", freeMargin);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Create Order Comment                                            |
//+------------------------------------------------------------------+
string CreateOrderComment(SIGNAL_TYPE signalType, double signalStrength)
{
    string comment = "a4TS_";
    comment += (signalType == SIGNAL_BUY) ? "B_" : "S_";
    comment += DoubleToString(signalStrength, 2);
    comment += "_" + TimeToString(TimeCurrent(), TIME_MINUTES);
    
    return comment;
}

//+------------------------------------------------------------------+
//| Update Trailing Stops                                          |
//+------------------------------------------------------------------+
void UpdateTrailingStops()
{
    if(!InpUseTrailingStop) return;
    
    double atr[1];
    if(CopyBuffer(g_ATRHandle, 0, 0, 1, atr) <= 0) return;
    
    double trailDistance = atr[0] * InpTrailingStopATRMultiplier;
    long minStopLevel = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
    double minStopDistance = minStopLevel * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    
    if(trailDistance < minStopDistance)
        trailDistance = minStopDistance * 1.5;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == Symbol() && 
               PositionGetInteger(POSITION_MAGIC) == g_MagicNumber)
            {
                UpdatePositionTrailingStop(PositionGetTicket(i), trailDistance);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update Individual Position Trailing Stop                       |
//+------------------------------------------------------------------+
void UpdatePositionTrailingStop(ulong ticket, double trailDistance)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    
    double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    
    double newSL = 0.0;
    bool shouldUpdate = false;
    
    if(posType == POSITION_TYPE_BUY)
    {
        newSL = currentPrice - trailDistance;
        
        // Only update if new SL is higher than current SL (or no SL set)
        if(newSL > currentSL || currentSL == 0.0)
        {
            // Ensure we don't move SL below break-even
            if(newSL >= posOpenPrice * 0.999) // Small buffer for spread
            {
                shouldUpdate = true;
            }
        }
    }
    else // POSITION_TYPE_SELL
    {
        newSL = currentPrice + trailDistance;
        
        // Only update if new SL is lower than current SL (or no SL set)
        if(newSL < currentSL || currentSL == 0.0)
        {
            // Ensure we don't move SL above break-even
            if(newSL <= posOpenPrice * 1.001) // Small buffer for spread
            {
                shouldUpdate = true;
            }
        }
    }
    
    if(shouldUpdate)
    {
        newSL = NormalizeDouble(newSL, Digits());
        
        if(g_Trade.PositionModify(ticket, newSL, currentTP))
        {
            Print("Trailing stop updated for ticket ", ticket, ". New SL: ", DoubleToString(newSL, Digits()));
        }
        else
        {
            Print("Failed to update trailing stop for ticket ", ticket, ". Error: ", GetLastError());
        }
    }
}

//+------------------------------------------------------------------+
//| Check Early Exit Conditions                                    |
//+------------------------------------------------------------------+
void CheckEarlyExitConditions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == Symbol() && 
               PositionGetInteger(POSITION_MAGIC) == g_MagicNumber)
            {
                ulong ticket = PositionGetTicket(i);
                
                // Check various exit conditions
                if(ShouldExitEarly(ticket))
                {
                    ClosePosition(ticket, "Early exit signal");
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Determine if Position Should Exit Early                        |
//+------------------------------------------------------------------+
bool ShouldExitEarly(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    
    // 1. Check for signal reversal
    if(IsSignalReversed(posType))
    {
        Print("Early exit: Signal reversal detected for ticket ", ticket);
        return true;
    }
    
    // 2. Check for excessive time in trade (optional)
    int maxBarsInTrade = 50; // Maximum bars to hold position
    int barsInTrade = Bars(Symbol(), Period(), openTime, TimeCurrent());
    
    if(barsInTrade > maxBarsInTrade)
    {
        Print("Early exit: Maximum time in trade exceeded for ticket ", ticket);
        return true;
    }
    
    // 3. Check for market regime change
    static MARKET_REGIME lastRegime = REGIME_TRENDING_NORMAL_VOL;
    MARKET_REGIME currentRegime = DetectMarketRegime();
    
    if(currentRegime == REGIME_RANGING_HIGH_VOL && lastRegime != REGIME_RANGING_HIGH_VOL)
    {
        Print("Early exit: Market regime changed to unfavorable conditions for ticket ", ticket);
        return true;
    }
    
    // 4. Check for EMA alignment breakdown
    if(IsEMAAlignmentBroken(posType))
    {
        Print("Early exit: EMA alignment broken for ticket ", ticket);
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if Signal is Reversed                                    |
//+------------------------------------------------------------------+
bool IsSignalReversed(ENUM_POSITION_TYPE posType)
{
    // Calculate current main entry score
    double currentMainScore = CalculateMainEntryScore();
    
    // Get signal direction
    SIGNAL_TYPE currentSignal = GetSignalDirection(currentMainScore, 
                                                  InpEnableAIScoring ? CalculateEnhancedAIScore() : 0.5,
                                                  InpEnablePriceAction ? CalculateAdvancedPriceAction() : 0.5);
    
    // Check if signal is opposite to position
    if(posType == POSITION_TYPE_BUY && currentSignal == SIGNAL_SELL)
        return true;
    else if(posType == POSITION_TYPE_SELL && currentSignal == SIGNAL_BUY)
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if EMA Alignment is Broken                               |
//+------------------------------------------------------------------+
bool IsEMAAlignmentBroken(ENUM_POSITION_TYPE posType)
{
    if(ArraySize(g_FastEMABuffer) < 2 || 
       ArraySize(g_MediumEMABuffer) < 2 || 
       ArraySize(g_SlowEMABuffer) < 2)
        return false;
    
    double fastEMA = g_FastEMABuffer[0];
    double mediumEMA = g_MediumEMABuffer[0];
    double slowEMA = g_SlowEMABuffer[0];
    
    if(posType == POSITION_TYPE_BUY)
    {
        // Check if bullish alignment is broken
        return !(fastEMA > mediumEMA && mediumEMA > slowEMA);
    }
    else // POSITION_TYPE_SELL
    {
        // Check if bearish alignment is broken
        return !(fastEMA < mediumEMA && mediumEMA < slowEMA);
    }
}

//+------------------------------------------------------------------+
//| Close Position                                                  |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket, string reason)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    bool result = g_Trade.PositionClose(ticket);
    
    if(result)
    {
        Print("Position closed successfully. Ticket: ", ticket, ", Reason: ", reason);
        
        // Record trade closing
        RecordTradeClosing(ticket, reason);
    }
    else
    {
        Print("Failed to close position. Ticket: ", ticket, ", Error: ", GetLastError());
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Check Risk Management                                           |
//+------------------------------------------------------------------+
bool CheckRiskManagement()
{
    // Check account balance vs equity
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    if(balance > 0)
    {
        double drawdownPercent = (balance - equity) / balance * 100.0;
        
        // Stop trading if drawdown exceeds 20%
        if(drawdownPercent > 20.0)
        {
            Print("Risk Management: Maximum drawdown exceeded (", DoubleToString(drawdownPercent, 2), "%)");
            return false;
        }
    }
    
    // Check free margin
    double freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
    double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
    
    if(marginLevel > 0 && marginLevel < 200.0) // Less than 200% margin level
    {
        Print("Risk Management: Low margin level (", DoubleToString(marginLevel, 2), "%)");
        return false;
    }
    
    // Check maximum concurrent trades
    if(GetOpenTrades() >= g_MaxTrades)
    {
        return false;
    }
    
    // Check daily loss limit (optional)
    double dailyPnL = GetTodayPnL();
    double maxDailyLoss = balance * 0.05; // 5% max daily loss
    
    if(dailyPnL < -maxDailyLoss)
    {
        Print("Risk Management: Daily loss limit exceeded");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Get Today's P&L                                                |
//+------------------------------------------------------------------+
double GetTodayPnL()
{
    double dailyPnL = 0.0;
    datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    
    // Check closed positions
    HistorySelect(todayStart, TimeCurrent());
    int totalDeals = HistoryDealsTotal();
    
    for(int i = 0; i < totalDeals; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if(dealTicket > 0)
        {
            string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
            long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
            
            if(dealSymbol == Symbol() && dealMagic == g_MagicNumber)
            {
                double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                double dealSwap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
                double dealCommission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
                
                dailyPnL += dealProfit + dealSwap + dealCommission;
            }
        }
    }
    
    // Add floating P&L from open positions
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == Symbol() && 
               PositionGetInteger(POSITION_MAGIC) == g_MagicNumber)
            {
                dailyPnL += PositionGetDouble(POSITION_PROFIT) + 
                           PositionGetDouble(POSITION_SWAP);
            }
        }
    }
    
    return dailyPnL;
}

//+------------------------------------------------------------------+
//| Record Trade Opening                                            |
//+------------------------------------------------------------------+
void RecordTradeOpening(SIGNAL_TYPE signalType, double entryPrice, double stopLoss, 
                       double takeProfit, double lotSize, double signalStrength)
{
    // This function would log trade opening details
    // Implementation depends on specific logging requirements
    
    string logMessage = StringFormat("TRADE OPENED: %s | Price: %s | SL: %s | TP: %s | Lot: %s | Strength: %s",
                                   signalType == SIGNAL_BUY ? "BUY" : "SELL",
                                   DoubleToString(entryPrice, Digits()),
                                   DoubleToString(stopLoss, Digits()),
                                   DoubleToString(takeProfit, Digits()),
                                   DoubleToString(lotSize, 2),
                                   DoubleToString(signalStrength, 3));
    
    Print(logMessage);
    
    // Could also write to file or send to external logging system
}

//+------------------------------------------------------------------+
//| Record Trade Closing                                            |
//+------------------------------------------------------------------+
void RecordTradeClosing(ulong ticket, string reason)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    double profit = PositionGetDouble(POSITION_PROFIT);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double closePrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
    
    // Create trade result for performance tracking
    CTradeResult tradeResult;
    tradeResult.timestamp = openTime;
    tradeResult.entryPrice = openPrice;
    tradeResult.exitPrice = closePrice;
    tradeResult.profit = profit;
    tradeResult.success = (profit > 0);
    tradeResult.lotSize = PositionGetDouble(POSITION_VOLUME);
    
    // Find corresponding setup data to complete the record
    // This would be matched with the stored trade setup when the position was opened
    
    string logMessage = StringFormat("TRADE CLOSED: Ticket: %d | Profit: %s | Reason: %s",
                                   ticket,
                                   DoubleToString(profit, 2),
                                   reason);
    
    Print(logMessage);
    
    // Record in performance tracking system
    RecordTradeResult(tradeResult);
}

//+------------------------------------------------------------------+
//| Get Position Information                                        |
//+------------------------------------------------------------------+
string GetPositionsInfo()
{
    string info = "=== Open Positions ===\n";
    int posCount = 0;
    double totalProfit = 0.0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == Symbol() && 
               PositionGetInteger(POSITION_MAGIC) == g_MagicNumber)
            {
                posCount++;
                ulong ticket = PositionGetTicket(i);
                ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                double volume = PositionGetDouble(POSITION_VOLUME);
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
                double profit = PositionGetDouble(POSITION_PROFIT);
                
                totalProfit += profit;
                
                info += StringFormat("Ticket: %d | %s | %.2f lots | Open: %s | Current: %s | P&L: %s\n",
                                   ticket,
                                   type == POSITION_TYPE_BUY ? "BUY" : "SELL",
                                   volume,
                                   DoubleToString(openPrice, Digits()),
                                   DoubleToString(currentPrice, Digits()),
                                   DoubleToString(profit, 2));
            }
        }
    }
    
    if(posCount == 0)
    {
        info += "No open positions\n";
    }
    else
    {
        info += StringFormat("Total Positions: %d | Total P&L: %s\n", posCount, DoubleToString(totalProfit, 2));
    }
    
    info += "=====================";
    
    return info;
}

//+------------------------------------------------------------------+
//| Emergency Close All Positions                                  |
//+------------------------------------------------------------------+
void EmergencyCloseAll(string reason)
{
    Print("EMERGENCY: Closing all positions. Reason: ", reason);
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == Symbol() && 
               PositionGetInteger(POSITION_MAGIC) == g_MagicNumber)
            {
                ulong ticket = PositionGetTicket(i);
                ClosePosition(ticket, "Emergency close: " + reason);
            }
        }
    }
}