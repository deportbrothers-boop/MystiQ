import 'package:flutter/material.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bilgilendirme')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Uygulama kahve kupasındaki şekillerin sembolik yorumunu sunar.'),
            SizedBox(height: 8),
            Text('• Gelecek tahmini yapılmaz.'),
            SizedBox(height: 8),
            Text('• Kesinlik veya garanti içermez.'),
            SizedBox(height: 8),
            Text('• Eğlence amaçlıdır.'),
          ],
        ),
      ),
    );
  }
}
