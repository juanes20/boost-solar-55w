/*
  BOOST - Arduino UNO R3
  PWM automatico: D9, 31.37 kHz
  Referencia desde Serial Plotter: solo escribir 18, 19, etc.

  A0 = Vin  (divisor 68k / 10k)
  A1 = Vout (divisor 270k / 10k)
  A2 = ACS712 de 30A (solo monitoreo)

  Control PI de voltaje de salida para banco de 12V.
  No usar con bateria ni salida de 55V.
*/

#include <Arduino.h>
#include <stdlib.h>

const uint16_t PWM_TOP = 509;

const float VADC = 5.0;
const float FACTOR_VIN = 7.8;
const float FACTOR_VOUT = 28.0;

const float DMIN = 0.15;
const float DMAX = 0.42;

// Ganancias iniciales del PI de voltaje
const float KP = 0.008;
const float KI = 0.015;

float refV = 18.0;
float vin = 0.0;
float vout = 0.0;
float corriente = 0.0;

float duty = 153.0 / 510.0;
float integral = 0.0;

char entrada[16];
uint8_t num = 0;

unsigned long ultimaLetra = 0;
unsigned long tControl = 0;
unsigned long tPlot = 0;


// Lectura analogica promediada
float leerVoltaje(uint8_t pin) {
  analogRead(pin);

  uint16_t suma = 0;

  for (uint8_t i = 0; i < 8; i++) {
    suma += analogRead(pin);
  }

  return (suma / 8.0) * VADC / 1023.0;
}


// Cambiar duty SIN apagar Timer1
void fijarDuty(float d) {
  d = constrain(d, DMIN, DMAX);

  uint16_t valor = (uint16_t)(d * 510.0 + 0.5);

  noInterrupts();
  OCR1A = valor;
  interrupts();

  duty = valor / 510.0;
}


// Procesar referencia numerica
void aceptarReferencia() {
  if (num == 0) return;

  entrada[num] = '\0';

  char *fin;
  float nuevo = strtod(entrada, &fin);

  if (fin != entrada &&
      *fin == '\0' &&
      nuevo >= 14.0 &&
      nuevo <= 20.0) {

    refV = nuevo;
    integral = 0.0;
  }

  num = 0;
}


// Leer numero desde Serial Plotter
void recibirReferencia() {

  while (Serial.available()) {

    char c = Serial.read();

    if (c == '\n' || c == '\r') {
      aceptarReferencia();
    }
    else if (c >= 32 &&
             c <= 126 &&
             num < sizeof(entrada) - 1) {

      entrada[num++] = c;
      ultimaLetra = millis();
    }
  }

  if (num > 0 &&
      millis() - ultimaLetra > 120) {

    aceptarReferencia();
  }
}


void setup() {

  pinMode(9, OUTPUT);
  digitalWrite(9, LOW);

  Serial.begin(115200);
  analogReference(DEFAULT);

  // ==================================
  // TIMER1 - CONFIGURACION QUE FUNCIONO
  // ==================================

  noInterrupts();

  TCCR1A = 0;
  TCCR1B = 0;
  TCNT1 = 0;

  ICR1 = 509;
  OCR1A = 153;

  TCCR1A = _BV(COM1A1) | _BV(WGM11);

  TCCR1B = _BV(WGM13) |
           _BV(WGM12) |
           _BV(CS10);

  interrupts();

  // Timer1 queda funcionando.
  // No se deshabilita en ninguna parte.
}


void loop() {

  recibirReferencia();

  unsigned long ahora = millis();

  // Control cada 20 ms
  if (ahora - tControl >= 20) {

    tControl = ahora;

    vin = leerVoltaje(A0) * FACTOR_VIN;
    vout = leerVoltaje(A1) * FACTOR_VOUT;

    corriente =
      (leerVoltaje(A2) - 2.50) / 0.066;

    // Si no detecta entrada de 12 V:
    // PWM fijo del 30 % para diagnostico.
    if (vin < 9.0 || vin > 14.5) {

      integral = 0.0;
      fijarDuty(0.30);

    } else {

      // ==========================
      // CONTROL PI AUTOMATICO VOUT
      // ==========================

      float error = refV - vout;

      float anticipacion =
        1.0 - vin / refV;

      float objetivo =
        anticipacion +
        KP * error +
        integral;

      // Antiwindup
      if (!((objetivo >= DMAX && error > 0) ||
            (objetivo <= DMIN && error < 0))) {

        integral += KI * 0.020 * error;

        integral =
          constrain(integral, -0.12, 0.12);
      }

      objetivo = constrain(
        anticipacion +
        KP * error +
        integral,
        DMIN,
        DMAX
      );

      // Cambio progresivo del duty
      float cambio = constrain(
        objetivo - duty,
        -0.002,
        0.002
      );

      fijarDuty(duty + cambio);
    }
  }

  // ==========================
  // SERIAL PLOTTER
  // ==========================

  if (ahora - tPlot >= 100) {

    tPlot = ahora;

    Serial.print("Ref_V:");
    Serial.print(refV, 2);

    Serial.print("\tVout_V:");
    Serial.print(vout, 2);

    Serial.print("\tVin_V:");
    Serial.print(vin, 2);

    Serial.print("\tI_A_aprox:");
    Serial.print(corriente, 2);

    Serial.print("\tDuty_01:");
    Serial.println(duty, 3);
  }
}
