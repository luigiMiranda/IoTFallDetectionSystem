#include "Arduino_BMI270_BMM150.h"
#include <ArduinoBLE.h>

// Modalità di test
enum TestMode {
  IDLE,
  FALL_FORWARD,
  FALL_BACKWARD,
  FALL_SIDE,
  NORMAL_WALK,
  JUMPING,
  SIT_CHAIR,
  GET_UP_BED
};

// Variabili globali per il test
TestMode currentTestMode = IDLE;
unsigned long testStartTime = 0;
const unsigned long TEST_DURATION = 5000;
bool isConnected = false;

// Servizi e caratteristiche BLE per il debug
BLEService testService("19b10000-e8f2-537e-4f6c-d104768a1214");
BLECharacteristic testModeChar("19b10001-e8f2-537e-4f6c-d104768a1214", BLERead | BLEWrite, 20);
// Caratteristiche separate per accelerometro e giroscopio
BLECharacteristic accelDataChar("19b10002-e8f2-537e-4f6c-d104768a1214", BLERead | BLENotify, 20);
BLECharacteristic gyroDataChar("19b10003-e8f2-537e-4f6c-d104768a1214", BLERead | BLENotify, 20);

void setup() {
  pinMode(LEDR, OUTPUT);
  pinMode(LEDG, OUTPUT);
  pinMode(LEDB, OUTPUT);
  
  digitalWrite(LEDR, HIGH);
  digitalWrite(LEDG, HIGH);
  digitalWrite(LEDB, HIGH);
  
  if (!IMU.begin()) {
    while(1) {
      digitalWrite(LEDR, LOW);
      delay(100);
      digitalWrite(LEDR, HIGH);
      delay(100);
    }
  }

  if (!BLE.begin()) {
    while (1);
  }

  BLE.setEventHandler(BLEConnected, bleConnectHandler);
  BLE.setEventHandler(BLEDisconnected, bleDisconnectHandler);

  BLE.setLocalName("MovementTest");
  BLE.setAdvertisedService(testService);
  
  testService.addCharacteristic(testModeChar);
  testService.addCharacteristic(accelDataChar);
  testService.addCharacteristic(gyroDataChar);
  
  BLE.addService(testService);
  
  testModeChar.setEventHandler(BLEWritten, onTestModeReceived);
  
  BLE.advertise();
}

void bleConnectHandler(BLEDevice central) {
  isConnected = true;
  digitalWrite(LEDR, HIGH);
  digitalWrite(LEDG, LOW);
  digitalWrite(LEDB, HIGH);
}

void bleDisconnectHandler(BLEDevice central) {
  isConnected = false;
  BLE.advertise();
  currentTestMode = IDLE;
  digitalWrite(LEDR, LOW);
  digitalWrite(LEDG, HIGH);
  digitalWrite(LEDB, HIGH);
}

void onTestModeReceived(BLEDevice central, BLECharacteristic characteristic) {
  uint8_t testModeValue;
  characteristic.readValue(testModeValue);
  currentTestMode = static_cast<TestMode>(testModeValue);
  testStartTime = millis();
  digitalWrite(LEDR, HIGH);
  digitalWrite(LEDG, HIGH);
  digitalWrite(LEDB, LOW);
}

void loop() {
  BLE.poll();

  if (isConnected && currentTestMode != IDLE) {
    float ax, ay, az;
    float gx, gy, gz;
    
    if (IMU.accelerationAvailable() && IMU.gyroscopeAvailable()) {
      IMU.readAcceleration(ax, ay, az);
      IMU.readGyroscope(gx, gy, gz);
      
      // Buffer separati per accelerometro e giroscopio
      char accelBuffer[20];
      char gyroBuffer[20];
      
      snprintf(accelBuffer, sizeof(accelBuffer), 
               "%d,%.2f,%.2f,%.2f", 
               currentTestMode, ax, ay, az);
               
      snprintf(gyroBuffer, sizeof(gyroBuffer), 
               "%d,%.2f,%.2f,%.2f", 
               currentTestMode, gx, gy, gz);
               
      accelDataChar.writeValue(accelBuffer);
      gyroDataChar.writeValue(gyroBuffer);
    }
    
    if (millis() - testStartTime >= TEST_DURATION) {
      currentTestMode = IDLE;
      digitalWrite(LEDR, HIGH);
      digitalWrite(LEDG, LOW);
      digitalWrite(LEDB, HIGH);
    }
  }
  
  delay(5);
}