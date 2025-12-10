# 🏆 AURUM Investment Ecosystem

**Sistema completo de trading algorítmico profesional para TradingView y MetaTrader 5**

---

## 📋 Descripción General

AURUM es un ecosistema integral de herramientas de trading diseñado para traders profesionales que buscan automatizar y optimizar sus estrategias de inversión. El sistema combina análisis visual avanzado en TradingView con ejecución automatizada en MetaTrader 5.

### 🎯 Componentes del Ecosistema

1. **AURUMVISION** (TradingView) - Indicador visual y sistema de señales
2. **AURUMSNIPER** (MetaTrader 5) - Expert Advisor para trading automatizado
3. **AURUMVISUALIZER** (MetaTrader 5) - Indicador visual complementario

---

## 🚀 Características Principales

### 📊 TradingView: AURUMVISION

- **Análisis Multi-Timeframe**: Confirmación de señales en múltiples marcos temporales
- **Indicadores Técnicos Avanzados**: RSI, MACD, Bandas de Bollinger, Medias Móviles
- **Señales Visuales Claras**: Flechas de compra/venta con colores intuitivos
- **Alertas Configurables**: Notificaciones en tiempo real de oportunidades
- **Panel de Información**: Dashboard con métricas clave del mercado
- **Zonas de Soporte/Resistencia**: Identificación automática de niveles críticos

📁 **Ubicación**: `/TradingView/AURUMVISION.pine`

### 🤖 MetaTrader 5: AURUMSNIPER EA

Expert Advisor optimizado para ejecución automatizada de operaciones:

- **Gestión Avanzada de Riesgo**: 
  - Trailing stop dinámico
  - Stop loss y take profit adaptativos
  - Control de drawdown máximo
  - Gestión de tamaño de posición por riesgo porcentual

- **Sistema de Filtros Inteligentes**:
  - Filtros de volatilidad
  - Confirmación multi-indicador
  - Análisis de tendencia
  - Detección de rangos laterales

- **Optimización de Rendimiento**:
  - Código optimizado para velocidad
  - Manejo robusto de errores
  - Logging detallado para análisis
  - Compatibilidad con backtesting

📁 **Ubicación**: `/MetaTrader5/AURUMSNIPER_V2.mq5`

### 📈 MetaTrader 5: AURUMVISUALIZER

Indicador visual complementario para análisis en MT5:

- **Señales de Entrada/Salida**: Visualización clara de oportunidades
- **Alertas Configurables**: Notificaciones sonoras y visuales
- **Múltiples Timeframes**: Análisis sincronizado en diferentes marcos
- **Rendimiento Optimizado**: Cálculos eficientes sin lag
- **Personalización Completa**: Colores, estilos y parámetros ajustables

📁 **Ubicación**: `/MetaTrader5/AURUMVISUALIZER_V2.mq5`

---

## 🎓 Guía de Inicio Rápido

### Para TradingView (AURUMVISION)

1. **Abrir TradingView** y seleccionar el gráfico deseado
2. **Abrir Pine Editor** (Alt + E)
3. **Copiar el código** de `/TradingView/AURUMVISION.pine`
4. **Pegar en el editor** y hacer clic en "Añadir al gráfico"
5. **Configurar parámetros** según tu estrategia
6. **Activar alertas** para recibir notificaciones

### Para MetaTrader 5 (AURUMSNIPER & AURUMVISUALIZER)

1. **Abrir MetaTrader 5**
2. **Ir a**: Archivo → Abrir carpeta de datos
3. **Navegar a**: `MQL5/Experts/` (para EA) o `MQL5/Indicators/` (para indicador)
4. **Copiar archivos**:
   - `AURUMSNIPER_V2.mq5` → carpeta Experts
   - `AURUMVISUALIZER_V2.mq5` → carpeta Indicators
