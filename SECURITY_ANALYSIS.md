# height-sync Script Güvenlik ve Optimizasyon Değerlendirmesi

## 📋 Genel Bakış

Bu doküman, **height-sync** QBCore scriptinin güvenlik ve optimizasyon açısından kapsamlı değerlendirmesini içermektedir.

---

## 🔒 GÜVENLİK DEĞERLENDİRMESİ

### ✅ Güvenli Uygulamalar

| Özellik | Durum | Açıklama |
|---------|-------|----------|
| Sunucu Taraflı Doğrulama | ✅ İYİ | [`server/main.lua:13-18`](height-sync/server/main.lua:13) - `IsValidScale()` fonksiyonu ile kapsamlı doğrulama |
| SQL Enjeksiyon Koruması | ✅ İYİ | [`database.lua:34,50`](height-sync/server/database.lua:34) - Parametreli sorgular kullanılıyor |
| Rate Limiting | ✅ İYİ | [`server/main.lua:21-50`](height-sync/server/main.lua:21) - Hem SetHeight hem Broadcast için mevcut |
| Oyuncu Kimlik Doğrulama | ✅ İYİ | [`server/main.lua:55-56,86-87`](height-sync/server/main.lua:55) - QBCore Functions.GetPlayer() kullanılıyor |
| NaN Kontrolü | ✅ İYİ | [`server/main.lua:15`](height-sync/server/main.lua:15) - Sayısal değer kontrolü var |

### ⚠️ Güvenlik Sorunları

#### 🔴 Kritik

**1. Export'larda Kaynak Doğrulaması Eksik**
```lua
-- server/main.lua:144-164
exports('SetPlayerHeight', function(serverId, scale)
    -- HİÇBİR KAYNAK KONTROLÜ YOK!
    -- Herhangi bir resource bu fonksiyonu çağırabilir
```
**Öneri:** QBCore yetkilendirme kontrolü eklenmeli:
```lua
exports('SetPlayerHeight', function(source, serverId, scale)
    -- Admin kontrolü eklenmeli
    if not IsPlayerAdmin(source) then return false end
```

**2. NUI Mesajlarında Kaynak Doğrulaması Yok**
```lua
-- client/main.lua:102-108
RegisterNUICallback('setHeight', function(data, cb)
    -- data kaynağı doğrulanmıyor
    local scale = tonumber(data.scale)
```
**Öneri:** NUI callback'lerinde ek doğrulama eklenmeli

#### 🟠 Orta Düzey

**3. Harici Font Bağımlılığı (Güvenlik Riski)**
```html
<!-- ui/index.html:8 -->
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
```
**Sorun:** Harici kaynak bağlantısı - bağlantı kesilirse font çalışmaz, güvenlik riski
**Öneri:** Font yerel olarak barındırılmalı veya sistem fontu kullanılmalı

**4. Duplicate Code - Potansiyel Bug**
```lua
-- server/main.lua:119-125
-- Bu kod bloğu tekrarlanmış - muhtemelen kopyalama hatası
    -- Update in-memory store only if changed
    if PlayerHeights[src] ~= scale then
        PlayerHeights[src] = scale
    end
```

**5. Admin Yetkisi Kontrolü Yok**
```lua
-- server/main.lua:77
RegisterNetEvent('height-sync:setHeight', function(scale)
    -- Herhangi bir oyuncu yükseklik ayarlayabilir
    -- Öneri: config'de yetkili rolü tanımlanabilir
```

---

## ⚡ OPTİMİZASYON DEĞERLENDİRMESİ

### ✅ İyi Uygulamalar

| Özellik | Durum | Açıklama |
|---------|-------|----------|
| Frame Bazlı Throttle | ✅ İYİ | [`client/main.lua:120`](height-sync/client/main.lua:120) - Wait(0) kullanımı |
| Araç İçi Uygulama Atlama | ✅ İYİ | [`client/main.lua:125`](height-sync/client/main.lua:125) - Araçtayken uygulanmıyor |
| Distance Check Öncesi Caching | ✅ İYİ | [`client/sync.lua:23-25`](height-sync/client/sync.lua:23) - GetEntityCoords öncesi kontrol |
| Player Ped Cache | ✅ İYİ | [`client/sync.lua:8`](height-sync/server/database.lua:8) - PlayerPed önbellek sistemi |
| Scale 1.0 Atlaması | ✅ İYİ | [`client/sync.lua:13,46`](height-sync/client/sync.lua:13) - Varsayılan değer atlanıyor |
| Değer Sınırlama | ✅ İYİ | [`client/main.lua:76`](height-sync/client/main.lua:76) - math.max/min ile sınırlama |

