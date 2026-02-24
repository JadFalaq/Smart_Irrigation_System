#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

// ======================= Configuration WiFi =======================

// --------- WiFi ----------
#define WIFI_SSID     "A26"
#define WIFI_PASSWORD "20042004"

// --------- Firebase ----------
#define API_KEY "AIzaSyDeoCmqLt0_OF8waCMc1F83_6RsKDNwVEY"
#define DATABASE_URL "https://mikafa-538d9-default-rtdb.firebaseio.com/"
#define USER_EMAIL "admin@mikafa.com"
#define USER_PASSWORD "Admin123"

// ID de l'administrateur pour l'ESP32
#define ADMIN_UID "MRsUiMmeOjRwXNUR1fJhRMeFIUC2"
#define DB_PATH "/users/" ADMIN_UID "/irrigation"

// ======================= Objets Firebase =======================
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

unsigned long sendDataPrevMillis = 0;
bool signupOK = false;

// ======================= Communication Serial avec Arduino =======================
#define RXD2 16  // RX ESP32 <- TX3 Mega (pin 14 via diviseur)
#define TXD2 17  // TX ESP32 -> RX3 Mega (pin 15)

// ======================= Variables d'état =======================
struct IrrigationState {
  bool zones[6];
  bool pump;
  bool autoMode;
  bool basin;
  unsigned long zoneTimes[6];
  unsigned long preValveMs;
  unsigned long postPumpMs;
  String lastLog;
} state;

String getTimestamp() {
  unsigned long ms = millis();
  unsigned long sec = ms / 1000;
  unsigned long min = sec / 60;
  unsigned long hr = min / 60;
  return String(hr % 24) + ":" + String(min % 60) + ":" + String(sec % 60);
}

void sendToArduino(const String &command) {
  Serial2.println(command);
  Serial.println("Envoyé à Arduino: " + command);
}

void initializeDatabase() {
  if (Firebase.ready() && signupOK) {
    for (int i = 0; i < 6; i++) {
      Firebase.RTDB.setBool(&fbdo, DB_PATH "/zones/zone" + String(i + 1) + "/active", false);
      Firebase.RTDB.setInt(&fbdo,  DB_PATH "/zones/zone" + String(i + 1) + "/duration", 5);
    }

    Firebase.RTDB.setBool(&fbdo,   DB_PATH "/pump/active", false);
    Firebase.RTDB.setBool(&fbdo,   DB_PATH "/basin/active", false);
    Firebase.RTDB.setBool(&fbdo,   DB_PATH "/auto/running", false);
    Firebase.RTDB.setInt(&fbdo,    DB_PATH "/settings/preValve", 1);
    Firebase.RTDB.setInt(&fbdo,    DB_PATH "/settings/postPump", 1);
    Firebase.RTDB.setString(&fbdo, DB_PATH "/status/message", "System Ready");
    Firebase.RTDB.setString(&fbdo, DB_PATH "/status/connection", "online");
    Firebase.RTDB.setString(&fbdo, DB_PATH "/status/lastUpdate", getTimestamp());

    Serial.println("Base de données initialisée");
  }
}

void setupListeners() {
  if (!Firebase.RTDB.beginStream(&fbdo, DB_PATH "/commands")) {
    Serial.println("Erreur stream: " + fbdo.errorReason());
  }
}

void parseArduinoMessage(String msg) {
  String low = msg;
  low.toLowerCase();

  // Zones
  if (low.indexOf("zone") >= 0) {
    for (int i = 1; i <= 6; i++) {
      if (low.indexOf("zone " + String(i)) >= 0) {
        bool isOn = (low.indexOf(" on") >= 0);
        state.zones[i - 1] = isOn;
        Firebase.RTDB.setBool(&fbdo, DB_PATH "/zones/zone" + String(i) + "/active", isOn);
      }
    }
  }

  // Pompe
  if (low.indexOf("moteur on") >= 0) {
    state.pump = true;
    Firebase.RTDB.setBool(&fbdo, DB_PATH "/pump/active", true);
  } else if (low.indexOf("moteur off") >= 0) {
    state.pump = false;
    Firebase.RTDB.setBool(&fbdo, DB_PATH "/pump/active", false);
  }

  // Bassin
  if (low.indexOf("bassin on") >= 0) {
    state.basin = true;
    Firebase.RTDB.setBool(&fbdo, DB_PATH "/basin/active", true);
  } else if (low.indexOf("bassin off") >= 0) {
    state.basin = false;
    Firebase.RTDB.setBool(&fbdo, DB_PATH "/basin/active", false);
  }

  // Auto
  if (low.indexOf("mode auto start") >= 0) {
    state.autoMode = true;
    Firebase.RTDB.setBool(&fbdo, DB_PATH "/auto/running", true);
  } else if (low.indexOf("mode auto done") >= 0 || low.indexOf("mode auto stop") >= 0) {
    state.autoMode = false;
    Firebase.RTDB.setBool(&fbdo, DB_PATH "/auto/running", false);
  }
}

