/*
  DIAGNOSTICO AISLADO DE PWM - Arduino UNO R3 (ATmega328P 16 MHz)
  D9 (OC1A): ~31 372.55 Hz, duty fijo 30 %
  No lee A0/A1/A2, no utiliza Serial para habilitar PWM.

  OBLIGATORIO PARA ESTA PRUEBA:
  - Desconectar la etapa de potencia de 12 V y la instrumentacion de 18 V.
  - Desconectar fisicamente D9 de la entrada PWM de la PCB/IR2110.
  - Medir SOLO D9 contra GND del Arduino, con el UNO alimentado por USB.
  - No usar este programa para accionar los MOSFET.
*/
#include <Arduino.h>

const uint16_t TOP_PWM = 509;
const uint16_t OCR_D30 = 153;

void setup() {
  pinMode(9, OUTPUT);
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(9, LOW);
  Serial.begin(115200);

  noInterrupts();
  TCCR1A = 0;
  TCCR1B = 0;
  TCNT1  = 0;
  ICR1   = TOP_PWM;
  OCR1A  = OCR_D30;
  // Timer1, modo 14 Fast PWM, salida OC1A no inversora, prescaler 1.
  TCCR1A = _BV(COM1A1) | _BV(WGM11);
  TCCR1B = _BV(WGM13) | _BV(WGM12) | _BV(CS10);
  interrupts();

  Serial.println(F("DIAGNOSTICO PWM AISLADO: D9 ACTIVO"));
  Serial.println(F("Frecuencia: 31372.55 Hz | Duty: 30.0%"));
  Serial.println(F("NO conectar D9 a la PCB durante este diagnostico."));
}

void loop() {
  static uint32_t t0 = 0;
  if (millis() - t0 >= 500) {
    t0 = millis();
    digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN));
    Serial.println(F("UNO ejecutando; D9 PWM activo"));
  }
}
