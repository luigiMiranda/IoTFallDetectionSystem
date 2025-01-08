import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
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
      debugShowCheckedModeBanner: false,
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

  final String _serviceUUID = "19b10000-e8f2-537e-4f6c-d104768a1214";
  final String _fallDetectedCharUUID = "19b10001-e8f2-537e-4f6c-d104768a1214";

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    FlutterBluePlus.isSupported.then((isAvailable) {
      if (!isAvailable) {
        _showBluetoothUnavailableDialog();
      }
    });
  }

  Future<void> _requestPermissions() async {
    await Permission.locationWhenInUse.request();
    await Permission.location.request();

    if (!await Geolocator.isLocationServiceEnabled()) {
      _showLocationServicesDialog();
    }
  }

  void _showLocationServicesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Servizi di Localizzazione'),
          content: Text('Per favore attiva i servizi di localizzazione per permettere il rilevamento della posizione in caso di caduta.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openLocationSettings();
              },
            ),
          ],
        );
      },
    );
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
    await FlutterBluePlus.turnOn();

    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    await FlutterBluePlus.startScan(
      timeout: Duration(seconds: 10),
      androidUsesFineLocation: true,
    );

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _scanResults = results;
      });
    });

    FlutterBluePlus.isScanning.listen((isScanning) {
      setState(() {
        _isScanning = isScanning;
      });
    });
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  void _connectToDevice(ScanResult result) async {
    await FlutterBluePlus.stopScan();

    try {
      await result.device.connect(
        autoConnect: false,
        timeout: Duration(seconds: 15),
      );

      List<BluetoothService> services = await result.device.discoverServices();

      for (BluetoothService service in services) {
        if (service.uuid.toString().toUpperCase() == _serviceUUID.toUpperCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase() == _fallDetectedCharUUID.toUpperCase()) {
              await characteristic.setNotifyValue(true);

              characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty && value[0] == 49) {
                  _handleFallDetection(); // Replace _showFallAlert() with this
                }
              });
            }
          }
          break;
        }
      }

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



  Future<void> _handleFallDetection() async {
    _showInAppAlert();
    await _sendTelegramAlert();
  }

  void _showInAppAlert() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('CADUTA RILEVATA!'),
          content: Text('È stata rilevata una possibile caduta. Un messaggio di allerta è stato inviato ai contatti di emergenza.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendTelegramAlert() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('telegram_token');
    final chatIds = prefs.getStringList('telegram_chat_ids') ?? [];
    final userName = prefs.getString('user_name') ?? '';

    final now = DateTime.now();
    final formattedTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final formattedDate = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

    Position? position = await _getCurrentLocation();
    String locationInfo = '';
    String mapsLink = '';

    if (position != null) {
      locationInfo = '\nPosizione: ${position.latitude}, ${position.longitude}';
      mapsLink = '\nMappa: https://www.google.com/maps?q=${position.latitude},${position.longitude}';
    } else {
      locationInfo = '\nPosizione: Non disponibile';
    }

    final message = userName.isNotEmpty
        ? 'ATTENZIONE: È stata rilevata una possibile caduta di $userName!\n'
        'Data e ora: $formattedDate alle $formattedTime$locationInfo$mapsLink'
        : 'ATTENZIONE: È stata rilevata una possibile caduta!\n'
        'Data e ora: $formattedDate alle $formattedTime$locationInfo$mapsLink';

    if (token != null && chatIds.isNotEmpty) {
      for (String chatId in chatIds) {
        try {
          final encodedMessage = Uri.encodeComponent(message);
          final response = await http.get(
            Uri.parse(
                'https://api.telegram.org/bot$token/sendMessage?chat_id=$chatId&text=$encodedMessage'
            ),
          );

          if (position != null) {
            await http.get(
              Uri.parse(
                  'https://api.telegram.org/bot$token/sendLocation?chat_id=$chatId&latitude=${position.latitude}&longitude=${position.longitude}'
              ),
            );
          }
        } catch (e) {
          print('Errore nella comunicazione con Telegram per $chatId: $e');
        }
      }
    }
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
                  title: Text(result.device.platformName.isEmpty
                      ? 'Dispositivo sconosciuto'
                      : result.device.platformName),
                  subtitle: Text(result.device.remoteId.toString()),
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
              'Dispositivo connesso: ${widget.device.platformName}',
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
  late TextEditingController _newChatIdController;
  late TextEditingController _userNameController;
  List<String> _chatIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController();
    _newChatIdController = TextEditingController();
    _userNameController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tokenController.text = prefs.getString('telegram_token') ?? '';
      _userNameController.text = prefs.getString('user_name') ?? '';
      _chatIds = prefs.getStringList('telegram_chat_ids') ?? [];
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('telegram_token', _tokenController.text);
      await prefs.setString('user_name', _userNameController.text);
      await prefs.setStringList('telegram_chat_ids', _chatIds);

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impostazioni salvate con successo'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _addChatId() {
    if (_newChatIdController.text.isNotEmpty &&
        !_chatIds.contains(_newChatIdController.text)) {
      setState(() {
        _chatIds.add(_newChatIdController.text);
        _newChatIdController.clear();
      });
    }
  }

  void _removeChatId(String chatId) {
    setState(() {
      _chatIds.remove(chatId);
    });
  }

  Widget _buildInstructions() {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Come ottenere il tuo Chat ID:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '1. Cerca il bot su Telegram usando il nome del tuo bot\n'
                  '2. Avvia il bot cliccando Start o inviando /start\n'
                  '3. Invia il comando /getchatid\n'
                  '4. Il bot risponderà con il tuo Chat ID\n'
                  '5. Copia il numero e incollalo qui sotto',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyConnectionWithBot() async {
    if (_chatIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aggiungi almeno un Chat ID prima di verificare la connessione'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final token = _tokenController.text;
    final userName = _userNameController.text;
    bool hasError = false;

    for (String chatId in _chatIds) {
      try {
        final message = userName.isNotEmpty
            ? 'Test di connessione per il dispositivo di $userName: La connessione al bot è attiva!'
            : 'Test di connessione: La connessione al bot è attiva!';

        final response = await http.get(
          Uri.parse(
              'https://api.telegram.org/bot$token/sendMessage?chat_id=$chatId&text=$message'
          ),
        );

        if (response.statusCode != 200) {
          hasError = true;
          print('Errore nell\'invio del messaggio di verifica a $chatId: ${response.body}');
        }
      } catch (e) {
        hasError = true;
        print('Errore nella comunicazione con Telegram per $chatId: $e');
      }
    }

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            hasError
                ? 'Errore nella verifica della connessione. Controlla il token e i Chat ID.'
                : 'Connessione verificata con successo! Controlla Telegram.'
        ),
        backgroundColor: hasError ? Colors.red : Colors.green,
      ),
    );
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
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _userNameController,
                decoration: InputDecoration(
                  labelText: 'Nome Utente',
                  hintText: 'Inserisci il nome di chi indossa il dispositivo',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Per favore inserisci il nome';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
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
              _buildInstructions(),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _newChatIdController,
                      decoration: InputDecoration(
                        labelText: 'Nuovo Chat ID',
                        hintText: 'Inserisci il chat ID ottenuto dal bot',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: _addChatId,
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text('Chat ID Registrati:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _chatIds.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_chatIds[index]),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _removeChatId(_chatIds[index]),
                    ),
                  );
                },
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blue,
                ),
                child: Text(
                  'Salva Impostazioni',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: _verifyConnectionWithBot,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.green,
                ),
                child: Text(
                  'Verifica Connessione Bot',
                  style: TextStyle(fontSize: 16, color: Colors.white),
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
    _newChatIdController.dispose();
    _userNameController.dispose();
    super.dispose();
  }
}