//+------------------------------------------------------------------+
//|                                                    TazzieBot.mq5 |
//|                        Copyright 2020, JMRSquared Software Corp. |
//|                                           https://jmrsquared.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, JMRSquared Software Corp."
#property link      "https://jmrsquared.com"
#property version   "1.1"

// this is it
input double volume=0.01;
input double total_sl_pips=50;
input double total_tp_pips=50;
input double acceptable_profit_usd=25;
input int max_concurrent_positions=10;
input int adjust_value_for_tp_sl=8;
input int sellDelayHours=10;
input int buyDelayHours=10;

#include<Trade\Trade.mqh>
// #include<.\Helpers\DynamicArray.mqh>
CTrade trade;


int tp_pips = total_tp_pips;
int sl_pips = total_sl_pips;
int acceptable_profit = acceptable_profit_usd;

int allPreviousBuys = 0;
int allPreviousSells = 0;

uint lastBuyTime = 0;
uint lastSellTime = 0;

struct CustomPosition
  {
   ulong             ticket;
   double            acceptable_profit;
   double            current_sl;
   double            current_tp;
   double            current_profit;
  };

CustomPosition allPositions[40];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnInit()
  {
   for(int ii =0; ii<ArraySize(allPositions); ii++)
     {
      allPositions[ii].ticket = 0;
      allPositions[ii].acceptable_profit  = 0;
      allPositions[ii].current_sl = 0;
      allPositions[ii].current_tp = 0;
      allPositions[ii].current_profit = 0;
     }
   for(int ii =0; ii<3; ii++)
     {
      Print(ii+ " => Position Ticket: "+allPositions[ii].ticket);
      Print(ii+ " => Position AC_PROFIT: "+allPositions[ii].acceptable_profit);
     }
  }
 
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   double Balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double Equity=AccountInfoDouble(ACCOUNT_EQUITY);

   double myMovingAverageArray1[];
   double myMovingAverageArray2[];

   long stopLevels=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);

   if(tp_pips > 0 && tp_pips < stopLevels)
     {
      Print("=> We have adjusted you TP from "+ tp_pips + " to " + stopLevels + " for the broker to be happy!");
      tp_pips = stopLevels;
     }
   if(sl_pips > 0 && sl_pips < stopLevels)
     {
      Print("=> We have adjusted you SL from "+ sl_pips + " to " + stopLevels + " for the broker to be happy!");
      sl_pips = stopLevels;
     }

   static int movingAverageDefinition1 = iMA(_Symbol,_Period,5,0,MODE_EMA,PRICE_CLOSE);
   static int movingAverageDefinition2 = iMA(_Symbol,_Period,25,0,MODE_EMA,PRICE_CLOSE);

   ArraySetAsSeries(myMovingAverageArray1,true);
   ArraySetAsSeries(myMovingAverageArray2,true);

   CopyBuffer(movingAverageDefinition1,0,0,3,myMovingAverageArray1);

   CopyBuffer(movingAverageDefinition2,0,0,3,myMovingAverageArray2);

   AdjustTPandSL();

   string marketDirection = "";

   if(myMovingAverageArray1[0] > myMovingAverageArray1[1])
     {
      marketDirection = "Going UP";
     }
   else
     {
      marketDirection = "Going DOWN";
     }
   string currentPositions = "";

    for(int ii =ArraySize(allPositions) - 1; ii>=0; ii--)
    {
      if(allPositions[ii].ticket != 0)
      {
        currentPositions += "\n\n   " + allPositions[ii].ticket + " =>";
        currentPositions += "\n       Acceptable profit  : "+allPositions[ii].acceptable_profit;
        currentPositions += "\n       Current SL         : "+allPositions[ii].current_sl;
        currentPositions += "\n       Current PROFIT     : "+allPositions[ii].current_profit;
      }
    }
     uint current_ticks = GetTickCount();
     Comment("\n Direction: "+marketDirection+
           "\n CAN SELL? :            "+((current_ticks - lastSellTime) > (sellDelayHours*3600))+
           "\n CAN BUY? :            "+((current_ticks - lastBuyTime) > (buyDelayHours*3600))+
           "\n\n"+
           "\n Balance:           "+Balance+
           "\n Equity:            "+Equity+
           "\n PROFIT:            "+(Equity - Balance)+
           "\n\n"+
           "\n\n"+
           "\n All Sells Count:            "+allPreviousSells+
           "\n All Buys Count:            "+allPreviousBuys+
           "\n\n"+
           "\n Total OPEN Positions:   "+PositionsTotal()+
           "\n POSITIONS:         "+currentPositions+
           "\n\n"
    ,250);

   if(myMovingAverageArray1[0]>myMovingAverageArray2[0] && myMovingAverageArray1[1]<myMovingAverageArray2[1])
     {
      // CheckforBreakEvenBuy();
      if(PositionsTotal() < max_concurrent_positions && (lastBuyTime == 0 || ((current_ticks - lastBuyTime) > (buyDelayHours*3600))))
        {
         allPreviousBuys++;
         
         lastBuyTime = current_ticks;

         double CurrentBuyPrice=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double TP = CurrentBuyPrice+tp_pips*SymbolInfoDouble(_Symbol,SYMBOL_POINT);
         double SL = CurrentBuyPrice-sl_pips*SymbolInfoDouble(_Symbol,SYMBOL_POINT);

         double digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
         TP=NormalizeDouble(TP,digits);
         SL=NormalizeDouble(SL,digits);

         trade.Buy(volume,NULL,0.0,NULL,NULL,"This is a buy");
         CloseAllSellPositions();
        }
     }
      
   if(myMovingAverageArray1[0]<myMovingAverageArray2[0] && myMovingAverageArray1[1]>myMovingAverageArray2[1])
     {
      // CheckforBreakEvenSell();
      if(PositionsTotal() < max_concurrent_positions && (lastSellTime == 0 || ((current_ticks - lastSellTime) > (sellDelayHours*3600))))
        {
         allPreviousSells++;
      
        lastSellTime = current_ticks;
         
         double CurrentSellPrice=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         double SL = CurrentSellPrice+(sl_pips*SymbolInfoDouble(_Symbol,SYMBOL_POINT));
         double TP = CurrentSellPrice-(tp_pips*SymbolInfoDouble(_Symbol,SYMBOL_POINT));
         // unnormalized TP value
         double digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
         TP=NormalizeDouble(TP,digits);
         SL=NormalizeDouble(SL,digits);

         trade.Sell(volume,NULL,0.0,NULL,NULL,"This is a sell");
         CloseAllBuyPositions();
        }
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void AdjustTPandSL()
  {
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   for(int i = PositionsTotal()-1; i>=0; i--)
     {
      ulong positionTicket = PositionGetInteger(POSITION_TICKET);
      double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double positionStopLoss = PositionGetDouble(POSITION_SL);
      double positionTakeProfit = PositionGetDouble(POSITION_TP);
      double positionType = PositionGetInteger(POSITION_TYPE);
      double profit = PositionGetDouble(POSITION_PROFIT);

      double acceptable_profit = 0;
      for(int ii =0; ii<ArraySize(allPositions); ii++)
        {
         if(allPositions[ii].ticket ==  positionTicket)
           {
            acceptable_profit = allPositions[ii].acceptable_profit;
            allPositions[ii].current_sl = positionStopLoss;
            allPositions[ii].current_tp = positionTakeProfit;
            allPositions[ii].current_profit = profit;
            break;
           }
        }
      if(acceptable_profit == 0)
        {
         for(int ii =0; ii<ArraySize(allPositions); ii++)
           {
            if(allPositions[ii].ticket == 0)
              {
               allPositions[ii].ticket = positionTicket;
               allPositions[ii].acceptable_profit  = acceptable_profit_usd;
               break;
              }
           }
        }

      string symbol = PositionGetSymbol(i);
      if(_Symbol == symbol)
        {
         if(positionType == POSITION_TYPE_BUY && positionTakeProfit > 0 && positionStopLoss > 0 && ask > (positionStopLoss+(adjust_value_for_tp_sl)*_Point) && ask > (positionOpenPrice+(adjust_value_for_tp_sl)*_Point))
           {
            double newTP = positionTakeProfit;
            double newSL = positionStopLoss+(adjust_value_for_tp_sl)*_Point;
            if(newSL < (positionOpenPrice+(adjust_value_for_tp_sl)*_Point))
              {
               newSL = positionOpenPrice+(adjust_value_for_tp_sl)*_Point;
              }
            while(newSL > newTP)
              {
               newTP = positionTakeProfit+(adjust_value_for_tp_sl)*_Point;
              }
            trade.PositionModify(positionTicket,newSL,newTP);
            Print(positionTicket + " We have adjusted a buy position :(ask) " + ask + " (tp__): " + positionTakeProfit + " (sl__): " + positionStopLoss);
            Print(positionTicket + " We have adjusted a buy position :(ask) " + ask + " (tp): " + newTP + " (sl): " + newSL);
           }
         else
        if(acceptable_profit > 0 && profit >= (acceptable_profit))
          {
            acceptable_profit = profit;
            for(int ii =0; ii<ArraySize(allPositions); ii++)
            {
              if(allPositions[ii].ticket ==  positionTicket)
              {
                Print("=> BUY: We have adjusted the AC_PROFIT to " + acceptable_profit + " FROM " + allPositions[ii].acceptable_profit);
                allPositions[ii].acceptable_profit = acceptable_profit;
                break;
              }
            }
            Print("\nOpen price: " + positionOpenPrice + "\n ask " + ask + "\n diff: "+ (ask-positionOpenPrice) + " digits " + digits);
            double newSL = 0;
            double newStop = positionOpenPrice + ((ask - positionOpenPrice)/2);

            if(positionStopLoss > 0){
              newSL = positionStopLoss + ((acceptable_profit*digits)*SymbolInfoDouble(_Symbol,SYMBOL_POINT));
            }else{
              newSL = positionOpenPrice + ((acceptable_profit*digits)*SymbolInfoDouble(_Symbol,SYMBOL_POINT));
            }
            Print("----->>>>> Using new stop of : "+ newStop +" instead of :"+newSL + " ... price = "+ ask);
            trade.PositionModify(positionTicket,NormalizeDouble(newStop,digits),NULL);
          }

         if(positionType == POSITION_TYPE_SELL && positionTakeProfit > 0 && positionStopLoss > 0 && bid < (positionStopLoss-(adjust_value_for_tp_sl)*_Point) && bid < (positionOpenPrice-(adjust_value_for_tp_sl)*_Point))
           {
            double newTP = positionTakeProfit;
            double newSL = positionStopLoss-(adjust_value_for_tp_sl)*_Point;
            if(newSL > (positionOpenPrice-(adjust_value_for_tp_sl)*_Point))
              {
               newSL = positionOpenPrice-(adjust_value_for_tp_sl)*_Point;
              }
            while(newSL < newTP)
              {
               newTP = positionTakeProfit-(adjust_value_for_tp_sl)*_Point;
              }
            trade.PositionModify(positionTicket,newSL,newTP);
            Print(positionTicket + " We have adjusted a buy position :(ask) " + bid + " (tp__): " + positionTakeProfit + " (sl__): " + positionStopLoss);
            Print(positionTicket + " We have adjusted a buy position :(ask) " + bid + " (tp): " + newTP + " (sl): " + newSL);
           }
         else
            if(acceptable_profit > 0 && profit >= (acceptable_profit*1.5))
              {

               acceptable_profit = profit;
               for(int ii =0; ii<ArraySize(allPositions); ii++)
                 {
                  if(allPositions[ii].ticket ==  positionTicket)
                    {
                     Print("=> sell: We have adjusted the AC_PROFIT to " + acceptable_profit + " FROM " + allPositions[ii].acceptable_profit);
                     allPositions[ii].acceptable_profit = acceptable_profit;
                     break;
                    }
                 }            
                 double newSL = 0;
                if(positionStopLoss > 0){
                  newSL = positionStopLoss - ((acceptable_profit*digits)*SymbolInfoDouble(_Symbol,SYMBOL_POINT));
                }else{
                  newSL = positionOpenPrice - ((acceptable_profit*digits)*SymbolInfoDouble(_Symbol,SYMBOL_POINT));
                }
            
               Print("Current SL: "+newSL+" old SL : "+positionStopLoss);
               trade.PositionModify(positionTicket,NormalizeDouble(newSL,digits),NULL);
              }
         break;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckforBreakEvenBuy()
  {
   double price = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   for(int i = PositionsTotal()-1; i>=0; i--)
     {
      ulong positionTicket = PositionGetInteger(POSITION_TICKET);
      double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double positionStopLoss = PositionGetDouble(POSITION_SL);
      double positionTakeProfit = PositionGetDouble(POSITION_TP);
      double positionType = PositionGetInteger(POSITION_TYPE);
      double profit = PositionGetDouble(POSITION_PROFIT);

      string symbol = PositionGetSymbol(i);
      if(_Symbol == symbol)
        {
         if(positionType == POSITION_TYPE_BUY && positionTakeProfit > 0 && positionStopLoss > 0 && price > (positionStopLoss+(8)*_Point) && price > (positionOpenPrice+(8)*_Point))
           {
            double newTP = positionTakeProfit;
            double newSL = positionStopLoss+(4)*_Point;
            if(newSL < (positionOpenPrice+(4)*_Point))
              {
               newSL = positionOpenPrice+(4)*_Point;
              }
            while(newSL > newTP)
              {
               newTP = positionTakeProfit+(4)*_Point;
              }
            trade.PositionModify(positionTicket,newSL,newTP);
            Print(positionTicket + " We have adjusted a buy position :(price) " + price + " (tp__): " + positionTakeProfit + " (sl__): " + positionStopLoss);
            Print(positionTicket + " We have adjusted a buy position :(price) " + price + " (tp): " + newTP + " (sl): " + newSL);
           }
         else
            if(profit >= acceptable_profit)
              {
               acceptable_profit = profit;

               double newSL = positionOpenPrice + (acceptable_profit/2)*_Point;
               Print("=> BUY: We have adjusted the SL to " + newSL + " FROM " + positionStopLoss + " ,,  profit " + profit);
               trade.PositionModify(positionTicket,newSL,NULL);
              }
        }
     }
  }


void CloseAllBuyPositions(){
    double digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
    int stop_level=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*10;
    double price = SymbolInfoDouble(_Symbol,SYMBOL_BID); 
    for(int i = 0; i<PositionsTotal(); i++)
     {
      int positionType = PositionGetInteger(POSITION_TYPE);
      double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      if(_Symbol == PositionGetSymbol(i) && positionType == POSITION_TYPE_BUY){ 
       double newTP = positionOpenPrice + ((positionOpenPrice - price)/2);
        double newSL = price - ((positionOpenPrice - price)/2);   
        ulong positionTicket = PositionGetTicket(i);
       Print("::CLOSING BUYS " +positionType == POSITION_TYPE_BUY + " :: positionTicket: " +positionTicket +" TP: "+newTP+" -- SL: "+newSL+" -- PRICE: "+price+" -- POSITION_OPEN: "+positionOpenPrice + " -- digits: "+digits+" -- _Point: "+_Point+ " -- acceptable_profit: "+acceptable_profit+ "  -- stop_level: "+stop_level); 
       trade.PositionModify(positionTicket,newSL,newTP);
      }
     }
}

void CloseAllSellPositions(){
    double digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
    int stop_level=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*10;
    double price = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
    double symbolPoint = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
for(int i = 0; i<PositionsTotal(); i++)
    {
      int positionType = PositionGetInteger(POSITION_TYPE);
      double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      if(_Symbol == PositionGetSymbol(i) && positionType == POSITION_TYPE_SELL){
       ulong positionTicket = PositionGetTicket(i);
       double newTP = positionOpenPrice - ((price - positionOpenPrice)/2);
       double newSL = price + ((price - positionOpenPrice)/2); 
       Print("::CLOSING SELLS " + positionType == POSITION_TYPE_SELL + " :: positionTicket: " +positionTicket + " TP: "+newTP+" -- SL: "+newSL+" -- PRICE: "+price+" -- POSITION_OPEN: "+positionOpenPrice + " -- digits: "+digits+" -- _Point: "+symbolPoint+ " -- acceptable_profit: "+acceptable_profit+ "  -- stop_level: "+stop_level); 
       trade.PositionModify(positionTicket,newSL,newTP);
      }
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckforBreakEvenSell()
  {
   double price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   for(int i = PositionsTotal()-1; i>=0; i--)
     {
      ulong positionTicket = PositionGetInteger(POSITION_TICKET);
      double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double positionStopLoss = PositionGetDouble(POSITION_SL);
      double positionTakeProfit = PositionGetDouble(POSITION_TP);
      double positionType = PositionGetInteger(POSITION_TYPE);
      double profit = PositionGetDouble(POSITION_PROFIT);

      string symbol = PositionGetSymbol(i);
      if(_Symbol == symbol)
        {
         if(positionType == POSITION_TYPE_SELL && positionTakeProfit > 0 && positionStopLoss > 0 && price < (positionStopLoss-(8)*_Point) && price < (positionOpenPrice-(8)*_Point))
           {
            double newTP = positionTakeProfit;
            double newSL = positionStopLoss-(4)*_Point;
            if(newSL > (positionOpenPrice-(4)*_Point))
              {
               newSL = positionOpenPrice-(4)*_Point;
              }
            while(newSL < newTP)
              {
               newTP = positionTakeProfit-(4)*_Point;
              }
            trade.PositionModify(positionTicket,newSL,newTP);
           }
         else
            if(profit >= acceptable_profit)
              {
               acceptable_profit = profit;

               double newSL = positionOpenPrice - (acceptable_profit/2)*_Point;
               Print("=> SELL: We have adjusted the SL to " + newSL + " FROM " + positionStopLoss + " ,,  profit " + profit);
               trade.PositionModify(positionTicket,newSL,NULL);
              }
        }
     }
  }
//+------------------------------------------------------------------+
