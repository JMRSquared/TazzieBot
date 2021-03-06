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
input double acceptable_sell_profit_usd=10;
input double acceptable_buy_profit_usd=25;
input int max_concurrent_positions=10;
input int sellDelayHours=5;
input int buyDelayHours=5;

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
   for(int i =0; i<3; i++)
     {
      Print(i+ " => Position Ticket: "+allPositions[i].ticket);
      Print(i+ " => Position AC_PROFIT: "+allPositions[i].acceptable_profit);
     }
  }
 
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   double Balance=AccountBalance();
   double Equity=AccountEquity();

   double maSlow1 = iMA(NULL,0,10,0,MODE_EMA,PRICE_CLOSE,1);
   double maFast1 = iMA(NULL,0,40,0,MODE_EMA,PRICE_CLOSE,1);
   double maSlow2 = iMA(NULL,0,10,0,MODE_EMA,PRICE_CLOSE,2);
   double maFast2 = iMA(NULL,0,40,0,MODE_EMA,PRICE_CLOSE,2);

   AdjustTPandSL();

   string marketDirection = "";

   if(maSlow1 > maFast1)
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
     bool canBuy = ((current_ticks - lastBuyTime) > (buyDelayHours*3600));
     bool canSell = ((current_ticks - lastSellTime) > (sellDelayHours*3600));
     string canBuyString = "Yes";
     string canSellString = "Yes";
     if(!canBuy){
        canBuyString = "NO";
     }
     if(!canSell){
        canSellString = "NO";
     }
     Comment("\n Direction: "+marketDirection+
           "\n CAN SELL? :            "+canSellString+
           "\n CAN BUY? :            "+canBuyString+
           "\n\n"+
           "\n Balance:           "+Balance+
           "\n Equity:            "+Equity+
           "\n\n"+
           "\n PROFIT:            "+(Equity - Balance)+
           "\n Total OPEN Positions:   "+OrdersTotal()+
           "\n\n"+
           "\n\n"+
           "\n All Sells Count:            "+allPreviousSells+
           "\n All Buys Count:            "+allPreviousBuys+
           "\n\n"+
           "\n POSITIONS:         "+currentPositions+
           "\n\n"
    ,250);

   if(maSlow1>maFast1 && maSlow2<maFast2)
     {
      if(OrdersTotal() < max_concurrent_positions && (lastBuyTime == 0 || ((current_ticks - lastBuyTime) > (buyDelayHours*3600))))
        {
         allPreviousBuys++;
         lastBuyTime = current_ticks;
         lastSellTime = current_ticks;
         CloseAllSellPositions();
        }
     }
      
   if(maSlow1<maFast1 && maSlow2>maFast2)
     {
      if(OrdersTotal() < max_concurrent_positions && (lastSellTime == 0 || ((current_ticks - lastSellTime) > (sellDelayHours*3600))))
        {
          allPreviousSells++;
          lastSellTime = current_ticks;
          lastBuyTime = current_ticks;
          CloseAllBuyPositions();
        }
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void AdjustTPandSL()
  {
   double ask = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol(),SYMBOL_BID);
   double digits = (int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS);
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) {
        Print("Failed to select order "+i,GetLastError());
        continue;
      }
      ulong positionTicket = OrderTicket();
      double positionOpenPrice = OrderOpenPrice();
      double positionStopLoss = OrderStopLoss();
      double positionTakeProfit = OrderTakeProfit();
      double positionType = OrderType();
      double profit = OrderProfit();

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
         for(int iii =0; iii<ArraySize(allPositions); iii++)
           {
            if(allPositions[iii].ticket == 0)
              {
               allPositions[iii].ticket = positionTicket;
               if(positionType == OP_BUY){
                  allPositions[iii].acceptable_profit  = acceptable_buy_profit_usd;
               }else if(positionType == OP_SELL){
                  allPositions[iii].acceptable_profit  = acceptable_sell_profit_usd;
               }
               break;
              }
           }
        }

      if(Symbol() == OrderSymbol())
        {
          double newTP = 0;
          double newSL = 0;

         if(acceptable_profit > 0 && profit >= acceptable_profit*1.5)
          {
            acceptable_profit = profit;
            for(int j =0; j<ArraySize(allPositions); j++)
            {
              if(allPositions[j].ticket ==  positionTicket)
              {
                Print("=> BUY: We have adjusted the AC_PROFIT to " + acceptable_profit + " FROM " + allPositions[j].acceptable_profit);
                allPositions[j].acceptable_profit = acceptable_profit;
                break;
              }
            }
            Print("\nOpen price: " + positionOpenPrice + "\n ask " + ask + "\n diff: "+ (ask-positionOpenPrice) + " digits " + digits);
            double newStop = positionOpenPrice + ((ask - positionOpenPrice)/2);

            if(positionStopLoss > 0){
              newSL = positionStopLoss + ((acceptable_profit*digits)*SymbolInfoDouble(Symbol(),SYMBOL_POINT));
            }else{
              newSL = positionOpenPrice + ((acceptable_profit*digits)*SymbolInfoDouble(Symbol(),SYMBOL_POINT));
            }
            Print("----->>>>> Using new stop of : "+ newStop +" instead of :"+newSL + " ... price = "+ ask);
            OrderModify(positionTicket,OrderOpenPrice(),NormalizeDouble(newStop,digits),NULL,0,Blue);
          }

            if(acceptable_profit > 0 && profit >= acceptable_profit*1.5)
            {
               acceptable_profit = profit;
               for(int jj =0; jj<ArraySize(allPositions); jj++)
                 {
                  if(allPositions[jj].ticket ==  positionTicket)
                    {
                     Print("=> sell: We have adjusted the AC_PROFIT to " + acceptable_profit + " FROM " + allPositions[jj].acceptable_profit);
                     allPositions[jj].acceptable_profit = acceptable_profit;
                     break;
                    }
                 }            
                if(positionStopLoss > 0){
                  newSL = positionStopLoss - ((acceptable_profit*digits)*SymbolInfoDouble(Symbol(),SYMBOL_POINT));
                }else{
                  newSL = positionOpenPrice - ((acceptable_profit*digits)*SymbolInfoDouble(Symbol(),SYMBOL_POINT));
                }
            
               Print("Current SL: "+newSL+" old SL : "+positionStopLoss);
               OrderModify(positionTicket,OrderOpenPrice(),NormalizeDouble(newSL,digits),NULL,0,Blue);
              }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void CloseAllBuyPositions(){
    double digits = (int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS);
    int stop_level=(int)SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL)*10;
    double price = SymbolInfoDouble(Symbol(),SYMBOL_BID); 
    bool foundBuyPosition = false;
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) {
        Print("Failed to select order "+i,GetLastError());
        continue;
      }
      int positionType = OrderType();
      double positionOpenPrice = OrderOpenPrice();
      double profit = OrderProfit();
      double positionStopLoss = OrderStopLoss();
      if(Symbol() == OrderSymbol() && positionType == OP_BUY){ 
        double newSL = price - ((positionOpenPrice - price));   
        ulong positionTicket = OrderTicket();
        Print("::CLOSING BUYS " +positionType == OP_BUY + " :: positionTicket: " +positionTicket +" -- SL: "+newSL+" -- PRICE: "+price+" -- POSITION_OPEN: "+positionOpenPrice + " -- digits: "+digits+" -- _Point: "+_Point+ "  -- stop_level: "+stop_level); 
        foundBuyPosition = true;
        if(profit > acceptable_buy_profit_usd*0.75){
          OrderClose(positionTicket,volume,Ask,0,Pink);
        }else{
          if(positionStopLoss == NULL || positionStopLoss == 0){
            OrderModify(positionTicket,OrderOpenPrice(),newSL,NULL,0,Blue);
          }
        }
      }
     }
     if(!foundBuyPosition){
         OrderSend(Symbol(),OP_SELL,volume,Bid,2,NULL,NULL);
         Alert(GetLastError());
     }
}

