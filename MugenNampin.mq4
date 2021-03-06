//+------------------------------------------------------------------+
//|                                                  MugenNampin.mq4 |
//|                           Copyright 2017, Palawan Software, Ltd. |
//|                             https://coconala.com/services/204383 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Palawan Software, Ltd."
#property link      "https://coconala.com/services/204383"
#property description "Author: Kotaro Hashimoto <hasimoto.kotaro@gmail.com>"
#property version   "1.00"
#property strict

// この番号の口座番号のアカウントでなければ稼働しない
const int Account_Number = 12345678;

const int Magic_Number = 1; //マジックナンバー
double Nampin_Span = 5.0; //ナンピン幅(pips)
input double Entry_Lot = 0.01; //初回エントリーロット数
const double Lot_Mult = 1.15; //ナンピンロット倍率
const int Mult_Trans_N = 4; //次のロット倍率に移行するナンピン回数
const double Lot_Mult2 = 1.45; //指定ナンピン回数以降のロット倍率
input bool Use_Trail = False; //金額トリーリングストップ有効/無効設定
input double Trail_Amount = 500; //金額トリーリングストップ幅（円）
input bool Use_TP = True; //指値利確有効/無効設定
double Take_Profit = 5; //指値利確幅(pips)
input int Max_Positions = 20; //最大ポジション数
const int Band_Period = 10; //ボリンジャーバンド計算期間

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

  Nampin_Span *= 10.0 * Point;
  Take_Profit *= 10.0 * Point;
      
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

double getAverageOpenPrice(int direction) {

  double price = 0.0;
  double amount = 0.0;

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(OrderMagicNumber() == Magic_Number && thisSymbol == Symbol()) {

        if(OrderType() == OP_BUY && direction == OP_BUY) {
          price += OrderOpenPrice() * OrderLots();
          amount += OrderLots();
        }
        else if(OrderType() == OP_SELL && direction == OP_SELL) {
          price += OrderOpenPrice() * OrderLots();
          amount += OrderLots();
        }
      }
    }
  }

  return 0 < amount ? price / amount : 1;
}


void modifyTakeProfit(double price, int direction) {

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(OrderMagicNumber() == Magic_Number && thisSymbol == Symbol()) {

        if(OrderType() == OP_BUY && direction == OP_BUY) {
          bool mod = OrderModify(OrderTicket(), OrderOpenPrice(), 0, price, 0);
        }
        else if(OrderType() == OP_SELL && direction == OP_SELL) {
          bool mod = OrderModify(OrderTicket(), OrderOpenPrice(), 0, price, 0);
        }
      }
    }
  }
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
          currentBuyLot = (currentBuyLot < OrderLots()) ? OrderLots() : currentBuyLot;
        }
        else if(OrderType() == OP_SELL) {
          shortProfit += OrderProfit();
          shortNum ++;
          currentSellLot = (currentSellLot < OrderLots()) ? OrderLots() : currentSellLot;
        }
      }
    }
  }
  
  if(longNum == 0) {
    longTrail = False;
    longSL = 0;
    currentBuyLot = Entry_Lot / Lot_Mult;
    longTP = 0;
  }
  else if(longSL < longProfit - Trail_Amount) {
    longTrail = True && Use_Trail;
    longSL = longProfit - Trail_Amount;
  }
  
  double longLotMult = ((Mult_Trans_N <= longNum + 1) ? Lot_Mult2 : Lot_Mult);
  
  if(shortNum == 0) {
    shortTrail = False;
    shortSL = 0;
    currentSellLot = Entry_Lot / Lot_Mult;
    shortTP = 0;
  }
  else if(shortSL < shortProfit - Trail_Amount) {
    shortTrail = True && Use_Trail;
    shortSL = shortProfit - Trail_Amount;
  }
  
  double shortLotMult = ((Mult_Trans_N <= shortNum + 1) ? Lot_Mult2 : Lot_Mult);


  double highestShort = 0;
  double lowestLong = 10000;
  
  bool cl = False;

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(OrderMagicNumber() == Magic_Number && thisSymbol == Symbol()) {
        
        if(OrderType() == OP_BUY) {

          bool closed = False;
          if(longTrail && longProfit < longSL) {
            closed = OrderClose(OrderTicket(), OrderLots(), Bid, 3);
          }
          if(!closed) {
            if(OrderOpenPrice() < lowestLong) {
              lowestLong = OrderOpenPrice();
            }
          }
          else {
            cl = True;
            i = -1;
            currentBuyLot /= longLotMult;
          }
        }
        else if(OrderType() == OP_SELL) {
      
          bool closed = False;
          if(shortTrail && shortProfit < shortSL) {
            closed = OrderClose(OrderTicket(), OrderLots(), Ask, 3);
          }
          if(!closed) {
            if(highestShort < OrderOpenPrice()) {
              highestShort = OrderOpenPrice();
            }
          }
          else {
            cl = True;
            i = -1;
            currentSellLot /= shortLotMult;
          }
        }
      }
    }
  }
  
  if(cl) {
    return;
  }

  if(OrdersTotal() < Max_Positions) {

    int sig = signal();
    
    if(highestShort + Nampin_Span < Bid && ((sig == OP_SELL && shortNum == 0) || 0 < shortNum) && longNum == 0) {
    
      currentSellLot *= shortLotMult;
      if(maxLot < currentSellLot) {
        currentSellLot = maxLot;
        Print("Lot size(", currentSellLot, ") is larger than max(", maxLot, "). Rounded to ", maxLot, ".");
      }
      else if(currentSellLot < minLot) {
        currentSellLot = minLot;
        Print("Lot size(", currentSellLot, ") is smaller than min(", minLot, "). Rounded to ", minLot, ".");
      }    
    
      if(Use_TP && 0 < shortNum) {
        double averagePrice = getAverageOpenPrice(OP_SELL);
        shortTP = NormalizeDouble(averagePrice - Take_Profit, Digits);

        modifyTakeProfit(shortTP, OP_SELL);
      }

      int ticket = OrderSend(Symbol(), OP_SELL, MathRound(currentSellLot / lotStep) * lotStep, Bid, 0, 0, shortTP, NULL, Magic_Number);
    }
    
    if(Ask < lowestLong - Nampin_Span && ((sig == OP_BUY && longNum == 0) || 0 < longNum) && shortNum == 0) {
    
      currentBuyLot *= longLotMult;
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
      if(Use_TP && 0 < longNum) {
        double averagePrice = getAverageOpenPrice(OP_BUY);
        longTP = NormalizeDouble(averagePrice + Take_Profit, Digits);

        modifyTakeProfit(longTP, OP_BUY);
      }
    
      int ticket = OrderSend(Symbol(), OP_BUY, MathRound(currentBuyLot / lotStep) * lotStep, Ask, 0, 0, longTP, NULL, Magic_Number);
    }
  }
}
//+------------------------------------------------------------------+
