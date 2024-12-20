#include "Arduino_BMI270_BMM150.h"
#include <ArduinoBLE.h>
#include "utility.h"

// Soglie per la fall detection
const float THRESHOLD_AM = 3.5f;
const float THRESHOLD_ACM = 1.5f;
const float THRESHOLD_AVCM = 0.6f;
constexpr float RAD_CONVERSION = 0.017453f;  // fattore di conversione da dps a rad/s

// Inizializzazione pin per indicare errori nel funzionamento del device
constexpr int LED_PIN = LED_BUILTIN;

// BLE UUIDs salvato in PROGMEM per milgior efficienza RAM
const char SERVICE_UUID[] PROGMEM = "19b10000-e8f2-537e-4f6c-d104768a1214";
const char CHAR_UUID[] PROGMEM = "19b10001-e8f2-537e-4f6c-d104768a1214";

// DICHIARAZIONE SERVIZIO E CARATTERISTICA PER PROTOCOLLO BLE
BLEService fallDetectionService(SERVICE_UUID);
BLECharacteristic fallDetectedChar(CHAR_UUID, BLERead | BLENotify, 5);

// Buffer per il messaggio in caso di fall detetion da inviare allo smartphone
static char fallDetected[] = "1";

void initializeLEDs() {
  // Inizializzazione LED RGB per connessione bluetooth
  pinMode(LEDR, OUTPUT);
  pinMode(LEDG, OUTPUT);
  pinMode(LEDB, OUTPUT);
  
  // Stato iniziale LED RGB per connessione bluetooth
  digitalWrite(LEDR, HIGH);
  digitalWrite(LEDG, HIGH);
  digitalWrite(LEDB, HIGH);
}

bool initializeSensors() {
  pinMode(LED_PIN, OUTPUT);
  
  if (!IMU.begin() || !BLE.begin()) {
    // Error indication
    while (1) {
      digitalWrite(LED_PIN, HIGH);
      delay(500);
      digitalWrite(LED_PIN, LOW);
      delay(500);
    }
    return false;
  }
  return true;
}

void setupBLE() {
  BLE.setEventHandler(BLEConnected, bleConnectHandler);
  BLE.setEventHandler(BLEDisconnected, bleDisconnectHandler);
  
  BLE.setLocalName("FallDetection");
  BLE.setAdvertisedService(fallDetectionService);
  fallDetectionService.addCharacteristic(fallDetectedChar);
  BLE.addService(fallDetectionService);
  BLE.advertise();
}

inline bool checkFallDetection(float AM, float ACM, float AVCM) {
  return (AM > THRESHOLD_AM && 
          ACM > THRESHOLD_ACM && 
          AVCM * RAD_CONVERSION > THRESHOLD_AVCM);
}

void handleFallDetection() {
  fallDetectedChar.writeValue(fallDetected);
  digitalWrite(LED_PIN, HIGH);
  delay(3000);
  digitalWrite(LED_PIN, LOW);
}

void setup() {
  initializeLEDs();
  if (initializeSensors()) {
    setupBLE();
  }
}

void loop() {
  BLE.poll();

  if (!isConnected) {
    // Enter low power mode when not connected
    delay(100);  // Longer delay to save power
    return;
  }

  static float ax, ay, az, gx, gy, gz;
  
  if (IMU.accelerationAvailable()) {
    IMU.readAcceleration(ax, ay, az);
    IMU.readGyroscope(gx, gy, gz);
    
    float AM = calculateAM(ax, ay, az);
    float ACM = calculateACM_AVCM(ax, ay, az);
    float AVCM = calculateACM_AVCM(gx, gy, gz);

    if (checkFallDetection(AM, ACM, AVCM)) {
      handleFallDetection();
    }
  }

  delay(5);
}