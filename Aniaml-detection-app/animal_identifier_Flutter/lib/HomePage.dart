import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'ResultPage.dart';

class HomePage extends StatefulWidget {
  @override
  _AnimalRecognitionHomePageState createState() =>
      _AnimalRecognitionHomePageState();
}

class _AnimalRecognitionHomePageState extends State<HomePage> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  String _deviceId = "Bilinmiyor"; // Cihaz kimliği başlangıç değeri
  List<Map<String, String>> _recognizedAnimals = []; // Geçmiş tanınan hayvanlar
  bool _isHistoryVisible = false; // Geçmiş kısmının görünürlüğünü kontrol

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // Asenkron işlemleri başlatma
  Future<void> _initialize() async {
    await _getDeviceId(); // Cihaz kimliğini al
    await _fetchHistory(); // Geçmiş verisini çek
  }

  // Cihaz Kimliğini Al
  Future<void> _getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String deviceId = "Bilinmiyor";

    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id; // Android cihaz ID
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? "Bilinmiyor"; // iOS cihaz ID
      }
    } catch (e) {
      print("Cihaz kimliği alınamadı: $e");
    }

    setState(() {
      _deviceId = deviceId;
    });
  }

  // Geçmişi API'den çekme
  Future<void> _fetchHistory() async {
    if (_deviceId == "Bilinmiyor" || _deviceId.isEmpty) {
      print("Cihaz kimliği henüz alınamadı.");
      return;
    }

    final uri = Uri.parse("http://<APIURI>:8000/histories/$_deviceId");
    try {
      final response = await http.get(uri);
      final responseBody = utf8.decode(response.bodyBytes);
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        if (data.containsKey('data') && data['data'] != null) {
          setState(() {
            _recognizedAnimals = List<Map<String, String>>.from(
              data['data'].take(5).map((item) {
                return {
                  'AnimalName': item['AnimalName']?.toString() ?? 'Bilinmeyen Hayvan',
                  'ImageURL': item['ImageURL']?.toString() ?? '',
                  'Habitat': item['Habitat']?.toString() ?? 'Açıklama mevcut değil.',
                  'Nutrition': item['Nutrition']?.toString() ?? 'Bilinmiyor',
                };
              }),
            );
          });
        } else {
          setState(() {
            _recognizedAnimals = [];
          });
        }
      } else {
        _showErrorMessage("API Hatası: ${response.statusCode}");
      }
    } catch (e) {
      _showErrorMessage("API bağlantı hatası: $e");
    }
  }

  // Resmi API'ye gönderme
  Future<void> _sendImageToApi(File image) async {
    final uri = Uri.parse("http://<APIURI>:8000/predict/");
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath("file", image.path))
      ..fields['device_id'] = _deviceId;

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = json.decode(responseBody);
        _navigateToResultPage(image, data);
      } else {
        _showErrorMessage("API Hatası: ${response.statusCode}");
      }
    } catch (e) {
      _showErrorMessage("API bağlantı hatası: $e");
    }
  }

  // Hata mesajı gösterme
  void _showErrorMessage(String message) {
    print(message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Sonuç sayfasına yönlendirme
  void _navigateToResultPage(File image, Map<String, dynamic> apiResult) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultPage(
          selectedImage: image,
          apiResult: apiResult,
        ),
      ),
    );
  }

  // Kamera işlevi
  Future<void> _pickImageFromCamera() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      await _sendImageToApi(File(pickedFile.path));
    }
  }

  // Galeri işlevi
  Future<void> _pickImageFromGallery() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      await _sendImageToApi(File(pickedFile.path));
    }
  }

  // Geçmişi göster/gizle
  void _toggleHistoryVisibility() {
    setState(() {
      _isHistoryVisible = !_isHistoryVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade300, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: <Widget>[
                SizedBox(height: 240),
                Text(
                  'Hayvanları Tanıyın ve Keşfedin!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _buildImagePickerButton(Icons.camera_alt, _pickImageFromCamera),
                    SizedBox(width: 50),
                    _buildImagePickerButton(Icons.photo_library, _pickImageFromGallery),
                  ],
                ),
                SizedBox(height: 80),
                if (_isHistoryVisible)
                  Expanded(
                    child: ListView.builder(
                      itemCount: _recognizedAnimals.length,
                      itemBuilder: (context, index) {
                        final animal = _recognizedAnimals[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          color: Colors.white.withOpacity(0.8),
                          child: ListTile(
                            leading: Image.network(animal['ImageURL'] ?? ''),
                            title: Text(animal['AnimalName'] ?? 'Bilinmiyor'),
                            subtitle: Text(
                              "Yaşadığı alan: ${animal['Habitat']} \nBeslenme şekli: ${animal['Nutrition']}",
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 75,
            right: 20,
            child: TextButton(
              onPressed: _toggleHistoryVisibility,
              child: Text(
                _isHistoryVisible ? 'Geçmişi Gizle' : 'Geçmişi Göster',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }


  // Image picker button widget
  Widget _buildImagePickerButton(IconData icon, Function onTap) {
    return GestureDetector(
      onTap: () => onTap(),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        height: 100,
        width: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 50,
          color: Colors.green,
        ),
      ),
    );
  }
}
