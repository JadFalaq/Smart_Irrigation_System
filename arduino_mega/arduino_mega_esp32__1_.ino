// ======================= Irrigation avec communication ESP32 =======================

// ======================= LOG Serial -> buffer =======================
const int LOG_CAP = 30;
String logBuf[LOG_CAP];
int logHead = 0;
int logCount = 0;

void logLine(const String &s) {
  Serial.println(s);
  Serial3.println(s);  // Envoyer aussi à l'ESP32

  logBuf[logHead] = s;
  logHead = (logHead + 1) % LOG_CAP;
  if (logCount < LOG_CAP) logCount++;
}

String getLogLineFromEnd(int idxFromEnd) {
  if (idxFromEnd >= logCount) return "";
  int lastIndex = (logHead - 1 + LOG_CAP) % LOG_CAP;
  int index = (lastIndex - idxFromEnd + LOG_CAP) % LOG_CAP;
  return logBuf[index];
}

// ======================= Bouton anti-rebond (zones + auto) =======================
class BoutonToggle {
  public:
    BoutonToggle(byte pin, unsigned long debounceDelay = 50)
      : _pin(pin), _debounceDelay(debounceDelay) {}

    void begin() {
      pinMode(_pin, INPUT_PULLUP); // bouton -> GND
      _lastReading      = digitalRead(_pin);
      _stableState      = _lastReading;
      _lastDebounceTime = millis();
    }

    bool pressed() {
      bool reading = digitalRead(_pin);
      if (reading != _lastReading) {
        _lastDebounceTime = millis();
        _lastReading = reading;
      }
      if ((millis() - _lastDebounceTime) > _debounceDelay) {
        if (reading != _stableState) {
          _stableState = reading;
          if (_stableState == LOW) return true; // appui
        }
      }
      return false;
    }

  private:
    byte _pin;
    unsigned long _debounceDelay;
    bool _lastReading      = HIGH;
    bool _stableState      = HIGH;
    unsigned long _lastDebounceTime = 0;
};

// ======================= Irrigation PINS =======================
// ✅ TES PINS BOUTONS (zones + auto)
const int buttonPins[6]     = {29, 31, 53, 37, 43, 35};   // Boutons zones (vers GND)
const int autoButtonPin     = 27;                         // Bouton AUTO (vers GND)

// Sorties relais (actif bas)
const int valveRelayPins[6] = {2, 3, 4, 5, 7, 8};         // Vannes 1..6
const int pumpRelayPin      = 6;                          // Pompe
const int basinPumpRelayPin = 11;                         // Moteur bassin

// ======================= Temps réglables =======================
unsigned long preValveMs  = 1000;   // vanne ON -> attendre -> pompe ON
unsigned long postPumpMs  = 1000;   // pompe OFF -> attendre -> vanne OFF
unsigned long waterMs[6]  = {5000,5000,5000,5000,5000,5000}; // durée par zone

// ======================= Etats relais (actif bas) =======================
// OFF = HIGH, ON = LOW
int valveState[6] = {HIGH, HIGH, HIGH, HIGH, HIGH, HIGH};
int pumpState     = HIGH;
int basinPumpState = HIGH;

BoutonToggle boutons[6] = {
  BoutonToggle(buttonPins[0]),
  BoutonToggle(buttonPins[1]),
  BoutonToggle(buttonPins[2]),
  BoutonToggle(buttonPins[3]),
  BoutonToggle(buttonPins[4]),
  BoutonToggle(buttonPins[5])
};
BoutonToggle autoBtn(autoButtonPin);

bool anyValveOn() {
  for (int i = 0; i < 6; i++) if (valveState[i] == LOW) return true;
  return false;
}

// ======================= AUTO state machine =======================
bool autoRunning = false;
int autoZone = 0;
unsigned long t0 = 0;

enum AutoStep {
  AUTO_IDLE,
  AUTO_VALVE_ON_WAIT,
  AUTO_PUMP_ON_WAIT,
  AUTO_PUMP_OFF_WAIT,
  AUTO_VALVE_OFF_WAIT,
  AUTO_STOP_WAIT_CLOSE_ALL
};
AutoStep autoStep = AUTO_IDLE;

void startAuto() {
  // stop tout
  pumpState = HIGH;
  digitalWrite(pumpRelayPin, pumpState);
  for (int i = 0; i < 6; i++) {
    valveState[i] = HIGH;
    digitalWrite(valveRelayPins[i], valveState[i]);
  }

  autoRunning = true;
  autoZone = 0;
  autoStep = AUTO_VALVE_ON_WAIT;
  t0 = millis();

  // ouvrir la 1ère vanne
  valveState[autoZone] = LOW;
  digitalWrite(valveRelayPins[autoZone], valveState[autoZone]);

  logLine("=== MODE AUTO START ===");
  logLine("Zone " + String(autoZone + 1) + " ON (vanne)");
}

