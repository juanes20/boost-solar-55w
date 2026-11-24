/*
  BOOST UNO R3 - ETAPA 1: PI INTERNO DE CORRIENTE (ACS712 DE 5 A)
  Basado en BOOST_3_CONTROLES_19V_V1(1).ino modificado por el profesor.
  NO modifica el archivo original ni el PWM original de Timer1.

  D9: PWM Timer1 31.37255 kHz (modo 14, TOP 509, prescaler 1)
  A0: voltaje de entrada / panel (factor 8.20)
  A1: voltaje de salida (factor 29.87; SOLO supervisa)
  A2: ACS712 5 A (185 mV/A); PI regula corriente

  PRUEBA INICIAL LABORATORIO: fuente ~19 V limitada en corriente,
  carga resistiva apropiada, SIN bateria. Iref inicial = 0.50 A.
  Serial Plotter 115200: para cambiar corriente escribir SOLO 0.3, 0.5, etc.

  IMPORTANTE:
  - Con Arduino solo por USB (Vin<16 V), OCR1A permanece en 0: NORMAL.
  - Calibrar cero SIN corriente al encender el Arduino.
  - SENTIDO_CORRIENTE=-1 corresponde a la prueba externa; CONFIRMAR en PCB.
  - OCR1A=0 NO asegura apagar ambos MOSFET de una PCB con inversion.
  - La fuente CC/CV NO reemplaza apagado fisico del driver, tiempo muerto
    ni protecciones independientes.
  - AUN NO incluye el PI fotovoltaico; primero validar PI interno.
*/

#include <Arduino.h>
#include <stdlib.h>

const uint16_t PWM_TOP = 509;
const float ADC_VREF = 5.0f;
const float FACTOR_VIN = 8.20f;   // Revisar contra multimetro
const float FACTOR_VOUT = 29.87f;
const float ACS_V_POR_A = 0.185f; // ACS712 5 A
const float SENTIDO_CORRIENTE = -1.0f; // Verificar orientacion definitiva

const float VIN_MIN = 16.0f;
const float VIN_MAX = 22.0f;
const float VOUT_MAX = 32.0f; // Limite de PRUEBA: no sustituye proteccion fisica
const float DMIN = 0.10f;
const float DMAX = 0.42f;     // Limite reducido frente al 0.80 original para banco
const float PASO_DUTY_MAX = 0.002f;
const float VOUT_ESTIMADA = 24.0f; // Solo anticipacion del duty, NO PI de Vout

// Conservamos las ganancias experimentales del profesor SIN sintonizarlas aun
const float KPI = 0.060f; // duty/A
const float KII = 0.45f;  // duty/(A*s)
const unsigned long T_I_MS = 20;
const unsigned long T_PLOT_MS = 150;

float refI = 0.50f;
float ceroACS = 2.5f;
float vin = 0.0f, vout = 0.0f, iMed = 0.0f;
float duty = 0.0f, integralI = 0.0f;
uint8_t estado = 0; // 0: sin Vin; 1: PI activo; 2: ACS invalido; 3: otro limite
unsigned long tI = 0, tPlot = 0, tUltCaracter = 0;
char entrada[16];
uint8_t nEntrada = 0;

float adcVoltios(uint8_t pin) {
  analogRead(pin); // Descartar primera lectura tras cambiar de canal
  unsigned long suma = 0;
  for (uint8_t n = 0; n < 32; ++n) suma += analogRead(pin);
  return (suma / 32.0f) * ADC_VREF / 1023.0f;
}

void escribirDuty(float d) {
  d = constrain(d, 0.0f, DMAX);
  uint16_t cuenta = (uint16_t)(d * (PWM_TOP + 1.0f) + 0.5f);
  noInterrupts();
  OCR1A = cuenta; // Nunca desconectar ni reconfigurar Timer1
  interrupts();
  duty = cuenta / (PWM_TOP + 1.0f);
}

