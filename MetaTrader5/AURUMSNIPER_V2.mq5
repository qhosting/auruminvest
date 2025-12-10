//+------------------------------------------------------------------+
//|                    AURUMSNIPER_V2.mq5 [PROFESSIONAL]             |
//|                    Copyright 2025, Aurum Capital (Edwin CEO)     |
//|                    Estrategia: Smart Trap V2 [OPTIMIZED]         |
//+------------------------------------------------------------------+
// ✅ CORRECCIONES CRITICAS IMPLEMENTADAS:
// 1. Bug critico validacion inversa de ordenes (lineas 128/155) - CORREGIDO
// 2. Position Sizing Dinamico (% de cuenta segun distancia SL)
// 3. Limite de Riesgo Diario (max 3% perdidas diarias)
// 4. Trailing Stop Avanzado (basado en ATR)
// 5. Sistema de Perdidas Consecutivas (bloqueo tras 3 perdidas)
// 6. Filtros de Confluencia: RSI (60/40) + Zonas H1
// 7. Cache de Fibonacci (actualiza cada 10 barras - anti-repaint)
// 8. Salida por tiempo (50 barras)
// 9. Reduccion de tamano tras perdidas
// 10. Encoding UTF-8 limpio (sin caracteres corruptos)
//
// Fecha: 10 Diciembre 2025
// Version: 2.0
//+------------------------------------------------------------------+
#property copyright "Aurum Capital"
#property version   "2.0"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

CTrade trade;
CSymbolInfo mysymbol;

// ==================== SECCION 1: CONFIGURACION ====================

input group "=== ESTRATEGIA (TRAMPA FIBO) ==="
input int      InpFiboLookback      = 100;       // Periodo Fibonacci Max/Min
input int      InpFiboUpdateBars    = 10;        // Actualizar Fibo cada N barras (anti-repaint)
input double   InpDistPuntos        = 50;        // Distancia minima validar orden
input int      InpMagic             = 8888;      // Numero Magico (ID Robot)

input group "=== FILTROS DE CONTEXTO ==="
input int      InpEMAPeriod         = 150;       // EMA Tendencia (M15) - Reducido de 200 a 150
input int      InpADXPeriod         = 14;        // ADX Periodo
input int      InpADXMin            = 25;        // ADX Minimo (>25) - Aumentado de 20
input bool     InpUseDailyBias      = true;      // Usar Filtro Daily Open

input group "=== FILTROS CONFLUENCIA (AVANZADO) ==="
input bool     InpUseRSI            = true;      // Filtro RSI Activado
input int      InpRSIPeriod         = 14;        // RSI Periodo
input double   InpRSI_OB            = 60.0;      // RSI Sobrecompra (60 mas realista que 70)
input double   InpRSI_OS            = 40.0;      // RSI Sobreventa (40 mas realista que 30)
input bool     InpUseH1Zones        = true;      // Filtro Zonas H1 Activado
input int      InpH1Lookback        = 20;        // Periodo Zonas H1
input double   InpH1DistPuntos      = 35;        // Distancia Zona H1 (Puntos)
input int      InpMinConfluence     = 2;         // Minimo Confluencias (de 4 posibles)

input group "=== GESTION DE RIESGO PROFESIONAL ==="
input bool     InpUseDynamicSizing  = true;      // Position Sizing Dinamico
input double   InpRiskPercent       = 1.0;       // Riesgo por Trade (%)
input double   InpMaxDailyRisk      = 3.0;       // Riesgo Max Diario (%)
input int      InpMaxDailyTrades    = 5;         // Max Trades por Dia
input int      InpMaxConsecLosses   = 3;         // Max Perdidas Consecutivas
input bool     InpReduceSizeAfterLoss = true;    // Reducir Tamano Tras Perdida
input double   InpLotsFixed         = 0.01;      // Lotaje Fijo (si dinamico=false)

