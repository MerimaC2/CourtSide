# CourtSide — Sistem za pregled i rezervaciju sportskih terena

Seminarski rad iz predmeta **Razvoj softvera II** (FIT).
Student: **Merima Čelić, IB180099**. Baza podataka: **`180099`**.

CourtSide je sistem za pregled i rezervaciju sportskih terena (futsal, tenis, padel, badminton) sa
mobilnom (korisničkom) i desktop (administratorskom) aplikacijom koje dijele isti REST API.

## Arhitektura

| Komponenta | Tehnologija |
|---|---|
| REST API | ASP.NET Core (.NET 9), EF Core, JWT, SignalR |
| Pomoćni servis | CourtSide.Worker (RabbitMQ consumer → email) |
| Baza | SQL Server 2022 |
| Poruke | RabbitMQ |
| Desktop app | Flutter (Windows) — `UI/courtside_admin` |
| Mobilna app | Flutter (Android) — `UI/courtside_mobile` |
| Plaćanje | Stripe (sandbox) + gotovina |
| Preporuke | ML.NET Matrix Factorization (collaborative filtering) |
| Izvještaji | QuestPDF (PDF) |
| Karte | flutter_map + OpenStreetMap (odabir koordinata) |

## Struktura projekta

```
CourtSide.Core            domena: entiteti, DTO, enums, exceptions, state machines, helpers
CourtSide.Infrastructure  EF DbContext, konfiguracije, migracije, seed, RabbitMQ
CourtSide.Services        biznis logika, recommender, izvještaji, validacija, background poslovi
CourtSide.Shared          SignalR hubs, poruke, konstante, helperi
CourtSide.Api             REST API + SignalR + Stripe webhook
CourtSide.Worker          RabbitMQ consumer (email)
UI/courtside_admin        Flutter desktop (admin)
UI/courtside_mobile       Flutter mobilna (korisnik)
```

## Funkcionalnosti

### Desktop (administratorska aplikacija)
- Prijava uz provjeru administratorske uloge
- **Tereni** — CRUD, upload slike terena, pretraga, pregled recenzija sa prosječnom ocjenom
- **Raspored** — pregled termina po terenu i danu, blokiranje/odblokiravanje termina
- **Rezervacije** — pretraga i filteri (status, period), detalji, potvrda i otkazivanje,
  evidencija gotovinskog plaćanja i refund; lista se sama osvježava dok je otvorena
- **Izvještaji** — PDF izvještaj o rezervacijama (sažetak po statusu, prihod, pregled)
- **Obavijesti** — CRUD obavijesti sa slikom i datumom objave
- **Referentni podaci** — CRUD za sportove, sportske centre, gradove i države;
  koordinate centra se biraju pinovanjem na karti (polja su samo za čitanje)
- Prekidač jezika BS/EN

### Mobilna (korisnička aplikacija)
- Registracija i prijava
- **Tereni** — lista sa slikom i prosječnom ocjenom, pretraga i filteri (sport, grad),
  sekcija „Preporučeno za tebe“
- **Detalji terena** — podaci, prosječna ocjena i lista recenzija (master-detail)
- **Dostupnost** — odabir datuma i slobodnog termina
- **Rezervacija i plaćanje** — gotovina ili kartica (Stripe PaymentSheet, in-app)
- **Moje rezervacije** — aktivne i historija, otkazivanje uz pravilo od 24 sata,
  ocjenjivanje terena nakon završene rezervacije
- **Profil** — pregled i izmjena podataka, profilna slika, promjena lozinke
- **Obavijesti** i **Notifikacije** (real-time preko SignalR-a, uz označavanje pročitanog)
- Prekidač jezika BS/EN

### Poslovna logika
- Statusi rezervacije `Pending → Confirmed → Completed / Cancelled` kroz centralizovanu
  state machine; rezervacije kojima je termin istekao se automatski zatvaraju u pozadinskom poslu
- Provjera preklapanja termina, radnog vremena i blokada na serveru
- Audit trag (ko je i kada potvrdio/otkazao, razlog otkazivanja)
- Plaćanje se finalizira serverski (Stripe webhook), refund preko Stripe API-ja
- Notifikacije za kreiranje, potvrdu, otkazivanje i završetak rezervacije te plaćanje i povrat

## Pokretanje

### Preduslovi
- .NET 9 SDK, Docker Desktop, Flutter SDK, Android SDK + AVD, JDK 17
- **Konfiguracija:** raspakovati `.env-tajne.zip` u root repozitorija (nastaje `.env` fajl;
  šifra arhive je dostavljena uz predaju rada). Alternativno: kopirati `.env.example` → `.env`
  i popuniti vlastite vrijednosti.

### Backend (Docker)
```bash
docker compose up -d            # SQL Server + RabbitMQ + API + Worker
# Swagger: http://localhost:5000/swagger
```
Migracije i seed podaci se primjenjuju automatski pri pokretanju API-ja.

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

Uz njih se seeduju i klijenti `amina`, `tarik` i `lejla` (lozinka `test`) kako bi historija
rezervacija pokrivala više korisnika — to je potrebno sistemu preporuke da pronađe sličnosti
među korisnicima.

## Sistem preporuke

Collaborative filtering (ML.NET Matrix Factorization) nad historijom rezervacija i pregleda
terena, sa objašnjenjem zašto je teren preporučen i fallbackom na popularne terene kada korisnik
nema dovoljno historije. Detaljan opis: [`recommender-dokumentacija.md`](recommender-dokumentacija.md).
