// Scanner.ino - ELE3PRO pan-tilt scanner
//
// Commands (115200 baud, one letter + optional number, newline at the end):
//   r  run              s  stop (works any time)
//   v  print settings
//   a  step size, both axes      p  pan step only     t  tilt step only
//   c  pan start                 d  pan stop
//   e  tilt start                f  tilt stop
//   g  pan delay (ms)            h  tilt delay (ms)
//   u  ultrasonic: u1 on, u0 off
// Settings are only accepted while stopped.
//
// Output, one line per point:  pan <TAB> tilt <TAB> tof_mm <TAB> us_mm
//   Angles are raw servo degrees (MATLAB converts them).
//   ToF timeout = 8190, ultrasonic off or no echo = 0.

#include <Servo.h>
#include <Wire.h>
#include <VL53L0X.h>

// ---- Build settings ----
#define PAN_PIN       9
#define TILT_PIN      4
#define TRIG_PIN      12      // HC-SR04
#define ECHO_PIN      11      // HC-SR04
#define PAN_CENTRE    90      // servo angle looking straight ahead
#define TILT_CENTRE   108     // servo angle looking level
#define NO_READING    8190    // ToF timeout value
#define US_TIMEOUT    30000UL // ultrasonic echo timeout, us (about 5 m)
#define SOUND_MM_US   0.343   // speed of sound, mm per us

Servo panServo;
Servo tiltServo;
VL53L0X tof;

// ---- Scan settings (changed by commands) ----
int pan_start  = PAN_CENTRE - 40;
int pan_stop   = PAN_CENTRE + 40;
int tilt_start = TILT_CENTRE;      // start = stop gives a line scan
int tilt_stop  = TILT_CENTRE;
int pan_step   = 5;
int tilt_step  = 5;
int pan_delay  = 50;
int tilt_delay = 50;
int use_us     = 0;                // ultrasonic off by default (it is slow)

int running = 0;                   // 1 while scanning
int pan_dir = 1;                   // pan direction, flips each scan

void setup() {
  Serial.begin(115200);

  panServo.attach(PAN_PIN);
  tiltServo.attach(TILT_PIN);
  panServo.write(PAN_CENTRE);      // start at centre
  tiltServo.write(TILT_CENTRE);
  delay(500);

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  digitalWrite(TRIG_PIN, LOW);

  // ToF: long range, high accuracy (200 ms per reading)
  Wire.begin();
  tof.init();
  tof.setTimeout(500);
  tof.setSignalRateLimit(0.1);
  tof.setVcselPulsePeriod(VL53L0X::VcselPeriodPreRange, 18);
  tof.setVcselPulsePeriod(VL53L0X::VcselPeriodFinalRange, 14);
  tof.setMeasurementTimingBudget(200000);
}

// Print the current settings
void printSettings() {
  char s[80];
  Serial.println("ELE3PRO Scanner (ToF + ultrasonic)");
  sprintf(s, "Pan: %i to %i, step %i, delay %i", pan_start, pan_stop, pan_step, pan_delay);
  Serial.println(s);
  sprintf(s, "Tilt: %i to %i, step %i, delay %i", tilt_start, tilt_stop, tilt_step, tilt_delay);
  Serial.println(s);
  Serial.println(use_us ? "Ultrasonic: on" : "Ultrasonic: off");
}

// Read one command line, if there is one
void readCommand() {
  if (Serial.available() == 0) return;

  char s[64];
  int n = Serial.readBytesUntil('\n', s, 63);
  if (n == 0) return;
  s[n] = '\0';
  int value = atoi(s + 1);         // number after the letter

  if (s[0] == 's') running = 0;    // stop works any time
  if (running) return;             // everything else only while stopped

  switch (s[0]) {
    case 'r': running = 1; break;
    case 'v': printSettings(); break;
    case 'a': pan_step = tilt_step = max(1, value); break;
    case 'p': pan_step  = max(1, value); break;
    case 't': tilt_step = max(1, value); break;
    case 'c': pan_start  = value; break;
    case 'd': pan_stop   = value; break;
    case 'e': tilt_start = value; break;
    case 'f': tilt_stop  = value; break;
    case 'g': pan_delay  = value; break;
    case 'h': tilt_delay = value; break;
    case 'u': use_us = (value != 0); break;
  }
}

// One ultrasonic reading in mm (0 = no echo)
int readUltrasonic() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  unsigned long t = pulseIn(ECHO_PIN, HIGH, US_TIMEOUT);
  if (t == 0) return 0;
  return (int)(t * SOUND_MM_US / 2.0);   // out and back, so halve it
}

// Take one point and send it
void sendPoint(int pan, int tilt) {
  int d = tof.readRangeSingleMillimeters();
  if (tof.timeoutOccurred()) d = NO_READING;
  int us = use_us ? readUltrasonic() : 0;

  char s[40];
  sprintf(s, "%i\t%i\t%i\t%i", pan, tilt, d, us);
  Serial.println(s);
}

// Move pan, then sweep tilt up or down, one point per step
void sweepTilt(int pan, int dir) {
  panServo.write(pan);
  delay(pan_delay);

  int tilt = (dir == 1) ? tilt_start : tilt_stop;
  while (running && tilt >= tilt_start && tilt <= tilt_stop) {
    tiltServo.write(tilt);
    delay(tilt_delay);
    sendPoint(pan, tilt);
    readCommand();                 // check for a stop
    tilt += dir * tilt_step;
  }
}

void loop() {
  if (!running) {
    readCommand();
    return;
  }

  // Serpentine scan: tilt direction flips every column,
  // pan direction flips every scan, so the head never travels back empty.
  int tilt_dir = 1;
  int pan = (pan_dir == 1) ? pan_start : pan_stop;
  while (running && pan >= pan_start && pan <= pan_stop) {
    sweepTilt(pan, tilt_dir);
    tilt_dir = -tilt_dir;
    pan += pan_dir * pan_step;
  }
  pan_dir = -pan_dir;

  if (running) {                   // finished, not stopped
    Serial.println("SCAN COMPLETE");
    running = 0;
  }
}