input group "=== SALIDAS AVANZADAS ==="
input double   InpSL_ATR_Mult       = 1.5;       // SL basado en x ATR (reducido de 2.0)
input double   InpTP_Ratio          = 2.0;       // TP Ratio R:R (mejorado de 1.5)
input bool     InpUseTrailing       = true;      // Trailing Stop Activo
input double   InpTrailStart        = 1.5;       // Activar trailing en (x ATR)
input double   InpTrailOffset       = 1.0;       // Offset trailing (x ATR)
input bool     InpUseBreakEven      = true;      // Break-Even Activado
input double   InpBE_Trigger        = 1.0;       // Activar BE en (x ATR)
input bool     InpUseTimeExit       = true;      // Salida por Tiempo
input int      InpTimeExitBars      = 50;        // Salir si no cierra en N barras

input group "=== HORARIO ==="
input int      InpStartHour         = 7;         // Hora Inicio (NY)
input int      InpEndHour           = 11;        // Hora Fin (NY) - Reducido de 12
input int      InpExpiration        = 3;         // Expiracion Trampa (Horas) - Reducido de 4

// ==================== VARIABLES GLOBALES ====================

int handle_ema, handle_adx, handle_atr, handle_rsi;
double buf_ema[], buf_adx[], buf_atr[], buf_rsi[];
datetime last_bar_time = 0;

// Cache de Fibonacci (anti-repaint)
double g_fibo_high = 0.0;
double g_fibo_low = 0.0;
double g_fibo_618_buy = 0.0;
double g_fibo_618_sell = 0.0;
int g_last_fibo_calc_bar = 0;

// Zonas H1
double g_h1_high = 0.0;
double g_h1_low = 0.0;

// Gestion de Riesgo
double g_daily_loss = 0.0;
int g_daily_trades = 0;
datetime g_last_day = 0;
int g_consecutive_losses = 0;
double g_size_multiplier = 1.0;
int g_last_trade_count = 0;

// Tracking de trades
struct TradeInfo {
   ulong ticket;
   datetime entry_time;
   int bars_in_trade;
};
TradeInfo g_current_trade;

