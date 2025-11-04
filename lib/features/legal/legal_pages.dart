import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const _DocPage(title: 'Kullanım Koşulları', content: _terms);
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const _DocPage(title: 'Gizlilik Politikası', content: _privacy);
  }
}

class _DocPage extends StatelessWidget {
  final String title; final String content;
  const _DocPage({required this.title, required this.content});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(content),
      ),
    );
  }
}

const _terms = 'MystiQ, eğlence amaçlıdır ve sağlık/finansal tavsiye içermez. Uygulamayı kullanarak yerel yasalara uymayı kabul edersiniz. Premium ve coin ürünleri dijital içerik olup iade koşulları mağaza politikalarına tabidir.';
const _privacy = 'MystiQ, deneyimi iyileştirmek için sınırlı analitik verileri ve isteğe bağlı bildirim izinlerini kullanır. Kişisel verileriniz üçüncü taraflarla izniniz olmadan paylaşılmaz. Daha fazla bilgi için destek ile iletişime geçin.';