void CloseAllSellPositions(){
    double digits = (int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS);
    int stop_level=(int)SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL)*10;
    double price = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
    double symbolPoint = SymbolInfoDouble(Symbol(),SYMBOL_POINT);
    bool foundSellPosition = false;
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) {
        Print("Failed to select order "+i,GetLastError());
        continue;
      }
      int positionType = OrderType();
      double positionOpenPrice = OrderOpenPrice();
      double profit = OrderProfit();
      double positionStopLoss = OrderStopLoss();
      if(Symbol() == OrderSymbol() && positionType == OP_SELL){
       ulong positionTicket = OrderTicket();
       double newSL = price + ((price - positionOpenPrice)); 
       Print("::CLOSING SELLS " + positionType == OP_SELL + " :: positionTicket: " +positionTicket +" -- SL: "+newSL+" -- PRICE: "+price+" -- POSITION_OPEN: "+positionOpenPrice + " -- digits: "+digits+" -- _Point: "+symbolPoint+ "  -- stop_level: "+stop_level); 
       foundSellPosition = true;
        if(profit > acceptable_sell_profit_usd*0.75){
          OrderClose(positionTicket,volume,Bid,0,Pink);
        }else{
        if(positionStopLoss == NULL || positionStopLoss == 0){
          OrderModify(positionTicket,OrderOpenPrice(),newSL,NULL,0,Blue);
        }
       }
      }
    }
    if(!foundSellPosition){
        OrderSend(Symbol(),OP_BUY,volume,Ask,2,NULL,NULL);
        Alert(GetLastError());
    }
}