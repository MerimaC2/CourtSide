# Sistem preporuka – tehnička dokumentacija

## 1. Pregled

CourtSide sistem preporuka koristi **kolaborativno filtriranje** zasnovano na ML.NET
**Matrix Factorization** algoritmu. Cilj sistema je predložiti korisniku terene koje još
nije rezervisao, na osnovu obrazaca ponašanja korisnika sa sličnom historijom korištenja.

Sistem radi nad **implicitnim signalima** – ne traži od korisnika da bilo šta ocjenjuje,
nego uči iz onoga što korisnici stvarno rade:

- **Rezervacije** (primarni signal) – rezervacija terena je jak pokazatelj interesa.
- **Pregledi terena** (sekundarni signal) – otvaranje detalja terena je slabiji, ali koristan trag.

Kada za korisnika nema dovoljno podataka (hladni start), sistem se spušta na preporuke
po popularnosti, tako da sekcija „Preporučeno za tebe" u mobilnoj aplikaciji nikada nije prazna.

---

## 2. Ključni pojmovi

| Pojam | Definicija |
|---|---|
| **Interakcija** | Jedan par (korisnik, teren) izveden iz rezervacije ili pregleda terena. |
| **Implicitni signal** | Podatak o interesu izveden iz ponašanja, bez eksplicitne ocjene. |
| **One-class problem** | Poznati su samo pozitivni primjeri (interakcija se desila); negativni se ne bilježe. Svaka interakcija dobija `Label = 1`. |
| **Matrica interakcija** | Rijetka matrica `korisnici × tereni` u kojoj ćelija označava da je korisnik imao interakciju s terenom. |
| **Latentni faktori** | Skrivene osobine korisnika i terena koje algoritam sam nauči; ne zadaju se ručno. |
| **Matrix Factorization** | Razlaganje matrice interakcija `R` na proizvod manjih matrica `P` (korisnici) i `Q` (tereni): `R ≈ P × Qᵀ`. Skor kandidata je skalarni proizvod `score(u, t) = p_u · q_t`. |
| **Hladni start** | Situacija u kojoj model ne poznaje korisnika (nema historije) ili je podataka premalo za treniranje. |

---

## 3. Konfiguracija

Parametri sistema su definisani kao konstante u kodu (`RecommenderService`; interval re-treniranja u `RecommenderTrainingService`):

| Parametar | Vrijednost | Opis |
|---|---|---|
| `MinInteractions` | `6` | Minimalan ukupan broj interakcija za treniranje. |
| `MinDistinctUsers` | `2` | Minimalan broj različitih korisnika. |
| `MinDistinctCourts` | `2` | Minimalan broj različitih terena. |
| `count` (API parametar) | `3` (raspon 1–10) | Broj preporuka koje endpoint vraća. |
| `RetrainInterval` | `6 h` | Interval periodičnog re-treniranja u pozadini. |
| `ModelPath` | `models/recommender.zip` | Lokacija sačuvanog modela na disku. |

Parametri samog trenera (`MatrixFactorizationTrainer.Options`):

| Parametar | Vrijednost | Opis |
|---|---|---|
| `LossFunction` | `SquareLossOneClass` | Varijanta za implicitne (one-class) podatke. |
| `ApproximationRank` | `32` | Broj latentnih faktora. |
| `NumberOfIterations` | `100` | Broj iteracija optimizacije. |
| `Lambda` | `0.025` | Regularizacija (sprečava overfitting). |
| `Alpha` | `0.01` | Težina implicitnih negativnih primjera. |
| `C` | `0.00001` | Ciljna vrijednost za neopažene ćelije matrice. |

---

## 4. Preporuke za korisnika (`GetForCurrentUserAsync`)

**Implementacija:** `RecommenderService.GetForCurrentUserAsync(int count = 3)`

### Koraci algoritma

1. **Skup kandidata**
   Učitavaju se svi aktivni tereni, pa se iz njih isključe tereni koje je korisnik već
   rezervisao (status različit od `Cancelled`). Preporučuje se samo ono što je korisniku novo.

2. **Kolaborativno filtriranje**
   Ako je model istreniran i poznaje korisnika (korisnik je postojao u podacima pri zadnjem
   treniranju), svi kandidati se skoruju modelom. Kandidati se sortiraju silazno po skoru
   i uzima se top `count`, uz objašnjenje
   _„Korisnici sa sličnim rezervacijama često biraju ovaj teren."_

3. **Dopuna popularnošću**
   Ako kolaborativni dio nije dao dovoljno preporuka (model nije istreniran, korisnik je
   nepoznat ili je kandidata premalo), lista se dopunjava terenima s najviše rezervacija
   u **zadnjih 30 dana**, uz objašnjenje _„Najpopularniji teren u zadnjih 30 dana."_

4. **Posljednja odbrana**
   Ako ni popularnost ne popuni listu (npr. potpuno svježa baza bez ijedne rezervacije),
   dodaju se preostali aktivni tereni uz generičko objašnjenje _„Predloženo za tebe."_

