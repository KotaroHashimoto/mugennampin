//+------------------------------------------------------------------+
//|                                                  MugenNampin.mq4 |
//|                        Copyright 2016, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2016, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

input int Magic_Number = 1; //マジックナンバー
input double Entry_Lot = 0.01; //エントリーロットサイズ
input double Nampin_Span = 0.1; //ナンピン幅
input double Take_Profit = 1000; //トレーリングストップ幅（円）
input double Max_Positions = 100; //最大ポジション数

string thisSymbol;

bool longTrail;
bool shortTrail;
double longSL;
double shortSL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
  thisSymbol = Symbol();
  
  longTrail = False;
  longSL = 0;
  
  shortTrail = False;
  shortSL = 0;
     
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

  double longProfit = 0;
  int longNum = 0;
  double shortProfit = 0;
  int shortNum = 0;

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderMagicNumber() == Magic_Number && thisSymbol == Symbol()) {
      if(OrderSelect(i, SELECT_BY_POS)) {
        if(OrderType() == OP_BUY) {
          longProfit += OrderProfit();
          longNum ++;
        }
        else if(OrderType() == OP_SELL) {
          shortProfit += OrderProfit();
          shortNum ++;
        }
      }
    }
  }
  
  if(longNum == 0) {
    longTrail = False;
    longSL = 0;
  }
  else if(longSL < longProfit - Take_Profit) {
    longTrail = True;
    longSL = longProfit - Take_Profit;
    
  }
  
  if(shortNum == 0) {
    shortTrail = False;
    shortSL = 0;
  }
  else if(shortSL < shortProfit - Take_Profit) {
    shortTrail = True;
    shortSL = shortProfit - Take_Profit;    
  }
  
  double highestShort = 0;
  double lowestLong = 10000;

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderMagicNumber() == Magic_Number && thisSymbol == Symbol()) {
      if(OrderSelect(i, SELECT_BY_POS)) {
        if(OrderType() == OP_BUY) {

          bool closed = False;
          if(longTrail && longProfit < longSL) {
            closed = OrderClose(OrderTicket(), OrderLots(), Bid, 0);
          }
          if(!closed) {
            if(OrderOpenPrice() < lowestLong) {
              lowestLong = OrderOpenPrice();
            }
          }
          else {
            longSL = 0;
            longTrail = False;
          }
        }
        else if(OrderType() == OP_SELL) {
      
          bool closed = False;
          if(shortTrail && shortProfit < shortSL) {
            closed = OrderClose(OrderTicket(), OrderLots(), Ask, 0);
          }
          if(!closed) {
            if(highestShort < OrderOpenPrice()) {
              highestShort = OrderOpenPrice();
            }
          }
          else {
            shortSL = 0;
            shortTrail = False;
          }
        }
      }
    }
  }

  if(OrdersTotal() < Max_Positions) {
    if(highestShort + Nampin_Span < Bid) {
      int ticket = OrderSend(Symbol(), OP_SELL, Entry_Lot, Bid, 0, 0, 0, NULL, Magic_Number);
    }
    if(Ask < lowestLong - Nampin_Span) {
      int ticket = OrderSend(Symbol(), OP_BUY, Entry_Lot, Ask, 0, 0, 0, NULL, Magic_Number);
    }
  }
}
//+------------------------------------------------------------------+
