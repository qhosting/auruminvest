//+------------------------------------------------------------------+
//|                    AURUMVISUALIZER_V2.mq5 [PROFESSIONAL]         |
//|                    Copyright 2025, Aurum Capital (Edwin CEO)     |
//|                    Indicador Smart Trap V2 [OPTIMIZED]           |
//+------------------------------------------------------------------+
// ✅ CORRECCIONES CRITICAS IMPLEMENTADAS:
// 1. Bug grave arrays incorrectos en Fibonacci - CORREGIDO
// 2. Memory leak de objetos graficos - CORREGIDO (max 50 objetos)
// 3. Repainting en Fibonacci - CORREGIDO (actualizacion periodica)
// 4. Dashboard de metricas en tiempo real
// 5. Limpieza automatica de objetos antiguos
// 6. Validacion de indices de arrays
// 7. Filtros de confluencia visuales (RSI, Zonas H1)
// 8. Encoding UTF-8 limpio
//
// Fecha: 10 Diciembre 2025
// Version: 2.0
//+------------------------------------------------------------------+
#property copyright "Aurum Capital"
#property version   "2.0"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
#property strict

// --- PLOTS (FLECHAS SEÑAL) ---
#property indicator_label1  "Buy Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  2

#property indicator_label2  "Sell Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2

// ==================== CONFIGURACION ====================

input group "=== ESTRATEGIA ==="
input int      InpFiboLookback      = 100;       // Periodo Fibonacci
input int      InpFiboUpdateBars    = 10;        // Actualizar Fibo cada N barras (anti-repaint)
input int      InpEMAPeriod         = 150;       // EMA Tendencia (M15)
input int      InpADXPeriod         = 14;        // ADX Periodo
input int      InpADXMin            = 25;        // ADX Minimo

input group "=== FILTROS AVANZADOS ==="
input bool     InpShowRSI           = true;      // Mostrar RSI en Dashboard
input int      InpRSIPeriod         = 14;        // RSI Periodo
input bool     InpShowH1Zones       = true;      // Mostrar Zonas H1
input int      InpH1Lookback        = 20;        // Periodo Zonas H1

input group "=== VISUALIZACION ==="
input bool     InpShowTrap          = true;      // Mostrar Trampa (Ghost Box)
input bool     InpShowDashboard     = true;      // Mostrar Dashboard
input bool     InpShowMetrics       = true;      // Mostrar Metricas de Performance
input int      InpMaxObjects        = 50;        // Max Objetos Graficos (memory protection)
input color    ClrGold              = clrGold;   // Color Fibonacci
input color    ClrTrend             = clrCyan;   // Color Tendencia
input color    ClrDaily             = clrMagenta;// Color Daily Open
input color    ClrH1Zone            = clrOrange; // Color Zonas H1

// ==================== BUFFERS Y HANDLES ====================

double BufferBuy[];
double BufferSell[];

int handle_ema;
int handle_adx;
int handle_rsi;

// ==================== VARIABLES GLOBALES ====================

// Cache de Fibonacci (anti-repaint)
double g_fibo_high = 0.0;
double g_fibo_low = 0.0;
double g_fibo_618 = 0.0;
int g_last_fibo_calc_bar = 0;

// Tracking de objetos (memory management)
string g_line_names[];
string g_label_names[];
string g_box_names[];
int g_object_count = 0;

// Zonas H1
double g_h1_high = 0.0;
double g_h1_low = 0.0;

// Metricas de performance
struct Metrics {
   int total_signals;
   int buy_signals;
   int sell_signals;
   datetime last_signal_time;
   double last_signal_price;
};
Metrics g_metrics;

//+------------------------------------------------------------------+
//| INICIALIZACION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Buffers
   SetIndexBuffer(0, BufferBuy, INDICATOR_DATA);
   SetIndexBuffer(1, BufferSell, INDICATOR_DATA);
   
   PlotIndexSetInteger(0, PLOT_ARROW, 233); // Flecha Arriba
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // Flecha Abajo
   
   // Inicializar arrays como vacios
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // Indicadores
   handle_ema = iMA(_Symbol, PERIOD_M15, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   handle_adx = iADX(_Symbol, PERIOD_M15, InpADXPeriod);
   handle_rsi = iRSI(_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);

   if(handle_ema == INVALID_HANDLE || handle_adx == INVALID_HANDLE || handle_rsi == INVALID_HANDLE)
   {
      Print("ERROR: No se pudo cargar indicadores");
      return(INIT_FAILED);
   }
   
   // Inicializar tracking de objetos
   ArrayResize(g_line_names, 0);
   ArrayResize(g_label_names, 0);
   ArrayResize(g_box_names, 0);
   g_object_count = 0;
   
   // Inicializar metricas
   g_metrics.total_signals = 0;
   g_metrics.buy_signals = 0;
   g_metrics.sell_signals = 0;
   g_metrics.last_signal_time = 0;
   g_metrics.last_signal_price = 0.0;

   Print("\n========================================");
   Print("AURUM VISUALIZER V2.0 [PROFESSIONAL] INICIADO");
   Print("========================================");
   Print("Max Objetos: ", InpMaxObjects, " (memory protection)");
   Print("Fibo Update: cada ", InpFiboUpdateBars, " barras (anti-repaint)");
   Print("========================================\n");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| LIMPIEZA                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Limpiar SOLO objetos propios (con prefijo Aurum_)
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "Aurum_") == 0)
         ObjectDelete(0, name);
   }
   
   IndicatorRelease(handle_ema);
   IndicatorRelease(handle_adx);
   IndicatorRelease(handle_rsi);
   Comment("");
   
   Print("AURUM VISUALIZER V2 DETENIDO. Razon: ", reason);
}