void readFromArduino() {
  if (Serial2.available()) {
    String line = Serial2.readStringUntil('\n');
    line.trim();

    if (line.length() > 0) {
      Serial.println("Arduino: " + line);
      state.lastLog = line;

      if (Firebase.ready() && signupOK) {
        Firebase.RTDB.setString(&fbdo, DB_PATH "/logs/latest", line);
        Firebase.RTDB.setString(&fbdo, DB_PATH "/status/lastUpdate", getTimestamp());
        parseArduinoMessage(line);
      }
    }
  }
}

void handleFirebaseCommands() {
  if (!(Firebase.ready() && signupOK)) return;

  // zones 1..6
  for (int i = 1; i <= 6; i++) {
    if (Firebase.RTDB.getBool(&fbdo, DB_PATH "/commands/zone" + String(i))) {
      bool cmd = fbdo.boolData();
      sendToArduino("ZONE" + String(i) + ":" + (cmd ? "ON" : "OFF"));
      Firebase.RTDB.deleteNode(&fbdo, DB_PATH "/commands/zone" + String(i));
    }
  }

  // auto
  if (Firebase.RTDB.getBool(&fbdo, DB_PATH "/commands/autoStart")) {
    if (fbdo.boolData()) {
      sendToArduino("AUTO:START");
      Firebase.RTDB.deleteNode(&fbdo, DB_PATH "/commands/autoStart");
    }
  }
  if (Firebase.RTDB.getBool(&fbdo, DB_PATH "/commands/autoStop")) {
    if (fbdo.boolData()) {
      sendToArduino("AUTO:STOP");
      Firebase.RTDB.deleteNode(&fbdo, DB_PATH "/commands/autoStop");
    }
  }

  // bassin
  if (Firebase.RTDB.getBool(&fbdo, DB_PATH "/commands/basinStart")) {
    if (fbdo.boolData()) {
      sendToArduino("BASIN:ON");
      Firebase.RTDB.deleteNode(&fbdo, DB_PATH "/commands/basinStart");
    }
  }
  if (Firebase.RTDB.getBool(&fbdo, DB_PATH "/commands/basinStop")) {
    if (fbdo.boolData()) {
      sendToArduino("BASIN:OFF");
      Firebase.RTDB.deleteNode(&fbdo, DB_PATH "/commands/basinStop");
    }
  }

  // duration
  for (int i = 1; i <= 6; i++) {
    if (Firebase.RTDB.getInt(&fbdo, DB_PATH "/commands/setDuration" + String(i))) {
      int duration = fbdo.intData();
      sendToArduino("SETTIME" + String(i) + ":" + String(duration));
      Firebase.RTDB.deleteNode(&fbdo, DB_PATH "/commands/setDuration" + String(i));
    }
  }

  // pre/post
  if (Firebase.RTDB.getInt(&fbdo, DB_PATH "/commands/setPreValve")) {
    int val = fbdo.intData();
    sendToArduino("SETPREVAL:" + String(val));
    Firebase.RTDB.deleteNode(&fbdo, DB_PATH "/commands/setPreValve");
  }
  if (Firebase.RTDB.getInt(&fbdo, DB_PATH "/commands/setPostPump")) {
    int val = fbdo.intData();
    sendToArduino("SETPOSTPUMP:" + String(val));
    Firebase.RTDB.deleteNode(&fbdo, DB_PATH "/commands/setPostPump");
  }
}

void updateFirebaseStatus() {
  if (Firebase.ready() && signupOK) {
    if (millis() - sendDataPrevMillis > 5000 || sendDataPrevMillis == 0) {
      sendDataPrevMillis = millis();
      sendToArduino("STATUS?");
      Firebase.RTDB.setString(&fbdo, DB_PATH "/status/lastUpdate", getTimestamp());
      Firebase.RTDB.setString(&fbdo, DB_PATH "/status/connection", "online");
    }
  }
}

void setup() {
  Serial.begin(115200);
  Serial2.begin(9600, SERIAL_8N1, RXD2, TXD2);

  for (int i = 0; i < 6; i++) {
    state.zones[i] = false;
    state.zoneTimes[i] = 5000;
  }
  state.pump = false;
  state.basin = false;
  state.autoMode = false;
  state.preValveMs = 1000;
  state.postPumpMs = 1000;

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connexion WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(300);
  }
  Serial.println();
  Serial.print("Connecté avec IP: ");
  Serial.println(WiFi.localIP());

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;

  config.token_status_callback = tokenStatusCallback;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  Serial.print("Connexion Firebase");
  while (!Firebase.ready()) {
    Serial.print(".");
    delay(300);
  }
  Serial.println();
  Serial.println("Firebase connecté!");
  signupOK = true;

  initializeDatabase();
  setupListeners();
}

void loop() {
  readFromArduino();
  handleFirebaseCommands();
  updateFirebaseStatus();

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi déconnecté, reconnexion...");
    WiFi.reconnect();
  }

  delay(100);
}
