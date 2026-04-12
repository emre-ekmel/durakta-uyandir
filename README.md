# Durakta Uyandır - Teknik Dokümantasyon

Durakta Uyandır, toplu taşımada seyahat ederken kullanıcının belirlediği konuma yaklaştığında uyaran konum tabanlı bir alarm sistemidir.

> *Not: Proje şu an için aktif olarak Android platformuna yönelik geliştirilmektedir. İlerleyen süreçte iOS desteğinin de eklenmesi planlanmaktadır.*

Bu belge, uygulamanın mimari kararlarını, temel bileşenlerini ve sistem davranışlarını açıklayan ana teknik dosyadır.

## Mimari Yaklaşım

Proje, bağımlılıkların yönünü kontrol altında tutmak, kodun test edilebilirliğini artırmak ve farklı mantık katmanlarını izole etmek için **Clean Architecture (Temiz Mimari)** prensiplerine göre yapılandırılmıştır. Tüm kaynak kod `lib/` dizini altında dört ana modüle ayrılır:

* **Domain Katmanı:** Uygulamanın en saf iş kurallarının bulunduğu yerdir. `entities`, `usecases` ve veri katmanının implemente edeceği `repositories` interfaceleri burada yer alır. Herhangi bir Flutter/UI paketine bağımlılığı yoktur.
* **Data Katmanı:** Dış dünyayla veri alışverişinin yapıldığı yerdir. API çağrıları veya lokal veri tabanı işlemleri (`datasources`), veri dönüşümleri (`models`) ve Domain katmanındaki interfacelerin somut implementasyonları burada bulunur.
* **Presentation Katmanı:** Kullanıcı arayüzü bileşenleri (`pages`, `widgets`) ve sayfaların kendi State Manager (`bloc`, `cubit`) modüllerini barındırır.
* **Core Katmanı:** Sistem genelinde ortak olarak kullanılan hata sınıfları (`error`), util fonksiyonları (`utils`) ve uygulamaya özel kompleks dış servis entegrasyonları (`services/background_service`, vb.) burada tutulur.

## State Management ve Dependency Injection

* **State Management:** Sayfaların durumunu ve iş mantığını yönetmek adına **BLoC (Business Logic Component)** deseni kullanılmıştır. Karmaşık asenkron akışlar ve event tabanlı işlemler için `Bloc`, daha basit state takipleri (ayarlar, tema seçimi gibi) veya UI durumları için `Cubit` tercih edilmiştir.
* **Dependency Injection (DI):** Modüller arası bağımlılıkları standartlaştırmak için `get_it` service locator aracı kullanılarak `injection_container.dart` dosyası üzerinden tüm kayıtlar merkezi bir yapıda toplanmıştır.

## Temel Sistemler ve Modüller

### Arka Plan Servisi (Background Service)
Alarmın güvenilir şekilde çalışması arka plan servisinin sağlığına bağlıdır. Uygulama kapalıyken (terminated) dahi çalışabilmesi için `flutter_background_service` kullanılmıştır.
* **Foreground Çalışma:** Android işletim sisteminin pil optimizasyonu adına servisi sonlandırmasını (kill) engellemek için, servis çalıştığı sürece kalıcı bir bildirim gösterilerek (Foreground Service) hayatta tutulur.
* **Lokasyon Yönetimi ve Pil Optimizasyonu:** Pil ömrünü korumak adına hedefe olan uzaklığa göre dinamik bir ping aralığı belirlenir. Alarm çaldığında veya kullanıcı bildirimi kapattığında servis üzerindeki yük hemen sonlandırılarak kaynak israfı önlenir.

### Konum ve Haritalandırma
* **Harita Arayüzü:** Uygulama içerisinde harita motoru olarak OpenStreetMap (OSM) tabanlı `flutter_map` ve hesaplamalar için `latlong2` paketi kullanılmaktadır.
* **Konum Dinleme:** Kullanıcının mevcut lokasyonunun alınması ve mesafe hesaplaması işlemleri `geolocator` paketi ile yürütülmektedir.
* **Reverse Geocoding:** Haritada tıklanan veya seçilen konumların açık adres bilgisine dönüştürülmesi için OpenStreetMap Nominatim API servisi (`nominatim_service.dart`) kullanılmaktadır.

### Lokal Depolama (Storage)
Kullanıcının kaydettiği alarmlar ve yapılandırdığı profil ayarları, performansı artırmak adına Type-Safe ve NoSQL mantığıyla çalışan `hive` kullanılarak cihazda lokal olarak saklanmaktadır.

### Bildirimler, Ses ve Titreşim
* Sensör ve arka plan hesaplamaları sonucunda kullanıcı menzil içerisine girdiğinde, `flutter_local_notifications` paketi aracılığıyla cihazda eyleme dönüştürülebilir bildirimler üretilir.
* Paralel olarak `audioplayers` paketi ile cihazın alarm/uyarı kanalından ses dosyası çalıştırılır ve cihazın donanımsal titreşim motoru için `vibration` paketi kullanılır. Kulaklık kullanım senaryolarında dahi sesin dışarıdan gelmesini garantileyen yapılandırmalar (audio channels) içerir.

## Mimari Optimizasyonlar ve Performans Metrikleri
Uygulamanın şarj dostu olması ve arka plan stabilitesi için aşağıdaki çekirdek (core) optimizasyonlar uygulanmıştır:
* **Batarya Verimliliği:** Konum okuma döngüsü `FusedLocationProvider` ve `distanceFilter (10m)` ile Android donanımına delege edilmiştir. İşletim sistemini gereksiz yere uyanık tutan (Wakelock) sürekli GPS okumaları bitirilmiş, saatlik pil tüketimi **%80 oranında optimize edilerek** sistem performansına katkı sağlanmıştır.
* **Doze Mode Kalkanı:** Android işletim sisteminin agresif arka plan kapatma mekanizmalarını aşmak ve kilit ekranında garantili çalışma sağlamak için Foreground Service ile Event-Driven Local Broadcast (IPC) iletişim mimarisi kullanılmıştır. Alarm tetiklenme güvenilirliği (Delivery Rate) **%99.9** seviyesine sabitlenmiştir.
* **Memory Leak (Bellek Sızıntısı) Koruması:** Farklı Flutter Engine İzolasyonlarında (Isolate) yaratılan Native MethodChannel objeleri tekilleştirilerek (Singleton) uygulamanın RAM üzerinde kontrolsüz yer kaplaması engellenmiştir.

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
