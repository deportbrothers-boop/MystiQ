Klasör yapısı (Flutter çözünürlük varyantları)

- 1.0x anahtar dosyalar (zorunlu):
  assets/images/tarot/fronts/0.png … 23.png

- 3.0x varyant dosyalar (önerilen):
  assets/images/tarot/fronts/3.0x/0.png … 23.png

Boyut önerisi (9:14 oran)
- 1.0x: 125 × 194 px
- 3.0x: 375 × 582 px (kritik)

Not: Flutter, 3.0x dosyasını kullanabilmek için ana (1.0x) dosyanın da mevcut olmasını ister.
Geçici çözüm olarak 3.0x dosyalarını 1.0x’e kopyalayabilirsiniz.

İsim/indeks eşleşmesi
- Uygulama şu anda 0..23 arası indeks kullanır.
- Tarot sonuç ekranındaki flip animasyonu ön yüzü buradan okur.

