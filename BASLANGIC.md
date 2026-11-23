# Unity AI Studio: Sıfırdan Kurulum ve Kullanım

Bu rehber **Windows** ve **macOS** içindir ve hiç deneyimi olmayan birine göre
yazıldı. İki sistemde farklı olan adımlar ayrı ayrı yazıldı; gerisi aynıdır.
Kurulum yaklaşık 20–30 dakika sürer ve büyük kısmı beklemedir.

---

## Gerekenler

| Gereken | Nereden |
|---|---|
| Windows 10/11 ya da macOS | — |
| **Ücretli bir Claude hesabı** (Pro, Max veya Team) | [claude.ai](https://claude.ai) |
| **Unity Hub** ve en az bir **Unity 6** sürümü | [unity.com/download](https://unity.com/download). Hub üzerinden **6.3 LTS** kurulması önerilir |
| İnternet bağlantısı | — |

Git, Claude Code ve Unity CLI'ı önceden kurmana gerek yok; kurulum script'i
bunları kendisi kuruyor.

---

## Bölüm 1: Bilgisayarı hazırlamak (her bilgisayarda bir kez)

**1. Terminali aç.**

- **Windows:** Başlat menüsüne `PowerShell` yaz ve **Windows PowerShell**'e
  tıkla. Mavi ya da siyah bir pencere açılır.
- **macOS:** `Cmd + Boşluk` ile Spotlight'ı aç, `Terminal` yaz ve Enter'a bas.

Bu rehberde bundan sonra "terminal" dendiğinde bu pencere kastediliyor.

**2. Sistemine uygun satırı kopyala, terminale yapıştır ve Enter'a bas.**
Windows'ta sağ tık, macOS'ta `Cmd + V` yapıştırır.

Windows:

```powershell
irm https://raw.githubusercontent.com/sefamehmetyildiz/unity-ai-studio/main/setup-machine.ps1 | iex
```

macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/sefamehmetyildiz/unity-ai-studio/main/setup-machine.sh | bash
```

**3. Bitmesini bekle.** Script her adım için bir satır yazar:

- `[OK]` o adımın hazır olduğunu gösterir.
- `[DO]` bir şeyin kurulduğunu gösterir.
- **Windows:** Git kurulurken Windows izin isteyebilir, **Evet** de.
- **macOS:** Git yüklü değilse "Command Line Tools" kurulum penceresi açılır.
  **Yükle**'ye bas, kurulum bitince 2. adımdaki satırı bir kez daha çalıştır.
- En sonda yeşil renkte **"Machine ready."** yazısını görmelisin.

**4. Terminal penceresini kapat, yenisini aç.** Bu adım şart. Yeni kurulan
komutlar ancak yeni açılan pencerede tanınır.

**5. Claude'a bir kez giriş yap.** Yeni pencerede şunu yaz:

```
claude
```

Tarayıcı açılır, Claude hesabınla giriş yaparsın. Giriş bitince pencereye dönüp
`/exit` yazarak çık.

---

## Bölüm 2: Unity projesine kurmak (her projede bir kez)

**6. Unity projesini oluştur ya da aç.** Unity Hub'da **New project** seçip bir
şablon seç (2D veya 3D, URP olanlar önerilir). Projeye bir isim ver ve **klasör
yolunu not et**: Windows'ta örneğin `C:\Oyunlar\IlkOyunum`, macOS'ta
`~/Oyunlar/IlkOyunum`. Proje Unity'de açılsın ve **açık kalsın**.

**7. Terminalde proje klasörüne gir ve Claude'u başlat.**

Windows:

```powershell
cd "C:\Oyunlar\IlkOyunum"
```

macOS:

```bash
cd ~/Oyunlar/IlkOyunum
```

Sonra her iki sistemde:

```
claude
```

İlk seferde iki soru gelebilir:

- "Bu klasöre güveniyor musun?" sorusuna **Evet** de.
- Plugin kurmayı önerirse onu da kabul et.

**8. Kiti projeye kur.** Claude'a şunu yaz:

```
/studio:add
```

Claude önce ne değişeceğini özetler ve onay ister. **"evet"** yazman yeterli.
Projene yaklaşık 650 dosya eklenir. Bunlar Claude'un çalışma kuralları ve ekip
agent'larıdır; oyun dosyalarına dokunmaz.

**9. Unity penceresine bir kez tıkla.** Unity yeni bir paket indirir
(`com.unity.pipeline`); sağ altta ilerleme çubuğu görünür. Bitmesini bekle. Bu
paket Claude'un Unity'yi kontrol edebilmesini sağlar.

**10. Claude'u yeniden başlat.** Önce `/exit` yaz, sonra tekrar `claude` yaz.
Yeni kurulan agent'lar ve kurallar ancak yeni oturumda yüklenir.

**11. Motoru tanıt:**

```
/setup-engine unity
```

Claude birkaç soru sorar (Unity sürümü, dil vb.). Cevapla ya da önerilen
seçeneği kabul et.

**12. Her şeyin hazır olduğunu kontrol et:**

```
/studio:doctor
```

Bir tablo çıkar:

- **OK** olanlar hazırdır.
- **WARN** ve **MISSING** satırlarının yanında ne yapman gerektiği yazar.
- **FAIL** satırı yoksa kurulum tamamdır.

---

## Bölüm 3: Günlük kullanım

Her çalışma oturumunda şunları yap:

1. Unity'de projeni aç.
2. Terminalde proje klasörüne gir (`cd ...`) ve `claude` yaz.
3. Claude'la **Türkçe, normal bir dille** konuş.

**İlk oyununa başlamak için iki yol var:**

| Yaz | Ne olur |
|---|---|
| `/start` | Rehberli başlangıç. Ne yapmak istediğini sorar ve seni doğru yola sokar. Yeni başlayanlar için en iyisi. |
| `bana zıplayan bir top ile engellerden kaçılan bir oyun yap` | Doğrudan hızlı bir prototip yapar, oynar ve ekran görüntüsü alır. |

**Sonrasında işine yarayacak komutlar:**

| Yaz | Ne zaman |
|---|---|
| `/next-step` | "Şimdi ne yapmalıyım?" dediğinde |
| `/studio:doctor` | Bir şey çalışmıyor gibi göründüğünde |
| `/design-system` | Oyunun bir sistemini (savaş, envanter vb.) tasarlarken |
| `/sprint-plan` | Yapılacak işleri planlarken |
| `/studio:update` | Kit'in yeni sürümü çıktığında |

Komut ezberlemen gerekmiyor. "Karakter neden zıplamıyor?" ya da "menü ekranı
ekle" gibi normal cümleler de çalışır.

---

## Bilinmesi gerekenler

- **Unity açık olmalı.** Claude Unity'ye ancak Editor açıkken bağlanabilir:
  sahne kurmak, oyunu çalıştırmak, ekran görüntüsü almak gibi işler için.
- **Claude yazmadan önce sorar.** Bir dosyayı değiştirmeden önce izin ister.
  Okuyup onaylaman yeterli.
- **Kırmızı hata varsa önce onu düzelt.** Unity konsolunda derleme hatası varsa
  Claude'un Unity bağlantısı kopar. Claude'a "konsoldaki hataları düzelt" demen
  yeterli.
- **Kaydetme işi senin.** Claude kendi başına commit yapmaz. İşini GitHub'a
  göndermek istediğinde ya ona söylersin ya da GitHub Desktop'tan kendin
  yaparsın.

---

## Sorun çıkarsa

| Sorun | Çözüm |
|---|---|
| `claude` yazınca "tanınmıyor" ya da "command not found" hatası | Terminali kapatıp yeniden aç. Hata sürerse 1. bölümdeki kurulum satırını tekrar çalıştır; kurulu olanları atlar. |
| Doctor "No connected Editor" diyor | Projeyi Unity'de aç ve Unity penceresine bir kez tıkla. |
| `/studio:add` komutu bulunamıyor | Kurulum satırını tekrar çalıştır, sonra Claude'u yeniden başlat. |
| Windows: "Script çalıştırılamıyor" hatası | Kurulum komutunu Windows PowerShell'de çalıştırdığından emin ol. Komut İstemi'nde (cmd) çalışmaz. |
| macOS: kurulum "Command Line Tools" penceresinde kaldı | Penceredeki kurulumu bitir, sonra kurulum satırını tekrar çalıştır. |
| Herhangi bir şey | Claude'a sorunu olduğu gibi yaz ya da `/studio:doctor` çalıştır. |

---

**Kısa özet:** Bilgisayara bir kez tek satır yapıştırılır. Her yeni projede
sırasıyla `/studio:add`, Claude'u yeniden başlatma, `/setup-engine unity` ve
`/studio:doctor` yapılır. Sonrasında `/start` ile oyun yapmaya başlanır.
