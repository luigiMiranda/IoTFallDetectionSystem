#include <ArduinoBLE.h>
// Variabile per controllare se un dispositivo è connesso al device
bool isConnected = false;
// Gestore connessione BLE
void bleConnectHandler(BLEDevice central) {
  isConnected = true;
  // LED verde quando connesso
  digitalWrite(LEDR, HIGH);
  digitalWrite(LEDG, LOW);
  digitalWrite(LEDB, HIGH);
}

// Gestore disconnessione BLE
void bleDisconnectHandler(BLEDevice central) {
  isConnected = false;
  // Riavvia l'advertising
  BLE.advertise();
   
  // LED rosso quando disconnesso
  digitalWrite(LEDR, LOW);
  digitalWrite(LEDG, HIGH);
  digitalWrite(LEDB, HIGH);
} 



// Funzione per calcolare Signal Vector Magnitude (SVM)
float calculateAM(float x, float y, float z) {
  return sqrt(x * x + y * y + z * z);
}
// Funzione per calcolare ACM e ACVM
float calculateACM_AVCM(float x, float y, float z) {
  return cbrt(abs(x * y * z));
}