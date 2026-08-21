# CourtSide — Sistem za pregled i rezervaciju sportskih terena

Seminarski rad iz predmeta **Razvoj softvera II** (FIT).
Student: **Merima Čelić, IB180099**. Baza podataka: **`180099`**.

CourtSide je sistem za pregled i rezervaciju sportskih terena (futsal, tenis, padel, badminton) sa
mobilnom (korisničkom) i desktop (administratorskom) aplikacijom koje dijele isti REST API.

## Arhitektura

| Komponenta | Tehnologija |
|---|---|
| REST API | ASP.NET Core (.NET 9), EF Core, JWT, SignalR |
| Pomoćni servis | CourtSide.Worker (RabbitMQ consumer → email/notifikacije) |
| Baza | SQL Server 2022 |
| Poruke | RabbitMQ |
| Desktop app | Flutter (Windows) — `UI/courtside_admin` |
| Mobilna app | Flutter (Android) — `UI/courtside_mobile` |
| Plaćanje | Stripe (sandbox) + gotovina |
| Preporuke | ML.NET Matrix Factorization (collaborative filtering) |
| Izvještaji | QuestPDF (PDF) |

## Struktura projekta

```
CourtSide.Core            domena: entiteti, DTO, enums, exceptions, state machines
CourtSide.Infrastructure  EF DbContext, konfiguracije, migracije, seed, repos, RabbitMQ
CourtSide.Services        biznis logika, recommender, izvještaji, validacija
CourtSide.Shared          SignalR hubs, poruke, konstante, helperi
CourtSide.Api             REST API + SignalR + Stripe webhook
CourtSide.Worker          RabbitMQ consumer (email, notifikacije)
UI/courtside_admin        Flutter desktop (admin)
UI/courtside_mobile       Flutter mobilna (korisnik)
```

## Pokretanje

### Preduslovi
- .NET 9 SDK, Docker Desktop, Flutter SDK, Android SDK + AVD, JDK 17
- Kopirati `.env.example` → `.env` i popuniti vrijednosti (vidi `.env.example`)

### Backend (Docker)
```bash
docker compose up -d            # SQL Server + RabbitMQ + API + Worker
# Swagger: http://localhost:5000/swagger
```

### Mobilna aplikacija (Android, AVD)
```bash
cd UI/courtside_mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

### Desktop aplikacija (Windows)
```bash
cd UI/courtside_admin
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5000
```

## Korisnički nalozi za pristup (seed)

| Kontekst | Korisničko ime | Lozinka |
|---|---|---|
| Desktop verzija (admin) | `desktop` | `test` |
| Mobilna verzija (korisnik) | `mobile` | `test` |
| Admin uloga | `admin` | `test` |

> Status: backend, desktop (admin) i mobilna aplikacija su funkcionalni — auth/JWT, CRUD + reference,
> rezervacije (state machine, dostupnost, overlap), poruke (RabbitMQ + email worker + SignalR),
> plaćanje (Stripe + gotovina), izvještaji (QuestPDF) i sistem preporuke (ML.NET collaborative
> filtering — vidi `recommender-dokumentacija.md`).