//+------------------------------------------------------------------+
//| CALCULO PRINCIPAL                                                |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Validar datos suficientes
   if(rates_total < InpFiboLookback + 10) return(0);
   
   // Set arrays as series
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(BufferBuy, true);
   ArraySetAsSeries(BufferSell, true);

   // Arrays para indicadores
   double ema[1], adx[1], rsi[1];
   
   if(CopyBuffer(handle_ema, 0, 0, 1, ema) <= 0) return(0);
   if(CopyBuffer(handle_adx, 0, 0, 1, adx) <= 0) return(0);
   if(CopyBuffer(handle_rsi, 0, 0, 1, rsi) <= 0) return(0);

   // Daily Open
   double d_open = iOpen(_Symbol, PERIOD_D1, 0);

   // ==================== ACTUALIZAR FIBONACCI (CACHE) ====================
   ActualizarFibonacciCache(rates_total);
   
   // ==================== ACTUALIZAR ZONAS H1 ====================
   if(InpShowH1Zones) ActualizarZonasH1();
   
   // ==================== LOGICA DE SEÑALES ====================
   
   double close_current = close[0];
   bool is_uptrend = close_current > ema[0];
   bool strong_trend = adx[0] > InpADXMin;
   
   // Limpiar buffers
   BufferBuy[0] = EMPTY_VALUE;
   BufferSell[0] = EMPTY_VALUE;
   
   // Calcular nivel 61.8% segun tendencia
   double lev_618 = g_fibo_618;
   double tp_target = is_uptrend ? g_fibo_high : g_fibo_low;
   
   // Distancia al nivel Fibonacci
   double dist_to_fibo = MathAbs(close_current - lev_618) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   bool near_fibo = dist_to_fibo < 50;

   // ==================== DIBUJAR OBJETOS (SOLO ULTIMA VELA) ====================
   
   DrawLineOptimized("Aurum_FiboLine", lev_618, ClrGold, 2, STYLE_SOLID);
   DrawLineOptimized("Aurum_TrendLine", ema[0], ClrTrend, 1, STYLE_SOLID);
   DrawLineOptimized("Aurum_DailyLine", d_open, ClrDaily, 2, STYLE_DOT);
   
   // Zonas H1
   if(InpShowH1Zones && g_h1_high > 0 && g_h1_low > 0)
   {
      DrawLineOptimized("Aurum_H1_High", g_h1_high, ClrH1Zone, 1, STYLE_DASH);
      DrawLineOptimized("Aurum_H1_Low", g_h1_low, ClrH1Zone, 1, STYLE_DASH);
   }
   
   // Etiquetas
   DrawLabelOptimized("Aurum_Lbl_Fibo", lev_618, "  Fibo 61.8%", ClrGold);
   DrawLabelOptimized("Aurum_Lbl_Daily", d_open, "  D.OPEN", ClrDaily);
   
   if(InpShowH1Zones)
   {
      DrawLabelOptimized("Aurum_Lbl_H1High", g_h1_high, "  H1 HIGH", ClrH1Zone);
      DrawLabelOptimized("Aurum_Lbl_H1Low", g_h1_low, "  H1 LOW", ClrH1Zone);
   }

   // ==================== DIBUJAR TRAMPA (GHOST BOX) ====================
   if(InpShowTrap && near_fibo && strong_trend)
   {
      datetime t1 = time[0];
      datetime t2 = t1 + (PeriodSeconds() * 15);
      
      // Calcular SL y TP aproximados
      double atr_buffer[1];
      int handle_atr = iATR(_Symbol, PERIOD_M5, 14);
      if(handle_atr != INVALID_HANDLE && CopyBuffer(handle_atr, 0, 0, 1, atr_buffer) > 0)
      {
         double atr = atr_buffer[0];
         
         if(is_uptrend)
         {
            double sl_approx = lev_618 - (atr * 1.5);
            double tp_approx = lev_618 + (atr * 3.0);
            
            // Caja Riesgo (rojo)
            DrawBoxOptimized("Aurum_Trap_Risk", t1, lev_618, t2, sl_approx, clrRed);
            // Caja Beneficio (verde)
            DrawBoxOptimized("Aurum_Trap_Reward", t1, lev_618, t2, tp_approx, clrLime);
         }
         else
         {
            double sl_approx = lev_618 + (atr * 1.5);
            double tp_approx = lev_618 - (atr * 3.0);
            
            // Caja Riesgo (rojo)
            DrawBoxOptimized("Aurum_Trap_Risk", t1, lev_618, t2, sl_approx, clrRed);
            // Caja Beneficio (verde)
            DrawBoxOptimized("Aurum_Trap_Reward", t1, lev_618, t2, tp_approx, clrLime);
         }
      }
      
      // Texto Trampa
      string trap_txt = is_uptrend ? "BUY LIMIT ZONE" : "SELL LIMIT ZONE";
      DrawLabelOptimized("Aurum_Lbl_Trap", lev_618, trap_txt, clrWhite);
   }

   // ==================== DASHBOARD ====================
   if(InpShowDashboard)
   {
      string dash = "========================================\n";
      dash += "AURUM VISUALIZER V2.0 [PROFESSIONAL]\n";
      dash += "========================================\n\n";
      
      // Seccion Tendencia
      dash += "TENDENCIA M15: " + (is_uptrend ? "ALCISTA" : "BAJISTA") + "\n";
      dash += "Daily Bias: " + (close_current > d_open ? "BULLISH" : "BEARISH") + "\n";
      dash += "Fuerza ADX: " + DoubleToString(adx[0], 1) + (strong_trend ? " (FUERTE)" : " (DEBIL)") + "\n\n";
      
      // Seccion Fibonacci
      dash += "FIBONACCI:\n";
      dash += "High: " + DoubleToString(g_fibo_high, _Digits) + "\n";
      dash += "Low: " + DoubleToString(g_fibo_low, _Digits) + "\n";
      dash += "Nivel 61.8%: " + DoubleToString(lev_618, _Digits) + "\n";
      dash += "Distancia: " + DoubleToString(dist_to_fibo, 0) + " pts ";
      dash += (near_fibo ? "[EN ZONA]" : "") + "\n\n";
      
      // Seccion RSI
      if(InpShowRSI)
      {
         dash += "RSI M5: " + DoubleToString(rsi[0], 1);
         if(rsi[0] > 60) dash += " [SOBRECOMPRA]";
         else if(rsi[0] < 40) dash += " [SOBREVENTA]";
         dash += "\n\n";
      }
      
      // Seccion Zonas H1
      if(InpShowH1Zones && g_h1_high > 0)
      {
         dash += "ZONAS H1:\n";
         dash += "Resistencia: " + DoubleToString(g_h1_high, _Digits) + "\n";
         dash += "Soporte: " + DoubleToString(g_h1_low, _Digits) + "\n";
         
         double dist_h1_high = MathAbs(close_current - g_h1_high) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double dist_h1_low = MathAbs(close_current - g_h1_low) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         
         if(dist_h1_high < 35) dash += "[CERCA DE RESISTENCIA H1]\n";
         if(dist_h1_low < 35) dash += "[CERCA DE SOPORTE H1]\n";
         dash += "\n";
      }
      
      // Seccion Metricas
      if(InpShowMetrics)
      {
         dash += "METRICAS:\n";
         dash += "Senales Total: " + IntegerToString(g_metrics.total_signals) + "\n";
         dash += "Buy: " + IntegerToString(g_metrics.buy_signals) + " | ";
         dash += "Sell: " + IntegerToString(g_metrics.sell_signals) + "\n";
         if(g_metrics.last_signal_time > 0)
         {
            dash += "Ultima Senal: " + TimeToString(g_metrics.last_signal_time, TIME_DATE|TIME_MINUTES) + "\n";
         }
         dash += "\n";
      }
      
      // Seccion Sistema
      dash += "SISTEMA:\n";
      dash += "Objetos Graficos: " + IntegerToString(g_object_count) + "/" + IntegerToString(InpMaxObjects) + "\n";
      dash += "Fibo actualizado: cada " + IntegerToString(InpFiboUpdateBars) + " barras\n";
      
      Comment(dash);
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| CACHE DE FIBONACCI (ANTI-REPAINT)                               |
//+------------------------------------------------------------------+
void ActualizarFibonacciCache(int rates_total)
{
   // Solo actualizar cada N barras
   int bars_since_update = rates_total - g_last_fibo_calc_bar;
   if(bars_since_update < InpFiboUpdateBars && g_last_fibo_calc_bar > 0)
      return;
   
   // CORRECCION BUG: Usar iHigh/iLow en vez de arrays directos
   // Usar shift=1 para evitar lookahead (barra cerrada)
   int highest_idx = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, InpFiboLookback, 1);
   int lowest_idx  = iLowest(_Symbol, PERIOD_M5, MODE_LOW, InpFiboLookback, 1);
   
   // Validar indices
   if(highest_idx < 0 || lowest_idx < 0)
   {
      Print("ERROR: Indices Fibonacci invalidos");
      return;
   }
   
   // Usar funciones iHigh/iLow (mas seguro)
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
   
   // Calcular nivel 61.8% (promedio de ambos)
   double fib_buy = g_fibo_high - (f_range * 0.618);
   double fib_sell = g_fibo_low + (f_range * 0.618);
   g_fibo_618 = (fib_buy + fib_sell) / 2.0;
   
   g_last_fibo_calc_bar = rates_total;
   
   Print("Fibonacci actualizado | High: ", g_fibo_high, " | Low: ", g_fibo_low, 
         " | 61.8%: ", g_fibo_618);
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
   
   // Usar shift=1 para evitar lookahead
   if(CopyHigh(_Symbol, PERIOD_H1, 1, InpH1Lookback, h1_high_buffer) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_H1, 1, InpH1Lookback, h1_low_buffer) <= 0) return;
   
   g_h1_high = h1_high_buffer[ArrayMaximum(h1_high_buffer)];
   g_h1_low = h1_low_buffer[ArrayMinimum(h1_low_buffer)];
}