5. **Compilar**: Clic derecho → Compilar (o F7)
6. **Aplicar al gráfico**: Arrastrar desde el Navegador al gráfico
7. **Configurar parámetros** y activar AutoTrading (para EA)

---

## 📚 Documentación Detallada

### TradingView
- 📄 [Changelog de AURUMVISION](./aurum_vision_changelog.md)
- 📖 [Guía de Primeros Pasos](./LEEME_PRIMERO.md)

### MetaTrader 5
- 📄 [Changelog de MT5](./MetaTrader5/mt5_changelog.md)
- 📊 [Resumen de Optimizaciones](./MetaTrader5/RESUMEN_OPTIMIZACION.md)

---

## ⚙️ Requisitos del Sistema

### TradingView
- Cuenta de TradingView (gratuita o premium)
- Navegador web moderno
- Conexión a internet estable

### MetaTrader 5
- MetaTrader 5 (versión 5.00 o superior)
- Windows 10/11, macOS (con Wine), o Linux (con Wine)
- Cuenta de broker compatible con MT5
- Mínimo 4GB RAM recomendado

---

## 🔧 Configuración Recomendada

### Parámetros Iniciales Sugeridos

**AURUMSNIPER EA:**
```
- Lote: 0.01 (para cuentas pequeñas)
- Riesgo por operación: 1-2%
- Trailing Stop: 20-30 pips
- Take Profit: 2-3x Stop Loss
- Timeframe: H1 o H4
```

**AURUMVISUALIZER:**
```
- Timeframe principal: H1
- Confirmación: M15 y H4
- Sensibilidad de señales: Media
```

---

## 📊 Estrategia de Uso Integrado

### Flujo de Trabajo Recomendado

1. **Análisis en TradingView** con AURUMVISION
   - Identificar tendencias principales
   - Detectar zonas de soporte/resistencia
   - Confirmar señales en múltiples timeframes

2. **Configuración en MT5**
   - Aplicar AURUMVISUALIZER para confirmación visual
   - Configurar AURUMSNIPER con parámetros optimizados
   - Activar trading automatizado

3. **Monitoreo y Ajuste**
   - Revisar rendimiento diariamente
   - Ajustar parámetros según condiciones de mercado
   - Analizar logs y métricas de desempeño

---

## ⚠️ Advertencias y Consideraciones

- **Riesgo de Trading**: El trading conlleva riesgos significativos. Nunca opere con dinero que no pueda permitirse perder.
- **Backtesting**: Siempre realice backtesting exhaustivo antes de operar en cuenta real.
- **Demo First**: Pruebe en cuenta demo durante al menos 1-2 meses antes de pasar a real.
- **Gestión de Riesgo**: Nunca arriesgue más del 1-2% de su capital por operación.
- **Supervisión**: Aunque el sistema es automatizado, requiere supervisión regular.

---

## 🤝 Soporte y Contribuciones

### Reportar Problemas
Si encuentra bugs o tiene sugerencias, por favor abra un issue en este repositorio.

### Contribuir
Las contribuciones son bienvenidas. Por favor:
1. Fork el repositorio
2. Cree una rama feature (`git checkout -b feature/nueva-caracteristica`)
3. Commit sus cambios (`git commit -m 'Agregar nueva característica'`)
4. Push a la rama (`git push origin feature/nueva-caracteristica`)
5. Abra un Pull Request

---

## 📜 Licencia

Este proyecto es de código abierto. Consulte el archivo LICENSE para más detalles.

---

## 📞 Contacto

Para consultas profesionales o soporte personalizado, contacte a través de los issues de GitHub.

---

## 🔄 Actualizaciones

**Última actualización**: Diciembre 2025

Revise regularmente este repositorio para obtener las últimas versiones y mejoras del ecosistema AURUM.

---

## 🌟 Agradecimientos

Gracias a la comunidad de traders algorítmicos por su feedback continuo y contribuciones al desarrollo de estas herramientas.

---

**⚡ AURUM - Trading Inteligente, Resultados Consistentes**
