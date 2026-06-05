# PlayerPulse LiveOps

Bu proje, `Wowah` olaylarını profillemek, temizlemek ve analiz etmek için temel bir çalışma alanı sağlar.

## Klasör yapısı

- `data/raw/` → ham veri dosyaları
- `data/processed/` → işlenmiş veri setleri
- `data/outputs/` → raporlar ve çıktı dosyaları
- `notebooks/` → analiz ve profil notebook'ları
- `sql/` → staging SQL betikleri
- `docs/` → sözlük ve dokümantasyon

## Başlangıç

1. Sanal ortam oluşturun.
2. `pip install -r requirements.txt` komutunu çalıştırın.
3. `notebooks/01_data_profile.ipynb` üzerinden profiling işlemlerini inceleyin.
