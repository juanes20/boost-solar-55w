# Boost Solar 55 W — Portafolio GitHub Pages

**Convertidor DC–DC Boost síncrono con control de voltaje y corriente de entrada para transferencia hacia baterías**  
Institución Universitaria ITM · Ingeniería Electrónica · 2026-2

**Equipo:** Juan Esteban Moreno · Andrés Alejandro Zapata  
**Docente:** Juan Pablo Villegas Ceballos

## Sitio web

Este repositorio contiene un **portafolio web estático**, listo para servir con GitHub Pages. Incluye descripciones del sistema, diseño de PCB, resultados de simulación y un registro de las pruebas físicas disponibles.

**Función principal del convertidor:** regular las condiciones eléctricas **del lado de entrada** para transferir energía del panel fotovoltaico hacia una batería LiFePO₄:

1. **PI externo de tensión del panel (Vpv, A0):** compara el voltaje fotovoltaico con una referencia nominal de 18,8 V y genera la referencia de corriente `Iref`.
2. **PI interno de corriente (Iin, A2 / ACS712):** compara la corriente medida con `Iref` y modifica el ciclo útil de la señal PWM de D9.
3. **Salida / batería:** se monitoriza para aplicar límites y protecciones según el BMS y las condiciones de carga. No se incluye un tercer PI de tensión de salida en la arquitectura propuesta.

**La referencia principal de tensión es Vpv ≈ 18,8 V, correspondiente al punto nominal de máxima potencia del panel.** La corriente de entrada se regula con un PI interno. El seguimiento del punto de máxima potencia y la carga segura aún requieren validación en el sistema completo.

> **Estado:** prototipo académico en validación experimental. No es un cargador de baterías operativo/certificado. El PI de corriente en lazo cerrado y el PI fotovoltaico externo aún requieren validación conjunta; no conectar una batería basándose únicamente en este firmware.

### Especificaciones nominales

| Parámetro | Valor | Carácter |
|---|---:|---|
| Panel | Victron BlueSolar 55 W | Equipo seleccionado |
| Vmp del panel | 18,8 V | Dato del panel |
| Referencia nominal de voltaje de entrada (Vpv) | 18,8 V | Lazo externo propuesto, no validado como doble lazo |
| Variable regulada por el PI interno | Corriente de entrada (Iin) | Medida por ACS712 ±5 A |
| Voltaje de salida (Vout) | Dependiente de batería y condiciones de operación | Supervisión / límites, no referencia fija |
| Inductor | 330 µH | Implementación |
| PWM | 31.372,55 Hz (≈ 31,37 kHz) | Timer1 UNO, verificado |
| Sensor | ACS712 ±5 A, 185 mV/A | Instrumentación |

## Cómo publicar en GitHub Pages

1. Crea un repositorio público de GitHub; sugerencia: `boost-solar-55w`.
2. Descomprime el ZIP que recibiste y sube **los archivos internos** a la raíz del repositorio. Asegúrate de que `index.html` quede en la raíz (no dentro de otra carpeta).
3. En GitHub, abre **Settings → Pages → Build and deployment**.
4. Selecciona **Deploy from a branch**, rama `main` y carpeta `/(root)`, luego **Save**.
5. La dirección será aproximadamente `https://TU-USUARIO.github.io/boost-solar-55w/`. Sustituye `TU-USUARIO` por el nombre real de tu cuenta.
6. En la sección **About** del repositorio, agrega la URL del sitio.

No se requiere Node.js, npm, un servidor backend ni compilación: el sitio usa HTML, CSS y JavaScript.

## Organización de archivos

```
boost-solar-55w/
├── index.html                      # Portafolio público
├── assets/
│   ├── styles.css                  # Diseño responsive
│   ├── main.js                     # Menú, filtros y galería
│   ├── favicon.svg
│   └── img/                       # Evidencias gráficas reales
├── firmware/
│   ├── PWM_D9_31372Hz.ino
│   ├── PI_Vout_experimental.ino
│   ├── PI_corriente_ACS712_5A_V2.ino
│   └── PI_corriente_A3_experimental_V3.ino
├── simulaciones/                  # Scripts históricos MATLAB
├── documentos/
│   └── Informe_Proyecto_Boost_ITM_2026.docx
├── .nojekyll
└── README.md
```

## Qué muestran los resultados

- **PWM:** una señal de ≈ 31,37 kHz en D9 usando Timer1, modo Fast PWM 14, TOP = 509.
- **Prueba anterior de PI de tensión:** ~17,9 V para una consigna de 18 V; es un controlador **distinto** del doble lazo final.
- **Diagnóstico de alimentación/sensado:** con Vin físico ≈ 19,03 V, Vout físico ≈ 18,41 V y fuente en CV, `DIV_OUT` fue ≈ 0,60 V (potencia sola), 1,00 V (auxiliar sola) y 2,33 V (ambas). El programa registró `Estado = 3`, `Duty = 0` ante lectura de Vout incoherente.

## Fotografías de resultados experimentales

Las nuevas fotografías de pruebas pueden añadirse en `assets/img/` e incorporarse a la galería de `index.html`, indicando siempre las condiciones de ensayo (fuente, carga, medición y tipo de controlador). No deben confundirse con una validación del sistema en cascada.

## Arquitectura frente al material histórico

El informe académico descargable y los archivos `PI_Vout_experimental.ino` conservan antecedentes de un controlador de **voltaje de salida**. **No describen la estrategia final propuesta**: PI externo de **voltaje del panel** → `Iref` → PI interno de **corriente de entrada** → PWM del Boost. Los modelos y firmware anteriores deben identificarse como antecedentes de diseño, no como implementación actual. El nombre **Boost Solar 55 W** se refiere a la potencia nominal del panel.

## Limitaciones y seguridad

- Los programas Arduino son **versiones experimentales de laboratorio**, no un sistema final de carga LiFePO₄.
- `OCR1A = 0` no garantiza que ambos MOSFET queden apagados si el hardware invierte señales. El apagado del IR2110 debe comprobarse en el circuito real.
- No se verificaron de forma concluyente el tiempo muerto, la protección independiente ante sobretensión ni la estabilidad del doble lazo.
- Los archivos MATLAB de `simulaciones/` corresponden a una **iteración histórica con parámetros de 300 µH**, no al dimensionamiento definitivo de 330 µH. No renombrar ni presentar esos modelos como calibrados con la PCB final.
- Revisar el perfil del BMS y la protección física antes de cualquier conexión de batería.

## Procedencia de las evidencias

- Figuras, fotografías y diseño PCB: archivos e informe del propio equipo del proyecto.
- Datos del panel y dimensionamiento: `documentos/Informe_Proyecto_Boost_ITM_2026.docx`.
- Capturas de monitor y diagnóstico: registros de laboratorio del desarrollo.

## Licencia

No se añadió una licencia de uso de código ni de hardware automáticamente. **Todos los derechos reservados** hasta que el equipo elija expresamente una licencia para software, documentación y diseños.
