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
- **Tereni** — CRUD, upload slike terena (provjerava se stvarni sadržaj fajla, ne samo ekstenzija),
  radno vrijeme po danima (novi teren kreće zatvoren, standardni raspored 08:00–22:00 na jedan
  klik), pretraga, pregled recenzija sa prosječnom ocjenom
- **Raspored** — pregled termina po terenu i danu, blokiranje i odblokiranje termina
- **Rezervacije** — pretraga (i po klijentu) i filteri (status, period), detalji, potvrda i
  otkazivanje, evidencija gotovinskog plaćanja; povrat novca preko Stripe-a ili ručno za gotovinu,
  uz status povrata i ponovni pokušaj kad povrat ne uspije; lista se sama osvježava dok je otvorena
- **Izvještaji** — dva PDF izvještaja za odabrani period i sportski centar: rezervacije (sažetak po
  statusu, ostvareni prihod, pregled rezervacija) i popunjenost terena (najtraženiji termini i
  popunjenost u odnosu na radno vrijeme)
- **Obavijesti** — CRUD obavijesti sa slikom i datumom objave
- **Referentni podaci** — CRUD za sportove, sportske centre, gradove i države;
  koordinate centra se biraju pinovanjem na karti (polja su samo za čitanje)
- Liste sa straničenjem; prekidač jezika BS/EN

### Mobilna (korisnička aplikacija)
- Registracija i prijava; **zaboravljena lozinka** — šestocifreni kod stiže mailom i vrijedi 15 minuta
- **Tereni** — lista sa slikom i prosječnom ocjenom, pretraga i filteri (sport, grad),
  sekcija „Preporučeno za tebe“
- **Detalji terena** — podaci, adresa i grad, radno vrijeme po danima, prosječna ocjena i lista
  recenzija (master-detail)
- **Dostupnost** — odabir datuma i slobodnog termina
- **Rezervacija i plaćanje** — gotovina ili kartica (Stripe PaymentSheet, in-app)
- **Moje rezervacije** — aktivne i historija, status plaćanja, „Plati karticom“ za neplaćenu
  rezervaciju, otkazivanje uz pravilo od 24 sata (prikazan je tačan rok), ocjenjivanje terena
  nakon završene rezervacije
- **Profil** — pregled i izmjena podataka, profilna slika, promjena lozinke
- **Obavijesti** i **Notifikacije** (real-time preko SignalR-a, uz označavanje pročitanog)
- Prekidač jezika BS/EN

### Poslovna logika
- Statusi rezervacije `Pending → Confirmed → Completed / Cancelled` kroz centralizovanu
  state machine
- Pozadinski posao (pri pokretanju API-ja, pa svakih `RESERVATION_SWEEP_MINUTES` minuta) otkazuje
  rezervacije na čekanju kojima je termin počeo, završava prošle i kod Stripe-a provjerava
  kartična plaćanja i povrate koji još čekaju
- Provjera preklapanja termina, radnog vremena i blokada na serveru
- Audit trag (ko je i kada potvrdio/otkazao, razlog otkazivanja)
- Plaćanje se finalizira serverski (Stripe webhook ili serverska provjera kod Stripe-a); klijent
  nikad sam ne evidentira uspješno plaćanje. Povrat ide preko Stripe API-ja.
- Notifikacije za kreiranje, potvrdu, otkazivanje i završetak rezervacije te plaćanje i povrat;
  mail za kod za novu lozinku te kreiranje, potvrdu i otkazivanje rezervacije

## Pokretanje

### Preduslovi
- Docker Desktop, Android emulator (AVD) za mobilnu aplikaciju, Windows za desktop aplikaciju
- Za pokretanje iz izvornog koda još: Flutter SDK (3.44, Dart 3.12), Android SDK, JDK 17 i
  Visual Studio sa „Desktop development with C++“ (za Windows build); .NET 9 SDK samo ako se API
  pokreće bez Dockera
- **Konfiguracija:** raspakovati `.env-tajne.zip` u root repozitorija (nastaje `.env` fajl;
  šifra arhive je dostavljena uz predaju rada). Alternativno: kopirati `.env.example` → `.env`
  i popuniti vlastite vrijednosti.