Svaka preporuka nosi i podatke za prikaz (naziv, sport, centar, cijena, slika) te skor,
pa mobilna aplikacija ne mora ništa naknadno dohvaćati.

### Dijagram toka

```
Učitaj aktivne terene i rezervacije korisnika
        │
        ▼
Izbaci već rezervisane terene (kandidati)
        │
        ▼
Model istreniran i poznaje korisnika?
   DA ──► Skoruj kandidate modelom
   │          │
   │          ▼
   │      Sortiraj silazno po skoru, uzmi top N
   │          │
   NE         ▼
   └────► Lista ima manje od N stavki?
              DA ──► dopuni najpopularnijim (zadnjih 30 dana)
              │
              ▼
          I dalje manje od N?
              DA ──► dopuni preostalim aktivnim terenima
              │
              ▼
          Vrati listu preporuka s objašnjenjima
```

---

## 5. Treniranje modela (`TrainAsync`)

**Implementacija:** `RecommenderService.TrainAsync()`

1. **Prikupljanje interakcija**
   Iz baze se učitaju parovi (klijent, teren) iz svih neotkazanih rezervacija, zatim parovi
   (korisnik, teren) iz zapisa o pregledima terena (`CourtViewLog`). Svaki par postaje jedna
   interakcija s `Label = 1`.

2. **Provjera pragova**
   Ako je interakcija manje od `MinInteractions`, ili je korisnika/terena manje od minimuma,
   treniranje se preskače (matrica bi bila prerijetka) i sistem ostaje na popularnosti.

3. **Pipeline**
   ID korisnika i terena se mapiraju u ključeve (`MapValueToKey`), pa se trenira
   `MatrixFactorizationTrainer` s parametrima iz sekcije 3.

4. **Objava i perzistencija**
   Novi model atomarno zamjenjuje stari u memorijskom kešu (singleton `IRecommenderModel`,
   zaštićen lock-om – API zahtjevi skoruju bez prekida i tokom re-treniranja). Model se
   zatim snima na disk (`models/recommender.zip` + sidecar `.ids` sa spiskom poznatih
   korisnika i terena, potreban za ispravno učitavanje poslije restarta).

---

## 6. Životni ciklus modela (`RecommenderTrainingService`)

Pozadinski servis (`BackgroundService`) upravlja modelom kroz cijeli život aplikacije:

1. **Warm start** – pri pokretanju API-ja pokuša učitati sačuvani model s diska, pa preporuke
   rade odmah, bez čekanja prvog treniranja.
2. **Treniranje pri startu** – odmah zatim trenira model nad aktuelnim podacima.
3. **Periodično re-treniranje** – ponavlja treniranje svakih 6 sati, čime nove rezervacije
   i pregledi ulaze u model bez ikakve ručne intervencije.
4. **Ručno re-treniranje** – administrator može pokrenuti trening odmah, endpointom iz sekcije 7.

Greška u treniranju se loguje i ne ruši servis – stari model ostaje u upotrebi.

---

## 7. Gdje se sistem koristi

| Endpoint | Pristup | Opis |
|---|---|---|
| `GET /api/recommendations?count=3` | prijavljeni korisnik | Vraća preporuke za trenutnog korisnika. Poziva ga početni ekran mobilne aplikacije (sekcija „Preporučeno za tebe"). |
| `POST /api/courts/{id}/view` | prijavljeni korisnik | Bilježi pregled terena (sekundarni signal). Mobilna aplikacija ga zove pri otvaranju detalja terena. |
| `POST /api/recommendations/retrain` | administrator | Ručno pokreće re-treniranje modela. |

---

## 8. Ograničenja i napomene

- **Samo implicitni signali:** ocjene terena (recenzije) ne ulaze u model – koristi se
  isključivo ponašanje (rezervacije i pregledi), pa sistem radi i za korisnike koji
  nikada ništa ne ocijene.
- **Bez sadržajnih atributa:** karakteristike terena (sport, lokacija, cijena) nisu ulaz
  u algoritam; sličnost proizlazi samo iz obrazaca korištenja.
- **Nepoznati korisnici i tereni:** model može skorovati samo korisnike i terene koje je
  vidio pri treniranju. Novi korisnici dobijaju popularnost do prvog sljedećeg treninga
  nakon njihove prve interakcije; isto vrijedi za novododane terene.
- **Obrada u memoriji:** sve interakcije se učitavaju u memoriju pri treniranju. Za obim
  ovog sistema (stotine korisnika, desetine terena) to je ispravan izbor; kod višestruko
  većih podataka trening bi trebalo premjestiti u izdvojeni posao.
- **Native zavisnost:** ML.NET Matrix Factorization zahtijeva `libgomp1` (OpenMP) u Linux
  kontejneru – instalirana je u runtime sloju `CourtSide.Api/Dockerfile`.
