# Notepad# tasarımı

Tarih: 2026-10-22

## Amaç ve neden

Murat günlük hızlı notlar için çok basit, sekmeli bir düz metin editörü istiyor. Örnek: Windows'taki Notepad.
TextEdit'in sorunu: yeni sekme açıp kapatınca "kaydet mi, sil mi" diye soruyor. Hızlı not alırken dosya adı, konum, kaydetme düşünmek istemiyor.
Başarı: aç, yaz, kapat. Not kaybolmaz, gereksiz soru gelmez.

## Hedefler

1. Tek pencere, üstte hep görünen sekme çubuğu (Windows Notepad gibi), sonunda "+" butonu, her sekmede kapatma (x) butonu.
2. Yeni sekme otomatik olarak bir temp dosyaya bağlanır ve yazdıkça kendiliğinden kaydedilir.
3. Temp dosyalar Finder'dan görülebilen bir klasörde durur: `~/Documents/Notepad#/`.
4. Sekme kapatma kuralları:
   1. Boş temp sekme: soru sorulmaz, temp dosyası silinir, sekme kapanır.
   2. Dolu temp sekme: "Kaydet / Sil / Vazgeç" sorulur. Kaydet: konum seçme penceresi açılır, kaydedilince temp dosya silinir, sekme kapanır. Sil: temp dosya silinir, sekme kapanır. Vazgeç: hiçbir şey olmaz.
   3. Değişikliği olan dosya sekmesi: "Kaydet / Kaydetme / Vazgeç" sorulur.
   4. Değişikliği olmayan dosya sekmesi: soru sorulmaz, kapanır.
   5. Son sekme kapatılınca pencere kapanmaz, yerine boş yeni bir sekme açılır.
5. Uygulamadan çıkışta (Cmd+Q, kapatma) hiçbir şey sorulmaz. Temp notlar kaydedilir, sonraki açılışta aynı sekmeler aynı sırayla geri gelir.
6. Save As yapılan sekme artık o dosyaya bağlıdır; geri açılışta o konumdan açılır, temp dosyası silinir.
7. Dosya sekmeleri (Save As yapılmış ya da Cmd+O ile açılmış) Windows Notepad gibi çalışır, otomatik kaydedilmez:
   1. Düzenlenince sekmede "değişti" işareti çıkar, dosyaya yalnız Cmd+S ile yazılır.
   2. Çıkışta değişiklikler dosyaya yazılmaz, kenarda (uygulamanın kendi gizli klasöründe) saklanır. Açılışta sekme aynı değişikliklerle ve "değişti" işaretiyle geri gelir (Windows 11 Notepad gibi).
8. Sadece düz metin (plain text).
9. Font ve boyut Ayarlar penceresinden (Cmd+,) seçilir, tüm sekmelere uygulanır. Cmd + / Cmd - ile anlık büyütme küçültme.
10. Sekme adı: temp notta ilk satır (boşsa "Adsız 1", "Adsız 2"...), kayıtlı dosyada dosya adı.
11. UTF-8, satır kaydırma açık, Cmd+F ile arama, Cmd+O ile dosya açma.
12. Hafif ve hızlı açılır.

## Benim kararlarım (Claude, Murat'ın kontrolüne açık)

1. Temp sekmede Cmd+S, Save As penceresini açar.
2. Dolu temp notta "Sil" ve Save As sonrası temp dosyanın silinmesi: dosya Çöp Sepeti'ne taşınır, kalıcı silinmez. Boş temp dosya kalıcı silinir.
3. Çökmeye karşı: oturum bilgisi her sekme değişiminde güvenli (atomik) yazılır. Açılışta temp klasöründe olup sekme listesinde olmayan, uygulamanın ad biçimine uyan temp dosyalar sekme olarak geri açılır.
4. Açılışta dosya sekmesinin dosyası bulunamazsa: kenarda değişiklik varsa sekme o metinle "değişti" olarak açılır, Cmd+S konum sorar; değişiklik yoksa sekme açılmaz.
5. Açık bir dosya başka bir uygulamada değişirse: sekmede değişiklik yoksa sessizce yeniden yüklenir; varsa bizimki korunur, Cmd+S üstüne yazar.
6. UTF-8 olmayan bir dosya açılmak istenirse açılmaz, kısa bir uyarı gösterilir.

## Hedef dışı (şimdilik)

1. Zengin metin, biçimlendirme, syntax renklendirme.
2. Birden çok pencere, sekmeyi sürükleyip ayrı pencere yapma.
3. Bulut, senkron, iCloud.
4. Encoding seçimi, yazdırma.
5. Finder'da çift tıkla / "Birlikte Aç" ile dosya açma.
6. App Store, notarization, dağıtım. Uygulama Murat'ın kendi Mac'inde kullanılır.

## Kesinlikle olmaması gerekenler

1. Bir notun kaybolması (çökme, çıkış, yeniden açılış dahil).
2. Çıkışta ya da boş sekme kapanışında soru sorulması.
3. Electron gibi ağır bir yapı.

## Kısıtlar

1. Sadece macOS.
2. Swift, yerel uygulama. Yazı alanı AppKit `NSTextView`. Electron yok.
3. Build, test ve paketleme lokalde. CI yok.
4. Uygulama adı şimdilik "Notepad#". Ad tek bir sabitte durur, sonradan değişebilir; ad değişince `~/Documents/<eski ad>/` klasörü yeni ada taşınır.

## Builder'a bırakılanlar

1. Proje yapısı: Murat'ın diğer Swift projesi (Bakis) gibi SwiftPM, mantık için ayrı bir Core hedefi (test edilebilir), `scripts/build-app.sh` ile `.app` paketleme ve ad-hoc imza.
2. Sekme çubuğunun AppKit mi SwiftUI mi yazılacağı.
3. Otomatik kaydetme zamanlaması (ör. yazmayı bıraktıktan kısa süre sonra ve çıkışta).
4. Oturum bilgisinin (sekme listesi, sıra, aktif sekme, pencere boyutu) nerede ve hangi formatta tutulacağı.
5. Temp dosya adının biçimi (benzersiz olmalı).