### Backend (Docker)
```bash
docker compose up -d --build    # SQL Server + RabbitMQ + API + Worker
```
- Swagger: http://localhost:5000/swagger
- RabbitMQ Management: http://localhost:15672 (korisnik i lozinka su `RABBITMQ_USER` /
  `RABBITMQ_PASSWORD` iz `.env`)

Migracije i seed podaci se primjenjuju automatski pri pokretanju API-ja.

### Aplikacije iz GitHub Release-a
Arhiva `fit-build-<datum>.zip` iz Release-a sadrži gotove buildove:
- **Mobilna:** obrisati staru verziju aplikacije u AVD, pa prevući `app-release.apk` u emulator.
  Adresa API-ja je `http://10.0.2.2:5000` (host računar gledano iz emulatora).
- **Desktop:** pokrenuti `Release\courtside_admin.exe`. Adresa API-ja je `http://localhost:5000`.

### Aplikacije iz izvornog koda
Mobilna (Android, AVD):
```bash
cd UI/courtside_mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```
Desktop (Windows):
```bash
cd UI/courtside_admin
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5000
```

### Mailovi (Mailtrap)
Worker šalje mailove preko SMTP podataka iz `.env` (`SMTP_*`, Mailtrap sandbox). Mail ne ide
stvarnom primaocu nego završava u Mailtrap inboxu — tu se čita i kod za novu lozinku. Inbox se
čita u Mailtrapu ili bilo kojim POP3 klijentom: server `pop3.mailtrap.io`, port `1100` (STARTTLS),
korisničko ime i lozinka su `SMTP_USERNAME` i `SMTP_PASSWORD` iz `.env`. Za vlastiti inbox dovoljno
je u `.env` upisati svoje `SMTP_*` vrijednosti i ponovo pokrenuti `docker compose up -d`.

### Stripe
- Test kartica: `4242 4242 4242 4242`, bilo koji budući datum i bilo koji CVC.
- Plaćanje radi i bez webhooka: nakon PaymentSheet-a aplikacija traži od API-ja da plaćanje
  provjeri kod Stripe-a, a pozadinski posao provjerava plaćanja i povrate koji još čekaju.
- Webhook (opciono, za trenutne potvrde plaćanja i povrata), uz instaliran Stripe CLI:
  ```bash
  stripe listen --forward-to localhost:5000/api/payments/webhook --events payment_intent.succeeded,payment_intent.payment_failed,refund.updated,refund.failed
  ```
  `whsec_…` koji `stripe listen` ispiše upisati u `STRIPE_WEBHOOK_SECRET` u `.env`, pa
  `docker compose up -d api`. Povrat koji Stripe ne završi odmah dobije konačan status preko
  događaja `refund.updated` / `refund.failed`, a bez njih kad ga pozadinski posao provjeri
  (najkasnije za `RESERVATION_SWEEP_MINUTES` minuta).

## Korisnički nalozi za pristup (seed)

| Kontekst | Korisničko ime | Lozinka |
|---|---|---|
| Desktop verzija (admin) | `desktop` | `test` |
| Mobilna verzija (korisnik) | `mobile` | `test` |
| Admin uloga | `admin` | `test` |

Uz njih se seeduju i klijenti `amina`, `tarik` i `lejla` (lozinka `test`) kako bi historija
rezervacija pokrivala više korisnika — to je potrebno sistemu preporuke da pronađe sličnosti
među korisnicima.

Seed nalozi namjerno imaju lozinku `test` od 4 znaka, kako upute traže. Svaka nova lozinka
(registracija, promjena i reset lozinke) mora imati najmanje 6 znakova, pa se seed nalogu kroz
reset ne može vratiti lozinka `test` — reset lozinke je zato najbolje probati na novom nalogu.

## Sistem preporuke

Collaborative filtering (ML.NET Matrix Factorization) nad historijom rezervacija i pregleda
terena (rezervacija nosi 5 jedinica signala, pregled detalja 1, a pregledi jednog korisnika
najviše 3 po terenu), sa objašnjenjem
zašto je teren preporučen. Kada model ne poznaje korisnika ili ne popuni listu, nude se popularni
tereni iz zadnjih 30 dana, poredani po sportu i gradu koje korisnik inače bira. Model se trenira
pri pokretanju API-ja i zatim svakih 6 sati. Detaljan opis:
[`recommender-dokumentacija.md`](recommender-dokumentacija.md).
