# Dobrich’s Brain

Mój drugi mózg na iPhone’a: notatki z #tagami, zadania z przypomnieniami i licznik godzin pracy.
Web-apka (PWA), bez App Store. Działa offline, dane zostają tylko na telefonie.

## Instalacja na iPhonie
1. Otwórz adres apki w **Safari** (`https://<twoj-login>.github.io/dobrichs-brain/`).
2. Udostępnij → **Dodaj do ekranu początkowego**.

## Funkcje
- **Notatki**: zapis myśli, #tagi, wyszukiwanie, przypinanie.
- **Zadania**: terminy, grupy Zaległe/Dziś/Później. 🔔 dodaje przypomnienie do Kalendarza iPhone’a (.ics z alarmem),
  bo web-apki na iOS nie mogą same planować powiadomień.
- **Praca**: start/stop zmiany albo ręczny wpis (od–do, przerwa lub liczba godzin), podsumowanie miesiąca,
  cel godzin, zarobek wg stawki i eksport do CSV.
- **Więcej**: kopia zapasowa JSON i przywracanie.

## Pliki
`index.html`, `style.css`, `app.js`, `sw.js` (offline; podbij `VERSION` przy zmianach), `manifest.webmanifest`, `icons/`.
Push na `main` sam publikuje apkę na GitHub Pages (`.github/workflows/pages.yml`).