### 🟡 Optimize Edilebilir

#### 🟠 Orta Düzey

**1. Her Frame Tüm Remote Player Döngüsü**
```lua
-- client/sync.lua:45-64
for serverId, data in pairs(RemoteHeights) do
    -- HER FRAME çalışıyor - 60fps'de çok maliyetli
```
**Öneri:** 
```lua
-- Her 10 frame'de bir veya SetTimeout ile throttle
local frameCount = 0
CreateThread(function()
    while true do
        Wait(0)
        frameCount = frameCount + 1
        if frameCount % 10 == 0 then
            -- işlemleri burada yap
        end
    end
end)
```

**2. Sunucu Tarafında Mesaj Yayını Optimize Edilmemiş**
```lua
-- server/main.lua:100
TriggerClientEvent('height-sync:playerUpdate', -1, src, scale)
-- TÜM oyunculara gönderiliyor - yakın olanlara gerek yok
```
**Öneri:** Sadece yakın oyunculara gönder:
```lua
local players = GetPlayers()
for _, player in ipairs(players) do
    local dist = #(GetEntityCoords(GetPlayerPed(player)) - targetPos)
    if dist <= Config.SyncDistance then
        TriggerClientEvent('height-sync:playerUpdate', player, src, scale)
    end
end
```

**3. Veritabanı Her Değişiklikte Yazıyor**
```lua
-- server/main.lua:95-97
if Config.SaveToDatabase then
    exports['height-sync']:SavePlayerHeight(citizenid, scale)
end
-- Her setHeight'de yazıyor - çok fazla IO
```
**Öneri:** Debounce veya periyodik kaydetme:
```lua
-- Önbelleğe al ve periyodik kaydet
local pendingWrites = {}
CreateThread(function()
    while true do
        Wait(30000) -- 30 saniyede bir
        for citizenid, scale in pairs(pendingWrites) do
            MySQL.query.await(...)
        end
        pendingWrites = {}
    end
end)
```

**4. Bellek Sızıntısı Potansiyeli**
```lua
-- server/main.lua:4
local PlayerHeights = {}  -- Oyuncu çıkışında temizleniyor ✅
-- client/sync.lua:4  
local RemoteHeights = {}  -- playerLeft event'inde temizleniyor ✅
```
**Durum:** Temizleniyor ama büyük sunuculardabellek yönetimi iyileştirilebilir

**5. GetLocalHeight Fonksiyonu Cache'lenebilir**
```lua
-- client/sync.lua:73
local scale = GetLocalHeight()
-- Her sync interval'de çağrılıyor
```
**Öneri:** Global değişken kullanarak fonksiyon çağrısını azalt

---

## 📊 Performans Metrikleri

| Metrik | Mevcut | Önerilen |
|--------|--------|----------|
| Client FPS Etkisi | Yüksek (Wait(0)) | Orta (Wait(10-50)) |
| Ağ Trafiği | Yüksek | Düşük (sadece yakınlar) |
| DB Yazma Sıklığı | Her istek | Batch/throttled |
| Memory Cleanup | Manuel | Otomatik periyodik |

---

## 🔧 Öncelikli Düzeltmeler

### Yüksek Öncelik (Güvenlik)
1. ✅ Export'larda kaynak doğrulaması
2. ✅ NUI callback doğrulama
3. ✅ Admin yetkisi kontrolü

### Orta Öncelik (Performans)
1. Frame rate throttle uygulaması
2. Sunucu tarafında mesaj yayını optimizasyonu
3. Veritabanı batch yazma

### Düşük Öncelik
1. Harici font yerine lokal font
2. Duplicate kod temizliği

---

## 📝 QBCore Entegrasyonu Değerlendirmesi

| QBCore Özelliği | Kullanım | Uyumluluk |
|-----------------|----------|-----------|
| QBCore:Client:OnPlayerLoaded | ✅ Doğru | Uyumlu |
| QBCore:Client:OnPlayerUnload | ✅ Doğru | Uyumlu |
| QBCore.Functions.GetPlayer | ✅ Doğru | Uyumlu |
| oxmysql dependency | ✅ Doğru | Uyumlu |

---

*Değerlendirme Tarihi: 2026-03-06*
*Değerlendirmeci: QBCore Best Practices*
