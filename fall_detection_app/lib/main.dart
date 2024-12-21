import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(FallDetectionApp());
}

class FallDetectionApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rilevamento Cadute',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: BluetoothScanPage(),
    );
  }
}

class BluetoothScanPage extends StatefulWidget {
  @override
  _BluetoothScanPageState createState() => _BluetoothScanPageState();
}

class _BluetoothScanPageState extends State<BluetoothScanPage> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  BluetoothDevice? _connectedDevice;

  // UUID del servizio dall'Arduino
  final String _serviceUUID = "19b10000-e8f2-537e-4f6c-d104768a1214";
  final String _fallDetectedCharUUID = "19b10001-e8f2-537e-4f6c-d104768a1214";

  @override
  void initState() {
    super.initState();
    // Inizializza lo stato del Bluetooth
    FlutterBluePlus.isAvailable.then((isAvailable) {
      if (!isAvailable) {
        _showBluetoothUnavailableDialog();
      }
    });
  }

  void _showBluetoothUnavailableDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Bluetooth non disponibile'),
          content: Text('Questo dispositivo non supporta il Bluetooth.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _startBluetoothScan() async {
    // Abilita Bluetooth se non è già acceso
    await FlutterBluePlus.turnOn();

    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    // Avvia la scansione
    await FlutterBluePlus.startScan(
      timeout: Duration(seconds: 10),
      androidUsesFineLocation: true,
    );

    // Ascolta i risultati della scansione
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _scanResults = results;
      });
    });

    // Quando la scansione è completata
    FlutterBluePlus.isScanning.listen((isScanning) {
      setState(() {
        _isScanning = isScanning;
      });
    });
  }

  void _connectToDevice(ScanResult result) async {
    // Ferma la scansione se è ancora in corso
    await FlutterBluePlus.stopScan();

    try {
      // Connetti al dispositivo
      await result.device.connect(
        autoConnect: false,
        timeout: Duration(seconds: 15),
      );

      // Scopri i servizi
      List<BluetoothService> services = await result.device.discoverServices();

      // Cerca il servizio specifico
      for (BluetoothService service in services) {
        if (service.uuid.toString().toUpperCase() == _serviceUUID.toUpperCase()) {
          // Trova la caratteristica di rilevamento cadute
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase() == _fallDetectedCharUUID.toUpperCase()) {
              // Abilita le notifiche
              await characteristic.setNotifyValue(true);

              // Ascolta i valori
              characteristic.value.listen((value) {
                if (value.isNotEmpty && value[0] == 49) { // ASCII '1'
                  _showFallAlert();
                }
              });
            }
          }
          break;
        }
      }

      // Naviga alla pagina di rilevamento cadute
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FallDetectionPage(device: result.device),
        ),
      );

      setState(() {
        _connectedDevice = result.device;
      });

    } catch (e) {
      print("Errore di connessione: $e");
      _showConnectionErrorDialog();
    }
  }

  void _showConnectionErrorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Errore di Connessione'),
          content: Text('Impossibile connettersi al dispositivo. Riprova.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showFallAlert() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('telegram_token');
    final chatId = prefs.getString('telegram_chat_id');

    if (token != null && chatId != null) {
      try {
        final response = await http.get(
          Uri.parse(
              'https://api.telegram.org/bot$token/sendMessage?chat_id=$chatId&text=ATTENZIONE: È stata rilevata una possibile caduta!'
          ),
        );

        if (response.statusCode != 200) {
          print('Errore nell\'invio del messaggio Telegram: ${response.body}');
        }
      } catch (e) {
        print('Errore nella comunicazione con Telegram: $e');
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('CADUTA RILEVATA!'),
          content: Text('È stata rilevata una possibile caduta. Verificare lo stato della persona.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scansione Dispositivi Bluetooth'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: Icon(_isScanning ? Icons.stop : Icons.bluetooth_searching),
              label: Text(_isScanning ? 'Interrompi Scansione' : 'Avvia Scansione'),
              onPressed: _isScanning ? FlutterBluePlus.stopScan : _startBluetoothScan,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ),
          _isScanning
              ? LinearProgressIndicator()
              : SizedBox.shrink(),
          Expanded(
            child: _scanResults.isEmpty
                ? Center(child: Text('Nessun dispositivo trovato'))
                : ListView.builder(
              itemCount: _scanResults.length,
              itemBuilder: (context, index) {
                ScanResult result = _scanResults[index];
                return ListTile(
                  title: Text(result.device.name.isEmpty
                      ? 'Dispositivo sconosciuto'
                      : result.device.name),
                  subtitle: Text(result.device.id.toString()),
                  trailing: Text('RSSI: ${result.rssi} dBm'),
                  onTap: () => _connectToDevice(result),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FallDetectionPage extends StatefulWidget {
  final BluetoothDevice device;

  const FallDetectionPage({Key? key, required this.device}) : super(key: key);

  @override
  _FallDetectionPageState createState() => _FallDetectionPageState();
}

class _FallDetectionPageState extends State<FallDetectionPage> {
  bool _isFallDetected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rilevamento Cadute'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.bluetooth_connected,
              size: 100,
              color: Colors.blue,
            ),
            SizedBox(height: 20),
            Text(
              'Dispositivo connesso: ${widget.device.name}',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Text(
              _isFallDetected ? 'CADUTA RILEVATA!' : 'Nessuna caduta rilevata',
              style: TextStyle(
                  fontSize: 22,
                  color: _isFallDetected ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.device.disconnect();
    super.dispose();
  }
}
/*-------------------------------------------------------*/
//SETING PAGE

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tokenController;
  late TextEditingController _chatIdController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController();
    _chatIdController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tokenController.text = prefs.getString('telegram_token') ?? '';
      _chatIdController.text = prefs.getString('telegram_chat_id') ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('telegram_token', _tokenController.text);
      await prefs.setString('telegram_chat_id', _chatIdController.text);

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impostazioni salvate con successo'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _verifyConnectionWithBot() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('telegram_token');
    final chatId = prefs.getString('telegram_chat_id');

    if (token != null && chatId != null) {
      try {
        final response = await http.get(
          Uri.parse(
              'https://api.telegram.org/bot$token/sendMessage?chat_id=$chatId&text=Verifica connessione al bot'),
        );

        if (response.statusCode == 200) {
          print('Connessione verificata con successo');
        } else {
          print('Errore nell\'invio del messaggio di verifica: ${response.body}');
        }
      } catch (e) {
        print('Errore nella comunicazione con Telegram: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Impostazioni')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Impostazioni'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _tokenController,
                decoration: InputDecoration(
                  labelText: 'Token Bot Telegram',
                  hintText: 'Inserisci il token del tuo bot',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Per favore inserisci il token';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _chatIdController,
                decoration: InputDecoration(
                  labelText: 'Chat ID',
                  hintText: 'Inserisci il chat ID',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Per favore inserisci il chat ID';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveSettings,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Salva Impostazioni',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _verifyConnectionWithBot,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Verifica Connessione con Bot',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _chatIdController.dispose();
    super.dispose();
  }
}