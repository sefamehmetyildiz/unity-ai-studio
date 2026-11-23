# Unity AI Studio

Herhangi bir Unity projesine tek komutla kurulan, **Claude Code** için hazır oyun
geliştirme ortamı. Tek bir kişinin sıfırdan istediği oyunu yapabilmesi için üç
katmanı birlikte çalışacak şekilde bağlar:

| Katman | Ne yapar |
|---|---|
| **Claude Code Game Studios** (49 agent, 78 skill) | Süreç: fikir → brief → tasarım (GDD) → mimari → epic/story → sprint → QA → yayın |
| **gamedev** plugin'i | Bilgi: tür tasarımı, game feel, AI, kayıt, ses, kamera, performans |
| **Unity resmi** plugin + Unity CLI + MCP | Unity'ye özel işler ve açık Editor'ü canlı yönetme: derleme, Play Mode, ekran görüntüsü, sahne/prefab |

Kit bunların üstüne şunları ekler: hangi işin hangi skill'e gideceğini belirleyen
yönlendirme kuralları, Unity agent'larına önceden yüklenen skill'ler ve
`/studio:add`, `/studio:doctor`, `/studio:update` komutları.

> **İlk kez mi kuruyorsun?** Adım adım, hiç bilmeyen biri için yazılmış rehber:
> **[BASLANGIC.md](BASLANGIC.md)**

---

## 1. Bilgisayar kurulumu (her bilgisayarda bir kez)

Gerekenler: **Windows 10/11 veya macOS**, Unity Hub ve en az bir Unity 6
sürümü, bir Claude hesabı (Pro/Max/Team).

### Windows

PowerShell'i aç ve şunu yapıştır:

```powershell
irm https://raw.githubusercontent.com/sefamehmetyildiz/unity-ai-studio/main/setup-machine.ps1 | iex
```

### macOS

Terminal'i aç ve şunu yapıştır:

```bash
curl -fsSL https://raw.githubusercontent.com/sefamehmetyildiz/unity-ai-studio/main/setup-machine.sh | bash
```

Git yüklü değilse macOS bir "Command Line Tools" kurulum penceresi açar. Kurulum
bitince aynı komutu bir kez daha çalıştır.

### Script'i önce okumak istersen (önerilir)

Repoyu klonlayıp yerelden de çalıştırabilirsin:

```bash
git clone https://github.com/sefamehmetyildiz/unity-ai-studio.git ~/unity-ai-studio
```

Windows'ta:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\unity-ai-studio\setup-machine.ps1"
```

macOS'ta:

```bash
bash ~/unity-ai-studio/setup-machine.sh
```

Script kurulu olanları atlar, eksikleri kurar:

1. Git (Windows'ta Git Bash, macOS'ta Command Line Tools; Game Studios hook'ları için)
2. Claude Code CLI (PATH'e ekler)
3. Unity CLI
4. `gamedev` plugin'i
5. `unity` plugin'i ve Unity CLI skill'leri
6. `unity-editor-mcp` sunucusu
7. Bu kit'in `studio` plugin'i

Ne yapacağını önceden görmek için sonuna Windows'ta `-DryRun`, macOS'ta
`--dry-run` ekleyebilirsin. Bittiğinde **yeni bir terminal aç** ve ilk kez
`claude` yazarak giriş yap.

## 2. Bir Unity projesine ekleme (her projede bir kez)

Claude Code'u projenin klasöründe başlat ve şunu yaz:

```
/studio:add
```

Önce ne değişeceğini gösterir, onay ister, sonra kurar. Repoyu klonladıysan
Claude kullanmadan da yapılabilir:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\unity-ai-studio\scripts\add-to-project.ps1" -ProjectPath "C:\Oyunlar\YeniOyun"
```

```bash
bash ~/unity-ai-studio/scripts/add-to-project.sh --project-path ~/Oyunlar/YeniOyun
```

Ardından:

1. Projeyi Unity'de bir kez aç. `com.unity.pipeline` paketi bu sırada iner.
2. Claude Code'u proje klasöründe **yeniden başlat**.
3. `/setup-engine unity` komutunu çalıştır. Game Studios motoru ve sürümü bu
   adımda öğrenir.
