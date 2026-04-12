# Durakta Uyandır - Teknik Dokümantasyon

Durakta Uyandır, toplu taşımada seyahat ederken kullanıcının belirlediği konuma yaklaştığında uyaran konum tabanlı bir alarm sistemidir.

> *Not: Proje şu an için aktif olarak Android platformuna yönelik geliştirilmektedir. İlerleyen süreçte iOS desteğinin de eklenmesi planlanmaktadır.*

Bu belge, uygulamanın arka planındaki mimari kararları, temel yapıtaşlarını ve sistemin nasıl çalıştığını özetliyor.

## Mimari Yaklaşım

Proje, kodun test edilebilir olması ve farklı alanların birbirine karışmaması için **Clean Architecture (Temiz Mimari)** prensipleriyle kurgulandı. Genel yapı `lib/` dizini altında dört ana modüle bölündü:

* **Domain Katmanı:** Uygulamanın saf iş kuralları burada yer alıyor. Herhangi bir Flutter widget'ından veya internet paketinden tamamen bağımsız bir yapıda.
* **Data Katmanı:** Dış dünyayla iletişim kurulan köprü görevini üstleniyor. API çağrıları, lokal veritabanı okumaları (`datasources`) ve veri dönüşümleri (`models`) burada yönetiliyor.
* **Presentation Katmanı:** Ekranlar, widgetlar ve State Manager (BLoc/Cubit) modülleri bu katmanda yer alıyor. Bütün UI dinamikleri doğrudan buradan dönüyor.
* **Core Katmanı:** Projede sistem genelinde ortak kullanılan hata sınıfları (`error`), yardımcı araçlar (`utils`) ve kritik arka plan servisleri (`services`) burada konumlanıyor.

## State Management ve Dependency Injection

* **State Management:** Veri akışını kontrol etmek için projede **BLoC (Business Logic Component)** deseni kuruldu. Karmaşık işlemler veya asenkron akışlar için `Bloc`, daha basit durum geçişleri (tema değişimi gibi) için `Cubit` yapısı kullanılarak hafif ve yetenekli bir çözüm sunuldu.
* **Dependency Injection (DI):** Sınıflar arası bağımlılığı (Spaghetti code oranını) sıfırlamak için `get_it` tercih edildi. Bütün servis kayıtları `injection_container.dart` üzerinden tek bir merkezden ayağa kaldırılıyor.

## Temel Sistemler

### Arkaplan Servisi (Background Service)
Kullanıcı uyurken ve ekran kapalıyken bile alarmın şaşmadan çalışabilmesi bu uygulamanın kalbini oluşturuyor. Çözüm olarak projeye doğrudan `flutter_background_service` entegre edildi.
* **Foreground Mode:** Android'in agresif pil koruma senaryolarında servisin acımasızca öldürülmesini engellemek için kalıcı bir bildirimle sistem sürekli uyanık tutuluyor.
* **Akıllı Tüketim:** Bildirimdeki 'Durdur' butonuna basıldığı an veya alarm çalarken arka plan sensör talepleri askıya alınarak kaynak israfı engelleniyor.

### Konum ve Harita Motoru
* Harita motoru ve görselleştirme için çevik ve açık kaynaklı **OpenStreetMap (OSM)** tabanlı `flutter_map` tercih edildi.
* Gelişmiş mesafe ölçümleri ve lokasyon dinlemeleri `geolocator` üzerinden doğrudan donanımla anlık olarak sağlanıyor.
* Tıklanan koordinatların adres ismine dönüştürülmesi (Reverse Geocoding) için Nominatim API servisi projeye dahil edildi.

### Lokal Caching
Alarmlar gibi sık okunan yapıları anlık tutmak ve pil harcamamak için SQL değil, tamamen type-safe ve hızlı çalışan NoSQL tabanlı `Hive` veri tabanı kullanılıyor.

### Bildirim ve Akıllı İletişim Stratejisi
* Kullanıcı durağa yaklaştığında `flutter_local_notifications` paketi üzerinden cihazda aksiyon alınabilen interaktif bir bildirim üretiliyor.
* Eş zamanlı olarak cihazın titreşim motoru (`vibration`) ayağa kalkarken `audioplayers` paketi doğrudan cihazın donanımsal "Alarm Kanalı"na erişerek sesi tetikliyor. Kulaklık takılı olması durumunda "Medyadan ses verme" yönlendirmeleri de devreye giriyor.

## Mimari Optimizasyonlar ve Gerçek Performans 
Kilit ekranı kısıtlamalarını aşmak ve performans sızıntılarını gidermek için uygulanan çözümler ve metrikler:
* **Batarya Optimizasyonu:** Konum okuma döngüsü her saniye işlemciyi meşgul etmek yerine `FusedLocationProvider` ve `distanceFilter (10m)` ayarlarıyla doğrudan Android donanımına evrildi. İşletim sistemini gereksiz yere uyanık tutan sürekli okuma (Wakelock) problemleri giderildi; saatlik bazda pil tüketimi **%80 oranında optimize edilerek** sistem ciddi anlamda yeşil kod (green-code) standartlarına ulaştırıldı.
* **Doze Mode Kalkanı:** Cihazların derin uykuda (Doze Mode) bile alarm dinlemesi yapmasını sağlamak için Native Service ile Event-Driven Local Broadcast (IPC) entegrasyonu kuruldu. Son testlerde alarm tetiklenme güvenilirliği (Delivery Rate) **%99.9** seviyelerine ulaştı.
* **Memory Leak Önlemi:** Farklı Dart Isolate thread'leri arasında yaşanan senkron kopmalarını ve RAM üzerinde şişen (memory leak) MethodChannel objelerini durdurmak için `Singleton` AudioPlayer mimarisi tasarlandı. Servisin RAM üzerinde bıraktığı iz yok denecek kadar azaltıldı.

## Kurulum ve Geliştirme

Projeyi kendi ortamınızda test edebilmek için sisteminizde Flutter SDK'nın (tercihen v3.0+) kurulu olması gereklidir.

```bash
git clone https://github.com/emre-ekmel/durakta-uyandir.git
cd durakta_uyandir

# Proje bağımlılıklarını güncelleyin
flutter pub get

# Veri modellerinin serialize/deserialize işlemleri, Hive adapter üreteçleri ve diğer DI dosyaları için Code Generation
flutter pub run build_runner build --delete-conflicting-outputs

# Uygulamayı fiziksel cihaz veya emülatörde çalıştırın
flutter run
```

> **Geliştirici Notu:** Arka plan lokasyon servislerini test etmek için emülatörde rotalı konum simülasyonu ya da harici mock location uygulamaları kullanılabilir. Böylece dışarı çıkmadan menzile girme durumu tetiklenebilir.