void stopAuto() {
  autoRunning = true; // reste vrai jusqu'à fermeture propre
  autoStep = AUTO_STOP_WAIT_CLOSE_ALL;
  t0 = millis();

  pumpState = HIGH;
  digitalWrite(pumpRelayPin, pumpState);
  logLine("Moteur OFF (STOP AUTO)");
  logLine("Attente puis vannes OFF");
}

void handleAuto() {
  unsigned long now = millis();

  switch (autoStep) {
    case AUTO_VALVE_ON_WAIT:
      if (now - t0 >= preValveMs) {
        pumpState = LOW;
        digitalWrite(pumpRelayPin, pumpState);
        logLine("Moteur ON");

        autoStep = AUTO_PUMP_ON_WAIT;
        t0 = now;
      }
      break;

    case AUTO_PUMP_ON_WAIT:
      if (now - t0 >= waterMs[autoZone]) {
        pumpState = HIGH;
        digitalWrite(pumpRelayPin, pumpState);
        logLine("Moteur OFF");

        autoStep = AUTO_PUMP_OFF_WAIT;
        t0 = now;
      }
      break;

    case AUTO_PUMP_OFF_WAIT:
      if (now - t0 >= postPumpMs) {
        valveState[autoZone] = HIGH;
        digitalWrite(valveRelayPins[autoZone], valveState[autoZone]);
        logLine("Zone " + String(autoZone + 1) + " OFF (vanne)");

        autoStep = AUTO_VALVE_OFF_WAIT;
        t0 = now;
      }
      break;

    case AUTO_VALVE_OFF_WAIT:
      autoZone++;
      if (autoZone >= 6) {
        logLine("=== MODE AUTO DONE ===");
        stopAuto();
      } else {
        valveState[autoZone] = LOW;
        digitalWrite(valveRelayPins[autoZone], valveState[autoZone]);
        logLine("Zone " + String(autoZone + 1) + " ON (vanne)");

        autoStep = AUTO_VALVE_ON_WAIT;
        t0 = now;
      }
      break;

    case AUTO_STOP_WAIT_CLOSE_ALL:
      if (now - t0 >= postPumpMs) {
        for (int i = 0; i < 6; i++) {
          valveState[i] = HIGH;
          digitalWrite(valveRelayPins[i], valveState[i]);
        }
        logLine("Toutes les vannes OFF");
        logLine("=== MODE AUTO STOP ===");

        autoRunning = false;
        autoStep = AUTO_IDLE;
      }
      break;

    default:
      break;
  }
}

// ======================= MANUEL sans delay (mini state) =======================
bool manualBusy = false;
int manualZone = -1;
unsigned long manualT0 = 0;

enum ManualStep {
  MANUAL_IDLE,
  MANUAL_WAIT_BEFORE_PUMP_ON,
  MANUAL_WAIT_BEFORE_VALVE_OFF
};
ManualStep manualStep = MANUAL_IDLE;

void handleManual() {
  unsigned long now = millis();
  if (!manualBusy) return;

  switch (manualStep) {
    case MANUAL_WAIT_BEFORE_PUMP_ON:
      if (now - manualT0 >= preValveMs) {
        pumpState = LOW;
        digitalWrite(pumpRelayPin, pumpState);
        logLine("Moteur ON");

        manualBusy = false;
        manualStep = MANUAL_IDLE;
        manualZone = -1;
      }
      break;

    case MANUAL_WAIT_BEFORE_VALVE_OFF:
      if (now - manualT0 >= postPumpMs) {
        valveState[manualZone] = HIGH;
        digitalWrite(valveRelayPins[manualZone], valveState[manualZone]);
        logLine("Zone " + String(manualZone + 1) + " OFF (vanne)");

        manualBusy = false;
        manualStep = MANUAL_IDLE;
        manualZone = -1;
      }
      break;

    default:
      break;
  }
}

// ======================= Activation zone manuel =======================
void activateZone(int zone) {
  if (zone < 0 || zone >= 6) return;

  if (valveState[zone] == HIGH) {
    if (anyValveOn()) {
      logLine("Impossible zone " + String(zone+1) + " (autre ON)");
      return;
    }

    valveState[zone] = LOW;
    digitalWrite(valveRelayPins[zone], valveState[zone]);
    logLine("Zone " + String(zone + 1) + " ON (vanne)");

    manualBusy = true;
    manualZone = zone;
    manualStep = MANUAL_WAIT_BEFORE_PUMP_ON;
    manualT0 = millis();
  }
}

void deactivateZone(int zone) {
  if (zone < 0 || zone >= 6) return;

  if (valveState[zone] == LOW) {
    pumpState = HIGH;
    digitalWrite(pumpRelayPin, pumpState);
    logLine("Moteur OFF");

    manualBusy = true;
    manualZone = zone;
    manualStep = MANUAL_WAIT_BEFORE_VALVE_OFF;
    manualT0 = millis();
  }
}