4. `/studio:doctor` ile her şeyin hazır olduğunu kontrol et.
5. Başla: `/start` (rehberli) ya da doğrudan `"bana ... gibi bir oyun yap"`.

**Takım projesi:** Kit bir kez commit edildiyse ekip arkadaşların sadece repoyu
klonlar ve 1. adımı yapar. Projeyi Claude Code'da açtıklarında eksik plugin'ler
için kurulum önerisi otomatik gelir.

## 3. Komutlar

| Komut | İş |
|---|---|
| `/studio:doctor` | Bilgisayarı, projeyi ve açık Editor'ü kontrol eder. Her eksik için çözümü söyler. |
| `/studio:update` | Projedeki kit dosyalarını yeni sürüme günceller. Tasarım dosyalarına ve proje ayarlarına dokunmaz. |
| `/studio:add` | Kiti başka bir Unity projesine kurar. |

Sık kullanılan Game Studios komutları: `/start`, `/prototype`, `/next-step`,
`/design-system`, `/create-stories`, `/sprint-plan`, `/gate-check`.

## 4. Güncelleme neyi değiştirir?

- **Üzerine yazılır** (eski hali `.studio-backup/<zaman>/` klasörüne yedeklenir):
  `.claude/` altındaki çatı dosyaları ve motor referans dokümanları.
- **Hiç dokunulmaz:** `CLAUDE.md`, `project.yaml`, `design/`, `production/`,
  `docs/architecture/`, `Assets/`.
- `.gitignore` ve `.gitattributes` içinde sadece kit'in işaretli bloğu yenilenir.

Kit'in yeni sürümünü almak için:

```bash
claude plugin marketplace update unity-ai-studio
```

```bash
claude plugin update studio@unity-ai-studio
```

Sonra her projede `/studio:update` çalıştır.

## 5. Notlar

- **Unity sürümü:** gamedev skill'leri ve Game Studios motor dokümanları
  **Unity 6.3 LTS**'i hedefliyor. Daha eski bir sürümde de çalışır, ama
  önerilen API'leri sürümüne göre kontrol et. `/studio:doctor` bunu uyarı
  olarak gösterir.
- **Derleme hataları** Editor'ü Safe Mode'a sokar ve Claude'un Editor bağlantısı
  kopar. Önce hataları düzelt.
- Kit, Game Studios'u `.claude/` içine kopyalar. Game Studios'u kendi
  yöntemleriyle **güncelleme**. `/studio:update` kullan, yoksa agent'lardaki
  skill bağlantıları silinir.

## Kit'i geliştirmek (bakımcılar için)

```
payload/      Projeye kopyalanan dosyalar (Game Studios + entegrasyon katmanı)
templates/    .gitignore / .gitattributes blokları
scripts/      add-to-project, doctor, common: .ps1 (Windows) ve .sh (macOS/Linux)
skills/       /studio:add, /studio:doctor, /studio:update
setup-machine.ps1 / setup-machine.sh
.claude-plugin/   plugin.json + marketplace.json (repo hem plugin hem marketplace)
VERSION       Kit sürümü. plugin.json ve marketplace.json içindeki version ile aynı tutulur.
```

Bir değişiklik yayınlamak için:

1. `payload/` ya da script'leri düzenle.
2. `VERSION` ile iki manifest'teki `version` değerini artır.
3. Commit ve push et, `vX.Y.Z` tag'i ekle.

Projeler yeni sürümü `/studio:update` ile alır.

## Lisans

Kit: MIT (`LICENSE`). İçerdiği Claude Code Game Studios da MIT lisanslıdır
(`payload/.claude/CCGS-LICENSE`). Ayrıntılar `THIRD_PARTY.md` dosyasında.
gamedev ve Unity plugin'leri kit'e dahil değildir; kendi kaynaklarından kurulur.

---

**English summary:** a one-command Claude Code environment for Unity on Windows
and macOS. Run `setup-machine.ps1` (Windows) or `setup-machine.sh` (macOS) once
per machine, then `/studio:add` in any Unity project,
`/setup-engine unity`, and `/studio:doctor`. It bundles Claude Code Game
Studios with wiring to the gamedev skills and Unity's official plugin, CLI and
Editor MCP.
