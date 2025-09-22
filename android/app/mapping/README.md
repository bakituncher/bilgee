# ProGuard Mapping Dosyaları

Bu klasör, release build'ler için oluşturulan ProGuard/R8 mapping dosyalarını saklar.

## Mapping Dosyaları Nedir?

Mapping dosyaları, obfuscation işlemi sırasında değişen sınıf, method ve field isimlerinin orijinal hallerini tutar. Bu dosyalar:

- Crash raporlarındaki obfuscated stack trace'leri çözmek için kullanılır
- Google Play Console'a yüklenir
- Her release build için farklı bir mapping dosyası oluşturulur

## Dosya Adlandırma

Mapping dosyaları şu formatta adlandırılır:
- `mapping-{versionName}-{versionCode}.txt`
- Örnek: `mapping-1.0.0-1.txt`

## Kullanım

1. Release build yaptıktan sonra mapping dosyası otomatik olarak bu klasöre kopyalanır
2. Google Play Console'da crash raporu çözümlemesi için bu dosyayı yükleyin
3. Crash analizi araçlarında bu dosyayı kullanın

## Önemli Notlar

- Bu dosyaları saklamayı ihmal etmeyin
- Her release için farklı mapping dosyası olduğundan, version bilgisini doğru tutun
- Bu dosyaları güvenli bir yerde yedekleyin
