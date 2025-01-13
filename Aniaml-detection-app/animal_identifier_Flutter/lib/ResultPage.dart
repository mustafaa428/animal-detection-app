import 'dart:io';
import 'package:flutter/material.dart';

class ResultPage extends StatelessWidget {
  final File selectedImage;
  final Map<String, dynamic> apiResult; // API sonucundan gelen veri

  ResultPage({required this.selectedImage, required this.apiResult});

  @override
  Widget build(BuildContext context) {
    // Ekran boyutlarını alıyoruz
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // API sonucunu konsola yazdırarak kontrol ediyoruz
    print("API Result: $apiResult");

    // API sonucundan hayvan bilgilerini alıyoruz
    final String animalName = apiResult['data']?['Name']?.toString() ?? 'Bilinmiyor';
    final String nutrition = apiResult['data']?['Nutrition']?.toString() ?? 'Bilinmiyor';
    final String habitat = apiResult['data']?['Habitat']?.toString() ?? 'Bilinmiyor';
    final String reproduction = apiResult['data']?['Reproduction']?.toString() ?? 'Bilinmiyor';


    print(animalName);

    return Scaffold(
      body: Stack(
        children: [
          // Fotoğrafın ekran boyutuna tam olarak uyarlanması
          Positioned.fill(
            child: SizedBox(
              width: screenWidth,
              height: screenHeight,
              child: Image.file(
                selectedImage, // Seçilen görüntü buraya aktarılır
                fit: BoxFit.cover, // Fotoğraf ekranı dolduracak şekilde genişletilir
              ),
            ),
          ),
          // Üstteki bilgi kutusu
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 50),
              padding: const EdgeInsets.all(16),
              color: Colors.black.withOpacity(0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$animalName", // Hayvan ismini API sonucundan çekiyoruz
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Beslenme Şekli: $nutrition\n'
                        'Nerede Yaşar: $habitat\n'
                        'Üreme Şekli: $reproduction',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          // Sol üst köşede geri dönme butonu
          Positioned(
            top: 40, // Durum çubuğunun altında görünsün diye konum
            left: 16, // Sol tarafa biraz boşluk bırakıyoruz
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_outlined, // Geri dönüş ikonu
                color: Colors.white,
                size: 30,
              ),
              onPressed: () {
                Navigator.pop(context); // Önceki sayfaya döner
              },
            ),
          ),
        ],
      ),
    );
  }
}