void aceptarNumero() {
  if (nEntrada == 0) return;
  entrada[nEntrada] = '\0';
  char *fin = NULL;
  float nuevo = (float)strtod(entrada, &fin);
  if (fin != entrada && *fin == '\0' && nuevo >= 0.15f && nuevo <= 0.80f) {
    refI = nuevo; // Solo cambia referencia; SIN comandos de activacion
  }
  nEntrada = 0;
}

void leerReferencia() {
  while (Serial.available() > 0) {
    char c = (char)Serial.read();
    if (c == '\n' || c == '\r') aceptarNumero();
    else if (c >= 32 && c <= 126 && nEntrada < sizeof(entrada) - 1) {
      entrada[nEntrada++] = c;
      tUltCaracter = millis();
    }
  }
  if (nEntrada && millis() - tUltCaracter > 120UL) aceptarNumero();
}

void setup() {
  pinMode(9, OUTPUT);
  digitalWrite(9, LOW);
  Serial.begin(115200);
  analogReference(DEFAULT);

  // Calibrar ACS712 SOLO cuando realmente hay cero corriente.
  // Hacerlo con potencia y driver deshabilitados antes de arrancar.
  delay(500);
  float sumaCero = 0.0f;
  for (uint8_t n = 0; n < 64; ++n) {
    sumaCero += adcVoltios(A2);
    delay(3);
  }
  ceroACS = sumaCero / 64.0f;

  // Timer1 EXACTAMENTE con los registros del codigo PWM funcional.
  noInterrupts();
  TCCR1A = 0;
  TCCR1B = 0;
  TCNT1 = 0;
  ICR1 = PWM_TOP;
  OCR1A = 0;  // Sin fuente de 19 V, NO habra PWM de potencia
  TCCR1A = _BV(COM1A1) | _BV(WGM11);
  TCCR1B = _BV(WGM13) | _BV(WGM12) | _BV(CS10);
  interrupts();
}

void loop() {
  leerReferencia();
  unsigned long ahora = millis();
  if (ahora - tI >= T_I_MS) {
    tI = ahora;
    vin = adcVoltios(A0) * FACTOR_VIN;
    vout = adcVoltios(A1) * FACTOR_VOUT;
    float vACS = adcVoltios(A2); // CORREGIDO: A2, NO A0
    iMed = SENTIDO_CORRIENTE * (vACS - ceroACS) / ACS_V_POR_A;

    if (vin < VIN_MIN) estado = 0;
    else if (vACS < 1.80f || vACS > 3.20f || iMed < -0.20f) estado = 2;
    else if (vin > VIN_MAX || vout > VOUT_MAX || iMed > 1.25f) estado = 3;
    else estado = 1;

    if (estado != 1) {
      escribirDuty(0.0f);
      integralI = 0.0f;
    } else {
      // Unicamente PI interno de corriente, Iref por defecto 0.5 A
      float error = refI - iMed;
      // Valor de anticipacion experimental heredado del profesor:
      float dFF = constrain(1.0f - vin / VOUT_ESTIMADA, 0.0f, DMAX);
      float candidato = dFF + KPI * error + integralI;
      if (!((candidato >= DMAX && error > 0.0f) ||
            (candidato <= DMIN && error < 0.0f))) {
        integralI += KII * (T_I_MS / 1000.0f) * error;
        integralI = constrain(integralI, -0.20f, 0.20f);
      }
      float pedido = constrain(dFF + KPI * error + integralI, DMIN, DMAX);
      float paso = constrain(pedido - duty, -PASO_DUTY_MAX, PASO_DUTY_MAX);
      escribirDuty(duty + paso);
    }
  }

  if (ahora - tPlot >= T_PLOT_MS) {
    tPlot = ahora;
    // Variables de corriente y duty juntas: escala legible en Plotter.
    Serial.print(F("Iref_A:")); Serial.print(refI, 3);
    Serial.print(F("\tI_L_A:")); Serial.print(iMed, 3);
    Serial.print(F("\tDuty_01:")); Serial.print(duty, 3);
    Serial.print(F("\tEstado:")); Serial.println(estado);
  }
}