// ======================= Communication ESP32 =======================
void handleESP32Commands() {
  if (Serial3.available()) {
    String cmd = Serial3.readStringUntil('\n');
    cmd.trim();
    if (cmd.length() == 0) return;

    Serial.println("ESP32 CMD: " + cmd);

    // ZONEi:ON / ZONEi:OFF
    if (cmd.startsWith("ZONE")) {
      int zoneNum = cmd.substring(4, 5).toInt(); // 1..6
      String action = cmd.substring(6);          // ON/OFF

      if (zoneNum >= 1 && zoneNum <= 6) {
        if (action == "ON") activateZone(zoneNum - 1);
        else if (action == "OFF") deactivateZone(zoneNum - 1);
      }
    }
    // AUTO
    else if (cmd == "AUTO:START") {
      if (!autoRunning) startAuto();
    }
    else if (cmd == "AUTO:STOP") {
      if (autoRunning) stopAuto();
    }
    // BASIN
    else if (cmd == "BASIN:ON") {
      basinPumpState = LOW;
      digitalWrite(basinPumpRelayPin, basinPumpState);
      logLine("Bassin ON");
    }
    else if (cmd == "BASIN:OFF") {
      basinPumpState = HIGH;
      digitalWrite(basinPumpRelayPin, basinPumpState);
      logLine("Bassin OFF");
    }
    // SETTIMEi:seconds
    else if (cmd.startsWith("SETTIME")) {
      int zoneNum = cmd.substring(7, 8).toInt();
      int duration = cmd.substring(9).toInt();

      if (zoneNum >= 1 && zoneNum <= 6 && duration > 0) {
        waterMs[zoneNum - 1] = (unsigned long)duration * 1000UL;
        logLine("Temps zone " + String(zoneNum) + " = " + String(duration) + "s");
      }
    }
    // SETPREVAL:seconds
    else if (cmd.startsWith("SETPREVAL:")) {
      int val = cmd.substring(10).toInt();
      if (val > 0) {
        preValveMs = (unsigned long)val * 1000UL;
        logLine("Attente V->P = " + String(val) + "s");
      }
    }
    // SETPOSTPUMP:seconds
    else if (cmd.startsWith("SETPOSTPUMP:")) {
      int val = cmd.substring(12).toInt();
      if (val > 0) {
        postPumpMs = (unsigned long)val * 1000UL;
        logLine("Attente P->V = " + String(val) + "s");
      }
    }
    // STATUS?
    else if (cmd == "STATUS?") {
      sendStatus();
    }
  }
}

void sendStatus() {
  String status = "STATUS:";
  status += "AUTO=" + String(autoRunning ? "1" : "0") + ",";
  status += "PUMP=" + String(pumpState == LOW ? "1" : "0") + ",";
  status += "ZONES=";

  for (int i = 0; i < 6; i++) {
    status += String(valveState[i] == LOW ? "1" : "0");
    if (i < 5) status += ",";
  }

  Serial3.println(status);
}

// ======================= SETUP / LOOP =======================
void setup() {
  Serial.begin(9600);
  Serial3.begin(9600);  // RX3=15, TX3=14

  for (int i = 0; i < 6; i++) {
    pinMode(valveRelayPins[i], OUTPUT);
    digitalWrite(valveRelayPins[i], valveState[i]);
    boutons[i].begin();
  }

  pinMode(pumpRelayPin, OUTPUT);
  digitalWrite(pumpRelayPin, pumpState);

  pinMode(basinPumpRelayPin, OUTPUT);
  digitalWrite(basinPumpRelayPin, basinPumpState);

  autoBtn.begin();

  logLine("======================");
  logLine("Irrigation System");
  logLine("Version ESP32");
  logLine("======================");
  logLine("System READY");
  logLine("Pompe: D6");
  logLine("Bassin: D11");
  logLine("Vannes: D2,D3,D4,D5,D7,D8");
  logLine("AUTO bouton: D27");
  logLine("Boutons zones: 29,31,53,37,43,35");
  logLine("ESP32: Serial3 (RX3/TX3)");
}

void loop() {
  handleESP32Commands();

  // Bouton AUTO (physique)
  if (autoBtn.pressed()) {
    if (!autoRunning) startAuto();
    else stopAuto();
  }

  // AUTO actif
  if (autoRunning) {
    handleAuto();
    return;
  }

  // Manuel non bloquant
  handleManual();
  if (manualBusy) return;

  // Boutons zones (manuel)
  for (int i = 0; i < 6; i++) {
    if (boutons[i].pressed()) {
      if (valveState[i] == HIGH) activateZone(i);
      else deactivateZone(i);
    }
  }
}