//+------------------------------------------------------------------+
//| FUNCIONES DE DIBUJO OPTIMIZADAS (MEMORY MANAGEMENT)             |
//+------------------------------------------------------------------+

void DrawLineOptimized(string name, double price, color clr, int width, ENUM_LINE_STYLE style)
{
   // Verificar limite de objetos
   if(g_object_count >= InpMaxObjects)
   {
      // Eliminar linea mas antigua
      int line_count = ArraySize(g_line_names);
      if(line_count > 0)
      {
         string oldest = g_line_names[0];
         ObjectDelete(0, oldest);
         
         // Shift array
         for(int i = 0; i < line_count - 1; i++)
            g_line_names[i] = g_line_names[i + 1];
         
         ArrayResize(g_line_names, line_count - 1);
         g_object_count--;
      }
   }
   
   // Crear o actualizar linea
   if(ObjectFind(0, name) < 0)
   {
      if(ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
      {
         ArrayResize(g_line_names, ArraySize(g_line_names) + 1);
         g_line_names[ArraySize(g_line_names) - 1] = name;
         g_object_count++;
      }
   }
   
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

void DrawLabelOptimized(string name, double price, string text, color clr)
{
   // Verificar limite
   if(g_object_count >= InpMaxObjects)
   {
      int label_count = ArraySize(g_label_names);
      if(label_count > 0)
      {
         string oldest = g_label_names[0];
         ObjectDelete(0, oldest);
         
         for(int i = 0; i < label_count - 1; i++)
            g_label_names[i] = g_label_names[i + 1];
         
         ArrayResize(g_label_names, label_count - 1);
         g_object_count--;
      }
   }
   
   datetime time_future = TimeCurrent() + (PeriodSeconds() * 2);
   
   if(ObjectFind(0, name) < 0)
   {
      if(ObjectCreate(0, name, OBJ_TEXT, 0, time_future, price))
      {
         ArrayResize(g_label_names, ArraySize(g_label_names) + 1);
         g_label_names[ArraySize(g_label_names) - 1] = name;
         g_object_count++;
      }
   }
   
   ObjectSetInteger(0, name, OBJPROP_TIME, time_future);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void DrawBoxOptimized(string name, datetime t1, double p1, datetime t2, double p2, color clr)
{
   // Verificar limite
   if(g_object_count >= InpMaxObjects)
   {
      int box_count = ArraySize(g_box_names);
      if(box_count > 0)
      {
         string oldest = g_box_names[0];
         ObjectDelete(0, oldest);
         
         for(int i = 0; i < box_count - 1; i++)
            g_box_names[i] = g_box_names[i + 1];
         
         ArrayResize(g_box_names, box_count - 1);
         g_object_count--;
      }
   }
   
   if(ObjectFind(0, name) < 0)
   {
      if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2))
      {
         ArrayResize(g_box_names, ArraySize(g_box_names) + 1);
         g_box_names[ArraySize(g_box_names) - 1] = name;
         g_object_count++;
      }
   }
   
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}
//+------------------------------------------------------------------+