# Metric Dictionary

Bu doküman, PlayerPulse LiveOps analizlerinde kullanılan temel metriklerin kısa açıklamalarını içerir.

## Önerilen metrikler

- `event_timestamp`: Olayın oluşma zamanı
- `player_id`: Oyuncu kimliği
- `event_type`: Olay türü
- `session_id`: Oturum kimliği
- `region`: Oyuncunun konumu / bölgesi
- `device_type`: Cihaz tipi
- `event_value`: Olayın değer/ölçümü

## Kullanım notları

- Her metrik için veri tipi ve null durumları kontrol edilmelidir.
- Staging SQL üzerinde dönüşümler yapılmadan önce ham verinin doğrulanması gerekir.
