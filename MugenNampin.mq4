//+------------------------------------------------------------------+
//|                                                  MugenNampin.mq4 |
//|                        Copyright 2016, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2016, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// この番号の口座番号のアカウントでなければ稼働しない
const int Account_Number = 12345678;

input int Magic_Number = 1; //マジックナンバー
input double Nampin_Span = 0.1; //ナンピン幅（円）
input double Entry_Lot = 0.01; //初回エントリーロット数
input double Lot_Mult = 1.05; //ナンピンロット倍率
input bool Use_Trail = True; //金額トリーリングストップ有効/無効設定
input double Trail_Amount = 1000; //金額トリーリングストップ幅（円）
input bool Use_TP = True; //指値利確有効/無効設定
input double Take_Profit = 0.2; //指値利確幅（円）
input double Max_Positions = 100; //最大ポジション数
input int Band_Period = 20; //ボリンジャーバンド計算期間

string thisSymbol;

bool longTrail;
bool shortTrail;

double longSL;
double shortSL;
double longTP;
double shortTP;

double minLot;
double maxLot;
double lotStep;

double currentBuyLot;
double currentSellLot;


int signal() {

  double upper = iBands(NULL, PERIOD_CURRENT, Band_Period, 1.0, 0, PRICE_WEIGHTED, 1, 0);
  double lower = iBands(NULL, PERIOD_CURRENT, Band_Period, 1.0, 0, PRICE_WEIGHTED, 2, 0);
  
  double price = (Ask + Bid) / 2.0;  
  if(price < lower) {
    return OP_BUY;
  }
  else if(upper < price) {
    return OP_SELL;
  }
  
  return -1;
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
  thisSymbol = Symbol();

  minLot = MarketInfo(Symbol(), MODE_MINLOT);
  maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
  lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
  
  currentBuyLot = Entry_Lot;
  currentSellLot = Entry_Lot;

  longTrail = False;
  longSL = 0;
  currentBuyLot = Entry_Lot;
  longTP = 0;

  shortTrail = False;
  shortSL = 0;
  currentSellLot = Entry_Lot;
  shortTP = 0;
     
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

  if(AccountNumber() != Account_Number) {
    Print("Account Number mismatch. No operation.: ", Account_Number);
    return;
  }

  double longProfit = 0;
  int longNum = 0;
  double shortProfit = 0;
  int shortNum = 0;

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && (OrderMagicNumber() == Magic_Number)) {
          
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
    currentBuyLot = Entry_Lot;
    longTP = 0;
  }
  else if(longSL < longProfit - Trail_Amount) {
    longTrail = True && Use_Trail;
    longSL = longProfit - Trail_Amount;
  }
  
  if(shortNum == 0) {
    shortTrail = False;
    shortSL = 0;
    currentSellLot = Entry_Lot;
    shortTP = 0;
  }
  else if(shortSL < shortProfit - Trail_Amount) {
    shortTrail = True && Use_Trail;
    shortSL = shortProfit - Trail_Amount;
  }

  double highestShort = 0;
  double lowestLong = 10000;

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(OrderMagicNumber() == Magic_Number && thisSymbol == Symbol()) {
        
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
            currentBuyLot /= Lot_Mult;
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
            currentSellLot /= Lot_Mult;
          }
        }
      }
    }
  }

  if(OrdersTotal() < Max_Positions) {

    int sig = signal();
    
    if(highestShort + Nampin_Span < Bid && sig == OP_SELL) {
    
      currentSellLot *= Lot_Mult;
      if(maxLot < currentSellLot) {
        currentSellLot = maxLot;
        Print("Lot size(", currentSellLot, ") is larger than max(", maxLot, "). Rounded to ", maxLot, ".");
      }
      else if(currentSellLot < minLot) {
        currentSellLot = minLot;
        Print("Lot size(", currentSellLot, ") is smaller than min(", minLot, "). Rounded to ", minLot, ".");
      }    
    
      if(shortNum == 0 && Use_TP) {
        shortTP = NormalizeDouble(Bid - Take_Profit, Digits);
      }

      int ticket = OrderSend(Symbol(), OP_SELL, MathRound(currentSellLot / lotStep) * lotStep, Bid, 0, 0, shortTP, NULL, Magic_Number);
    }
    
    if(Ask < lowestLong - Nampin_Span && sig == OP_BUY) {
    
      currentBuyLot *= Lot_Mult;
      if(maxLot < currentBuyLot) {
        currentBuyLot = maxLot;
        Print("Lot size(", currentBuyLot, ") is larger than max(", maxLot, "). Rounded to ", maxLot, ".");
      }
      else if(currentBuyLot < minLot) {
        currentBuyLot = minLot;
        Print("Lot size(", currentBuyLot, ") is smaller than min(", minLot, "). Rounded to ", minLot, ".");
      }
      
      if(longNum == 0 && Use_TP) {
        longTP = NormalizeDouble(Ask + Take_Profit, Digits);
      }
    
      int ticket = OrderSend(Symbol(), OP_BUY, MathRound(currentBuyLot / lotStep) * lotStep, Ask, 0, 0, longTP, NULL, Magic_Number);
    }
  }
}
//+------------------------------------------------------------------+