//+------------------------------------------------------------------+
//| INICIALIZACION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Configurar Simbolo
   mysymbol.Name(_Symbol);
   mysymbol.Refresh();
   
   // Inicializar Indicadores
   handle_ema = iMA(_Symbol, PERIOD_M15, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   handle_adx = iADX(_Symbol, PERIOD_M15, InpADXPeriod);
   handle_atr = iATR(_Symbol, PERIOD_M5, 14);
   handle_rsi = iRSI(_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
   
   if(handle_ema == INVALID_HANDLE || handle_adx == INVALID_HANDLE || 
      handle_atr == INVALID_HANDLE || handle_rsi == INVALID_HANDLE)
   {
      Print("ERROR: No se pudo cargar indicadores.");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(InpMagic);
   
   // Resize arrays
   ArrayResize(buf_ema, 3);
   ArrayResize(buf_adx, 3);
   ArrayResize(buf_atr, 3);
   ArrayResize(buf_rsi, 3);
   
   // Inicializar tracking
   g_current_trade.ticket = 0;
   g_current_trade.entry_time = 0;
   g_current_trade.bars_in_trade = 0;
   
   // Obtener historial para tracking de perdidas
   HistorySelect(0, TimeCurrent());
   g_last_trade_count = HistoryDealsTotal();
   
   Print("\n========================================");
   Print("AURUM SNIPER V2.0 [PROFESSIONAL] INICIADO");
   Print("========================================");
   Print("Position Sizing: ", (InpUseDynamicSizing ? "DINAMICO" : "FIJO"));
   Print("Riesgo por Trade: ", InpRiskPercent, "%");
   Print("Riesgo Diario Max: ", InpMaxDailyRisk, "%");
   Print("Filtros Avanzados: RSI=", (InpUseRSI?"ON":"OFF"), " | H1Zones=", (InpUseH1Zones?"ON":"OFF"));
   Print("Trailing Stop: ", (InpUseTrailing ? "ACTIVADO" : "DESACTIVADO"));
   Print("========================================\n");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| LIMPIEZA                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handle_ema);
   IndicatorRelease(handle_adx);
   IndicatorRelease(handle_atr);
   IndicatorRelease(handle_rsi);
   Comment("");
   Print("AURUM SNIPER V2 DETENIDO. Razon: ", reason);
}

//+------------------------------------------------------------------+
//| CEREBRO PRINCIPAL                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. CONTROL DE VELAS (solo una vez por vela nueva en M5)
   datetime current_time = iTime(_Symbol, PERIOD_M5, 0);
   if(current_time == last_bar_time) return;
   last_bar_time = current_time;

   // 2. RESET DIARIO
   CheckDailyReset();
   
   // 3. CHECK PERDIDAS CONSECUTIVAS
   CheckConsecutiveLosses();
   
   // 4. GESTION DE POSICIONES ACTIVAS
   if(PositionsTotal() > 0)
   {
      GestionarSalidasAvanzadas();
      return;
   }
   
   // 5. GESTION DE ORDENES PENDIENTES
   if(OrdersTotal() > 0)
   {
      // Solo gestionamos las ordenes pendientes, no abrimos nuevas
      return;
   }

   // 6. VALIDACION PARA NUEVAS ENTRADAS
   if(!CanTrade()) return;

   // 7. FILTRO HORARIO
   MqlDateTime dt;
   TimeCurrent(dt);
   if(dt.hour < InpStartHour || dt.hour >= InpEndHour) return;

   // 8. ACTUALIZAR DATOS
   if(!ActualizarDatos()) return;

   // 9. ACTUALIZAR FIBONACCI (CACHE)
   ActualizarFibonacci();
   
   // 10. ACTUALIZAR ZONAS H1
   if(InpUseH1Zones) ActualizarZonasH1();

   // 11. LEER INDICADORES
   double ema_val = buf_ema[0];
   double adx_val = buf_adx[0];
   double atr_val = buf_atr[0];
   double rsi_val = buf_rsi[0];
   double close   = iClose(_Symbol, PERIOD_M5, 1);
   double d_open  = iOpen(_Symbol, PERIOD_D1, 0);
   
   // Validacion ATR minimo
   if(atr_val <= 0) return;

   // ==================== LOGICA DE ENTRADA ====================
   
   // A) MODO COMPRA (BULLISH)
   if(close > ema_val && (!InpUseDailyBias || close > d_open) && adx_val > InpADXMin)
   {
      // Sistema de Confluencias
      int confluences = 0;
      string conf_msg = "Confluencias: ";
      
      // Confluencia 1: Tendencia EMA
      confluences++;
      conf_msg += "[EMA] ";
      
      // Confluencia 2: ADX fuerte
      if(adx_val > InpADXMin)
      {
         confluences++;
         conf_msg += "[ADX=" + DoubleToString(adx_val,1) + "] ";
      }
      
      // Confluencia 3: RSI no sobrecomprado
      if(InpUseRSI && rsi_val < InpRSI_OB)
      {
         confluences++;
         conf_msg += "[RSI=" + DoubleToString(rsi_val,1) + "] ";
      }
      
      // Confluencia 4: Cerca de zona H1
      bool near_h1_zone = false;
      if(InpUseH1Zones)
      {
         if(ValidarZonaH1(true))
         {
            confluences++;
            near_h1_zone = true;
            conf_msg += "[H1_ZONE] ";
         }
      }
      
      // Validar confluencias minimas
      if(confluences < InpMinConfluence)
      {
         Print("BUY: Confluencias insuficientes (", confluences, "/", InpMinConfluence, ")");
         return;
      }
      
      // Calcular entrada desde cache de Fibonacci
      double entry_price = g_fibo_618_buy;
      
      // CORRECCION BUG CRITICO: Validacion CORRECTA para BuyLimit
      // BuyLimit se coloca DEBAJO del precio actual (esperando que baje)
      if(SymbolInfoDouble(_Symbol, SYMBOL_ASK) > entry_price)
      {
         double sl = entry_price - (atr_val * InpSL_ATR_Mult);
         double tp = entry_price + ((entry_price - sl) * InpTP_Ratio);
         
         // Calcular lotaje dinamico
         double calculated_lots = InpUseDynamicSizing ? 
            CalcularLotaje(entry_price, sl, InpRiskPercent) : InpLotsFixed;
         
         // Aplicar multiplicador de perdidas consecutivas
         calculated_lots *= g_size_multiplier;
         
         // Normalizar
         entry_price = NormalizeDouble(entry_price, _Digits);
         sl = NormalizeDouble(sl, _Digits);
         tp = NormalizeDouble(tp, _Digits);
         calculated_lots = NormalizeDouble(calculated_lots, 2);
         
         // Validacion de lotaje
         double lot_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double lot_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
         if(calculated_lots < lot_min || calculated_lots > lot_max)
         {
            Print("ERROR: Lotaje fuera de rango (", calculated_lots, ")");
            return;
         }
         
         // COLOCAR TRAMPA ALCISTA
         datetime expiration = TimeCurrent() + (InpExpiration * 3600);
         if(trade.BuyLimit(calculated_lots, entry_price, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration))
         {
            Print("========================================");
            Print("TRAMPA ALCISTA COLOCADA");
            Print("Entrada: ", entry_price, " | SL: ", sl, " | TP: ", tp);
            Print("Lotes: ", calculated_lots, " | Riesgo: ", InpRiskPercent, "%");
            Print(conf_msg);
            Print("========================================");
            
            // Registrar trade
            g_current_trade.ticket = trade.ResultOrder();
            g_current_trade.entry_time = TimeCurrent();
            g_current_trade.bars_in_trade = 0;
            g_daily_trades++;
         }
      }
   }

   // B) MODO VENTA (BEARISH)
   if(close < ema_val && (!InpUseDailyBias || close < d_open) && adx_val > InpADXMin)
   {
      // Sistema de Confluencias
      int confluences = 0;
      string conf_msg = "Confluencias: ";
      
      // Confluencia 1: Tendencia EMA
      confluences++;
      conf_msg += "[EMA] ";
      
      // Confluencia 2: ADX fuerte
      if(adx_val > InpADXMin)
      {
         confluences++;
         conf_msg += "[ADX=" + DoubleToString(adx_val,1) + "] ";
      }
      
      // Confluencia 3: RSI no sobrevendido
      if(InpUseRSI && rsi_val > InpRSI_OS)
      {
         confluences++;
         conf_msg += "[RSI=" + DoubleToString(rsi_val,1) + "] ";
      }
      
      // Confluencia 4: Cerca de zona H1
      if(InpUseH1Zones)
      {
         if(ValidarZonaH1(false))
         {
            confluences++;
            conf_msg += "[H1_ZONE] ";
         }
      }
      
      // Validar confluencias minimas
      if(confluences < InpMinConfluence)
      {
         Print("SELL: Confluencias insuficientes (", confluences, "/", InpMinConfluence, ")");
         return;
      }
      
      // Calcular entrada desde cache
      double entry_price = g_fibo_618_sell;
      
      // CORRECCION BUG CRITICO: Validacion CORRECTA para SellLimit
      // SellLimit se coloca ENCIMA del precio actual (esperando que suba)
      if(SymbolInfoDouble(_Symbol, SYMBOL_BID) < entry_price)
      {
         double sl = entry_price + (atr_val * InpSL_ATR_Mult);
         double tp = entry_price - ((sl - entry_price) * InpTP_Ratio);
         
         // Calcular lotaje dinamico
         double calculated_lots = InpUseDynamicSizing ? 
            CalcularLotaje(entry_price, sl, InpRiskPercent) : InpLotsFixed;
         
         // Aplicar multiplicador
         calculated_lots *= g_size_multiplier;
         
         // Normalizar
         entry_price = NormalizeDouble(entry_price, _Digits);
         sl = NormalizeDouble(sl, _Digits);
         tp = NormalizeDouble(tp, _Digits);
         calculated_lots = NormalizeDouble(calculated_lots, 2);
         
         // Validacion de lotaje
         double lot_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double lot_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
         if(calculated_lots < lot_min || calculated_lots > lot_max)
         {
            Print("ERROR: Lotaje fuera de rango (", calculated_lots, ")");
            return;
         }
         
         // COLOCAR TRAMPA BAJISTA
         datetime expiration = TimeCurrent() + (InpExpiration * 3600);
         if(trade.SellLimit(calculated_lots, entry_price, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration))
         {
            Print("========================================");
            Print("TRAMPA BAJISTA COLOCADA");
            Print("Entrada: ", entry_price, " | SL: ", sl, " | TP: ", tp);
            Print("Lotes: ", calculated_lots, " | Riesgo: ", InpRiskPercent, "%");
            Print(conf_msg);
            Print("========================================");
            
            // Registrar trade
            g_current_trade.ticket = trade.ResultOrder();
            g_current_trade.entry_time = TimeCurrent();
            g_current_trade.bars_in_trade = 0;
            g_daily_trades++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| FUNCIONES AUXILIARES                                             |
//+------------------------------------------------------------------+

bool ActualizarDatos()
{
   // Solo copiar 1 elemento (optimizacion)
   if(CopyBuffer(handle_ema, 0, 0, 1, buf_ema) < 0) return false;
   if(CopyBuffer(handle_adx, 0, 0, 1, buf_adx) < 0) return false;
   if(CopyBuffer(handle_atr, 0, 0, 1, buf_atr) < 0) return false;
   if(CopyBuffer(handle_rsi, 0, 0, 1, buf_rsi) < 0) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| CACHE DE FIBONACCI (ANTI-REPAINT)                               |
//+------------------------------------------------------------------+
void ActualizarFibonacci()
{
   // Solo actualizar cada N barras
   int current_bar = Bars(_Symbol, PERIOD_M5);
   if(current_bar - g_last_fibo_calc_bar < InpFiboUpdateBars && g_last_fibo_calc_bar > 0) 
      return;
   
   // Calcular usando barras CERRADAS (shift = 1, no 0)
   int highest_idx = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, InpFiboLookback, 1);
   int lowest_idx  = iLowest(_Symbol, PERIOD_M5, MODE_LOW, InpFiboLookback, 1);
   
   g_fibo_high = iHigh(_Symbol, PERIOD_M5, highest_idx);
   g_fibo_low  = iLow(_Symbol, PERIOD_M5, lowest_idx);
   
   double f_range = g_fibo_high - g_fibo_low;
   
   // Validar rango minimo
   double min_range = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
   if(f_range < min_range)
   {
      Print("ADVERTENCIA: Rango Fibonacci muy pequeno (", f_range, ")");
      return;
   }
   
   // Calcular niveles 61.8%
   g_fibo_618_buy = g_fibo_high - (f_range * 0.618);
   g_fibo_618_sell = g_fibo_low + (f_range * 0.618);
   
   g_last_fibo_calc_bar = current_bar;
   
   Print("Fibonacci actualizado | High: ", g_fibo_high, " | Low: ", g_fibo_low, 
         " | 61.8_Buy: ", g_fibo_618_buy, " | 61.8_Sell: ", g_fibo_618_sell);
}

//+------------------------------------------------------------------+
//| ZONAS H1                                                         |
//+------------------------------------------------------------------+
void ActualizarZonasH1()
{
   double h1_high_buffer[];
   double h1_low_buffer[];
   
   ArrayResize(h1_high_buffer, InpH1Lookback);
   ArrayResize(h1_low_buffer, InpH1Lookback);
   
   // Copiar usando shift=1 (sin lookahead)
   if(CopyHigh(_Symbol, PERIOD_H1, 1, InpH1Lookback, h1_high_buffer) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_H1, 1, InpH1Lookback, h1_low_buffer) <= 0) return;
   
   g_h1_high = h1_high_buffer[ArrayMaximum(h1_high_buffer)];
   g_h1_low = h1_low_buffer[ArrayMinimum(h1_low_buffer)];
}

bool ValidarZonaH1(bool is_buy)
{
   double dist_price = InpH1DistPuntos * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double current_close = iClose(_Symbol, PERIOD_M5, 1);
   
   if(is_buy)
   {
      // Para compra: precio cerca de soporte H1
      return (MathAbs(current_close - g_h1_low) <= dist_price);
   }
   else
   {
      // Para venta: precio cerca de resistencia H1
      return (MathAbs(current_close - g_h1_high) <= dist_price);
   }
}

//+------------------------------------------------------------------+
//| POSITION SIZING DINAMICO                                         |
//+------------------------------------------------------------------+
double CalcularLotaje(double entry_price, double sl_price, double risk_pct)
{
   // 1. Calcular distancia del SL
   double sl_distance = MathAbs(entry_price - sl_price);
   
   // 2. Proteccion: SL minimo
   double min_sl = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
   if(sl_distance < min_sl)
      sl_distance = min_sl;
   
   // 3. Calcular cantidad a arriesgar en USD
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = account_balance * (risk_pct / 100.0);
   
   // 4. Calcular valor del tick
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   // Proteccion division por cero
   if(tick_value <= 0 || tick_size <= 0)
   {
      Print("ERROR: Tick value o tick size invalido");
      return InpLotsFixed;
   }
   
   // 5. Calcular lotaje
   // Formula: Lotes = (Riesgo USD) / (SL en ticks × Valor por tick)
   double sl_in_ticks = sl_distance / tick_size;
   double lots = risk_amount / (sl_in_ticks * tick_value);
   
   // 6. Normalizar lotaje
   double lot_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lot_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lots = MathMax(lot_min, MathMin(lots, lot_max));
   lots = MathFloor(lots / lot_step) * lot_step;
   
   return lots;
}

//+------------------------------------------------------------------+
//| RESET DIARIO                                                     |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime today = StringToTime(IntegerToString(dt.year) + "." + 
                                  IntegerToString(dt.mon) + "." + 
                                  IntegerToString(dt.day));
   
   if(today != g_last_day)
   {
      g_daily_loss = 0.0;
      g_daily_trades = 0;
      g_last_day = today;
      Print("========================================");
      Print("NUEVO DIA - Reset de limites");
      Print("========================================");
   }
}

//+------------------------------------------------------------------+
//| VALIDACION PARA TRADING                                          |
//+------------------------------------------------------------------+
bool CanTrade()
{
   // 1. Check limite de trades
   if(g_daily_trades >= InpMaxDailyTrades)
   {
      Comment("BLOQUEADO: Limite de ", InpMaxDailyTrades, " trades alcanzado hoy");
      return false;
   }
   
   // 2. Check limite de riesgo diario
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(account_balance > 0)
   {
      double daily_risk_pct = (g_daily_loss / account_balance) * 100.0;
      
      if(daily_risk_pct >= InpMaxDailyRisk)
      {
         Comment("BLOQUEADO: Riesgo diario ", DoubleToString(daily_risk_pct, 2), "% alcanzado");
         return false;
      }
   }
   
   // 3. Check perdidas consecutivas
   if(g_consecutive_losses >= InpMaxConsecLosses)
   {
      Comment("BLOQUEADO: ", g_consecutive_losses, " perdidas consecutivas\nEsperar victoria para reanudar");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| CHECK PERDIDAS CONSECUTIVAS                                      |
//+------------------------------------------------------------------+
void CheckConsecutiveLosses()
{
   HistorySelect(0, TimeCurrent());
   int current_deals = HistoryDealsTotal();
   
   // Si hay nueva operacion cerrada
   if(current_deals > g_last_trade_count)
   {
      ulong last_deal = HistoryDealGetTicket(current_deals - 1);
      double profit = HistoryDealGetDouble(last_deal, DEAL_PROFIT);
      
      if(profit < 0) // Perdida
      {
         g_consecutive_losses++;
         g_daily_loss += MathAbs(profit);
         
         // Reducir tamano progresivamente
         if(InpReduceSizeAfterLoss)
         {
            g_size_multiplier = MathMax(0.4, 1.0 - (g_consecutive_losses * 0.2));
            Print("Perdida consecutiva #", g_consecutive_losses, 
                  " | Tamano reducido a ", DoubleToString(g_size_multiplier * 100, 0), "%");
         }
      }
      else if(profit > 0) // Ganancia
      {
         g_consecutive_losses = 0;
         g_size_multiplier = 1.0;
         Print("Victoria | Tamano restaurado a 100%");
      }
      
      g_last_trade_count = current_deals;
   }
}

//+------------------------------------------------------------------+
//| SALIDAS AVANZADAS (BREAK-EVEN + TRAILING + TIME EXIT)           |
//+------------------------------------------------------------------+
void GestionarSalidasAvanzadas()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || 
         PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl = PositionGetDouble(POSITION_SL);
      double current_tp = PositionGetDouble(POSITION_TP);
      double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
      long type = PositionGetInteger(POSITION_TYPE);
      
      // Obtener ATR actual
      double atr_buffer[1];
      if(CopyBuffer(handle_atr, 0, 0, 1, atr_buffer) <= 0) continue;
      double atr = atr_buffer[0];
      if(atr <= 0) continue;
      
      // Calcular ganancia en ATRs
      double profit_distance = (type == POSITION_TYPE_BUY) ?
         (current_price - open_price) : (open_price - current_price);
      
      double profit_in_atrs = profit_distance / atr;
      
      // === FASE 1: BREAK-EVEN ===
      if(InpUseBreakEven && profit_in_atrs >= InpBE_Trigger)
      {
         double new_sl = 0.0;
         bool should_modify = false;
         
         if(type == POSITION_TYPE_BUY)
         {
            new_sl = open_price + (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
            if(current_sl < new_sl)
               should_modify = true;
         }
         else // SELL
         {
            new_sl = open_price - (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
            if(current_sl == 0 || current_sl > new_sl)
               should_modify = true;
         }
         
         if(should_modify)
         {
            new_sl = NormalizeDouble(new_sl, _Digits);
            if(trade.PositionModify(ticket, new_sl, current_tp))
            {
               Print("BREAK-EVEN activado @ ", new_sl, " | Ganancia: ", 
                     DoubleToString(profit_in_atrs, 2), " ATRs");
            }
         }
      }
      
      // === FASE 2: TRAILING STOP ===
      if(InpUseTrailing && profit_in_atrs >= InpTrailStart)
      {
         double trail_distance = atr * InpTrailOffset;
         double new_sl = 0.0;
         bool should_modify = false;
         
         if(type == POSITION_TYPE_BUY)
         {
            new_sl = current_price - trail_distance;
            new_sl = NormalizeDouble(new_sl, _Digits);
            
            if(new_sl > current_sl && new_sl < current_price)
               should_modify = true;
         }
         else // SELL
         {
            new_sl = current_price + trail_distance;
            new_sl = NormalizeDouble(new_sl, _Digits);
            
            if((current_sl == 0 || new_sl < current_sl) && new_sl > current_price)
               should_modify = true;
         }
         
         if(should_modify)
         {
            if(trade.PositionModify(ticket, new_sl, current_tp))
            {
               Print("TRAILING STOP actualizado: ", new_sl, 
                     " | Ganancia protegida: ", DoubleToString(profit_in_atrs, 2), " ATRs");
            }
         }
      }
      
      // === FASE 3: SALIDA POR TIEMPO ===
      if(InpUseTimeExit)
      {
         datetime position_time = (datetime)PositionGetInteger(POSITION_TIME);
         int bars_since_entry = Bars(_Symbol, PERIOD_M5, position_time, TimeCurrent());
         
         if(bars_since_entry >= InpTimeExitBars)
         {
            Print("SALIDA POR TIEMPO: ", bars_since_entry, " barras en trade");
            trade.PositionClose(ticket);
         }
      }
   }
}
//+------------------------------------------------------------------+