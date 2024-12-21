# Sistema di Rilevamento Cadute con Arduino Nano 33 BLE e App Flutter

Questo progetto implementa un sistema wearable per il rilevamento di cadute, pensato principalmente per persone anziane sopra i 65 anni. Il sistema sfrutta:

- Arduino Nano 33 BLE con sensori integrati di accelerometro e giroscopio per rilevare i movimenti del corpo.

- App Android sviluppata con Flutter, che utilizza Bluetooth Low Energy (BLE) per comunicare con Arduino.

- Bot Telegram per notificare un contatto di fiducia in caso di caduta.

Il sistema rileva una possibile caduta analizzando i dati del sensore e confrontandoli con soglie predefinite. In caso di caduta, l'app invia una notifica al bot Telegram, che a sua volta informa un contatto fidato, permettendo un intervento tempestivo.

