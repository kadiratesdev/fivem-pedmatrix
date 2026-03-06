<p align="center">
  <img src="https://img.shields.io/github/stars/kadiratesdev/fivem-pedmatrix?style=flat&color=22c55e" alt="Stars">
  <img src="https://img.shields.io/github/forks/kadiratesdev/fivem-pedmatrix?style=flat&color=22c55e" alt="Forks">
  <img src="https://img.shields.io/github/license/kadiratesdev/fivem-pedmatrix?style=flat&color=22c55e" alt="License">
  <img src="https://img.shields.io/github/v/release/kadiratesdev/fivem-pedmatrix?style=flat&color=22c55e" alt="Version">
</p>

<h1 align="center">
  <img src="https://img.shields.io/badge/🔥%20qb--pedscale-22c55e?style=for-the-badge&logo=none" alt="qb-pedscale">
</h1>

<p align="center">
  <b>QBCore</b> için yükseklik senkronizasyonu ve ped ölçekleme sistemi. Oyuncuların boyunu özelleştir ve diğer oyunculara senkronize et!
</p>

<br>

<p align="center">
  <img src="https://i.imgur.com/example-preview.gif" alt="Preview" width="600">
</p>

---

## ✨ Özellikler

| Özellik | Açıklama |
|----------|-----------|
| 🔄 **Gerçek Zamanlı Senkronizasyon** | Diğer oyuncuların yüksekliğini anlık olarak gör |
| 🎮 **Kolay Kullanım** | F2 tuşu veya `/height` komutu ile aç |
| ⚡ **Yüksek Performans** | Optimize edilmiş kod ile FPS düşüşü minimize |
| 🔒 **Güvenlik** | Sunucu tarafı doğrulama ve admin kontrolü |
| 💾 **Veritabanı Desteği** | Oxmysql ile kalıcı yükseklik verileri |
| 🎨 **Modern UI** | Güzel ve kullanışlı arayüz |

---

## 📋 Gereksinimler

- [QBCore Framework](https://github.com/qbcore-framework/qb-core)
- [oxmysql](https://github.com/overextended/oxmysql)

---

## 🚀 Kurulum

### 1. İndir
```bash
cd resources
git clone https://github.com/kadiratesdev/fivem-pedmatrix.git [qb]/qb-pedscale
```

### 2. Ayarla
`fxmanifest.lua` dosyasında gerekli bağımlılıkları kontrol et:
```lua
dependency 'oxmysql'
dependency 'qb-core'
```

### 3. Başlat
`server.cfg` dosyanıza ekleyin:
```cfg
ensure qb-pedscale
```

---

## ⚙️ Konfigürasyon

`shared/config.lua` dosyasından ayarları değiştirebilirsiniz:

```lua
Config.MinHeight = 0.5       -- Minimum ölçek (50%)
Config.MaxHeight = 2.0       -- Maximum ölçek (200%)
Config.SyncDistance = 50.0   -- Senkronizasyon mesafesi
Config.RequireAdmin = false  -- Admin yetkisi gerektir
```

---

## 🎮 Kullanım

| Komut | Tuş | Açıklama |
|-------|-----|-----------|
| `/height` | - | UI'yi aç/kapat |
| - | `F2` | UI'yi aç/kapat |

### UI Özellikleri:
- 📊 Slider ile hassas ayar
- ⚡ Hızlı preset butonları (0.5x - 2.0x)
- 👁️ Canlı önizleme

---

## 🔧 API & Events

### Client Events
```lua
-- Yükseklik değişikliği
TriggerServerEvent('height-sync:setHeight', 1.5)
```

### Server Exports
```lua
-- Oyuncunun yüksekliğini ayarla
exports['qb-pedscale']:SetPlayerHeight(serverId, scale)

-- Oyuncunun yüksekliğini al
local height = exports['qb-pedscale']:GetPlayerHeight(serverId)
```

---

## 🛡️ Güvenlik Özellikleri

- ✅ Sunucu tarafı input doğrulama
- ✅ Rate limiting (spam koruması)
- ✅ Admin yetkisi kontrolü (opsiyonel)
- ✅ SQL injection koruması
- ✅ NUI callback doğrulama

---

## 📊 Performans

| Metrik | Değer |
|--------|-------|
| Client FPS Etkisi | < 1% |
| Sunucu CPU | Minimal |
| Ağ Trafiki | Optimize edilmiş |
| Memory | ~2MB |

---

## 🤝 Katkıda Bulunun

1. Repository'yi fork edin
2. Feature branch oluşturun (`git checkout -b feature/amazing`)
3. Commit yapın (`git commit -m 'Amazing feature'`)
4. Push edin (`git push origin feature/amazing`)
5. Pull Request açın

---

## 📝 Lisans

MIT License - Copyright (c) 2024

---

## ⭐ Beğendiyseniz

Eğer bu proje size yardımcı oldu, ⭐ vermeyi ve paylaşmayı unutmayın!

---

<p align="center">
  <b>Made with ❤️ for QBCore Community</b>
</p>
