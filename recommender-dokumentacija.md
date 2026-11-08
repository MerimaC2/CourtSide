# Sistem preporuka – tehnička dokumentacija

## 1. Pregled

CourtSide sistem preporuka koristi **kolaborativno filtriranje** zasnovano na ML.NET
**Matrix Factorization** algoritmu. Cilj sistema je predložiti korisniku terene koje još
nije rezervisao, na osnovu obrazaca ponašanja korisnika sa sličnom historijom korištenja.

Sistem radi nad **implicitnim signalima** – ne traži od korisnika da bilo šta ocjenjuje,
nego uči iz onoga što korisnici stvarno rade:

- **Rezervacije** (primarni signal) – rezervacija terena je jak pokazatelj interesa.
- **Pregledi terena** (sekundarni signal) – otvaranje detalja terena je slabiji, ali koristan trag.

Ta dva signala **nemaju istu težinu** (sekcija 5): jedna rezervacija vrijedi više od svih
pregleda istog terena, pa listanje aplikacije ne može nadjačati stvarno rezervisan termin.

Kada za korisnika nema dovoljno podataka (hladni start), sistem se spušta na preporuke po
popularnosti. Korisnik bez ijedne rezervacije nema ni sport ni grad po kojem bi se poredak
prilagodio, pa – ako ga model ne poznaje preko pregleda terena – dobija čistu popularnost. Korisniku koji ima rezervacije, a model ga ne
pokriva (ili kolaborativni dio ne popuni listu), popularni tereni se dodatno rangiraju prema
**sportu i gradu** koje inače bira – to je sadržajni (content-based) element hibridnog
pristupa. Ako je korisnik već rezervisao svaki aktivni teren, preporučuju se njegovi najčešće
rezervisani aktivni tereni, pa sekcija „Preporučeno za tebe" u mobilnoj aplikaciji nije prazna
sve dok postoji barem jedan aktivan teren.

---

## 2. Ključni pojmovi

| Pojam | Definicija |
|---|---|
| **Interakcija** | Jedan par (korisnik, teren) izveden iz rezervacije ili pregleda terena. |
| **Jedinica signala** | Mjera jačine interesa: par ulazi u matricu onoliko puta koliko je jedinica sakupio (sekcija 5). |
| **Implicitni signal** | Podatak o interesu izveden iz ponašanja, bez eksplicitne ocjene. |
| **One-class problem** | Poznati su samo pozitivni primjeri (interakcija se desila); negativni se ne bilježe. Svaka opažena ćelija vrijedi jednako, pa se jačina ne može upisati u `Label` nego se izražava brojem ponavljanja. |
| **Matrica interakcija** | Rijetka matrica `korisnici × tereni` u kojoj ćelija označava da je korisnik imao interakciju s terenom. |
| **Latentni faktori** | Skrivene osobine korisnika i terena koje algoritam sam nauči; ne zadaju se ručno. |
| **Matrix Factorization** | Razlaganje matrice interakcija `R` na proizvod manjih matrica `P` (korisnici) i `Q` (tereni): `R ≈ P × Qᵀ`. Skor kandidata je skalarni proizvod `score(u, t) = p_u · q_t`. |
| **Afinitet** | Zbir dva broja: koliko je puta korisnik rezervisao teren tog sporta i koliko puta teren u tom gradu; koristi se za poredak dopunskih preporuka. |
| **Hladni start** | Situacija u kojoj model ne poznaje korisnika (nema historije) ili je podataka premalo za treniranje. |

---

## 3. Konfiguracija

Parametri sistema su fiksne vrijednosti u kodu (konstante i `static readonly` polja u `RecommenderService`; interval re-treniranja u `RecommenderTrainingService`; `count` je parametar endpointa):

| Parametar | Vrijednost | Opis |
|---|---|---|
| `ReservationUnits` | `5` | Koliko jedinica signala nosi jedna rezervacija. |
| `ViewUnits` | `1` | Koliko jedinica nosi jedan pregled detalja terena. |
| `MaxViewUnitsPerPair` | `3` | Gornja granica doprinosa pregleda po paru (korisnik, teren). |
| `MaxUnitsPerPair` | `50` | Gornja granica ukupnog signala po paru. |
| `MinInteractions` | `6` | Minimalan broj interakcija (parova) za treniranje. |
| `MinDistinctUsers` | `2` | Minimalan broj različitih korisnika. |
| `MinDistinctCourts` | `2` | Minimalan broj različitih terena. |
| `count` (API parametar) | `3` (raspon 1–10) | Broj preporuka koje endpoint vraća; vrijednost izvan raspona svodi se na najbližu granicu. |
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
   uspješnom treniranju, odnosno u modelu učitanom s diska), modelom se skoruju kandidati koje je
   model vidio pri treniranju; novododani teren nema skor i može ući samo kroz dopunu. Kandidati
   se sortiraju silazno po skoru i uzima se top `count`, uz objašnjenje
   _„Korisnici sa sličnim rezervacijama često biraju ovaj teren."_ Model poznaje i korisnika
   koji ima samo preglede terena (bez rezervacija), pa i on može dobiti ovu preporuku.

3. **Dopuna popularnošću, poredana po ukusu korisnika**
   Ako kolaborativni dio nije dao dovoljno preporuka (model nije istreniran, korisnik je
   nepoznat ili je kandidata premalo), lista se dopunjava terenima rezervisanim u
   **zadnjih 30 dana**. Broje se sve neotkazane rezervacije (na čekanju, potvrđene i završene)
   prema datumu kreiranja rezervacije, ne prema datumu termina.

   Redoslijed te dopune nije samo popularnost. Iz historije rezervacija korisnika izračuna se
   **afinitet** – koliko je puta rezervisao taj sport i koliko puta u tom gradu – pa se
   kandidati sortiraju prvo po afinitetu, a tek onda po broju rezervacija. Pri jednakom
   afinitetu i broju rezervacija prednost ima teren s manjim ID-jem.

   Objašnjenje prati stvarni razlog izbora i imenuje samo ono što se stvarno poklapa:
   _„Popularan teren u sportu i gradu koje inače birate."_ kad se poklapaju oboje,
   _„Popularan teren u sportu koji inače birate."_ odnosno _„Popularan teren u gradu u kojem
   inače igrate."_ kad se poklapa jedno. Kad afiniteta nema (korisnik nema historije, ili je
   teren iz drugog sporta i grada), objašnjenje je _„Najpopularniji teren u zadnjih 30 dana."_
   samo za aktivni teren s najviše rezervacija u tom periodu, a za sve ostale
   _„Popularan teren u zadnjih 30 dana."_ Najpopularniji teren se određuje među svim aktivnim
   terenima (pri jednakom broju rezervacija onaj s manjim ID-jem); ako ga je korisnik već
   rezervisao, nijedna preporuka ne nosi to objašnjenje.

4. **Preostali aktivni tereni**
   Ako ni popularnost ne popuni listu (npr. potpuno svježa baza bez ijedne rezervacije),
   dodaju se preostali aktivni tereni, također poredani po afinitetu, uz generičko
   objašnjenje _„Predloženo za tebe."_

5. **Omiljeni tereni korisnika**
   Korisnik koji je već rezervisao svaki aktivni teren (rezervacijom koja nije otkazana, bez obzira
   na to je li termin odigran) nema nijednog novog kandidata. Umjesto prazne
   sekcije, lista se popunjava njegovim **najčešće rezervisanim** terenima, uz objašnjenje
   _„Često rezervišete ovaj teren."_ Ovaj sloj se aktivira **samo kad prethodna tri nisu dala
   nijednu preporuku** – već rezervisan teren nikad ne istiskuje teren koji korisnik još nije
   probao, pa korisnik s jednim nerezervisanim terenom dobija tačno jednu preporuku. To je i
   jedini sloj koji smije predložiti teren koji je korisnik već rezervisao.

Svaka preporuka nosi i podatke za prikaz (naziv, sport, centar, cijena, ID slike) te skor, pa
kartica preporuke u mobilnoj aplikaciji ne traži dodatne pozive; tek ekran detalja otvoren iz
preporuke dohvaća puni zapis terena (npr. radno vrijeme). Skor je zaokružen na četiri decimale za
kolaborativne preporuke, a za sve dopunske iznosi 0; mobilna aplikacija skor ne prikazuje, nego
objašnjenje. Server objašnjenja vraća na bosanskom, a mobilna aplikacija ih prevodi na engleski
kad je odabran engleski jezik.

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
              DA ──► dopuni najpopularnijim (zadnjih 30 dana),
              │      poredanim po afinitetu (sport + grad korisnika)
              ▼
          I dalje manje od N?
              DA ──► dopuni preostalim aktivnim terenima (isti poredak)
              │
              ▼
          Lista je i dalje PRAZNA (korisnik je rezervisao sve)?
              DA ──► popuni njegovim najčešće rezervisanim terenima
              │
              ▼
          Vrati listu preporuka s objašnjenjima
```

---

## 5. Treniranje modela (`TrainAsync`)

**Implementacija:** `RecommenderService.TrainAsync()`

1. **Prikupljanje i vaganje interakcija**
   Iz baze se učitaju parovi (klijent, teren) iz svih neotkazanih rezervacija, zatim parovi
   (korisnik, teren) iz zapisa o pregledima terena (`CourtViewLog`). Sve što se odnosi na
   **isti par (korisnik, teren) sabira se u jedinice signala**:

   | Signal | Jedinica | Ograničenje |
   |---|---|---|
   | rezervacija | **5** po rezervaciji | bez posebnog ograničenja |
   | pregled detalja terena | **1** po pregledu | najviše **3** po paru |
   | ukupno po paru (korisnik, teren) | zbir gornja dva | najviše **50** jedinica |

   Jedna rezervacija tako uvijek nadjačava koliko god pregleda istog terena. U treniranje ulaze
   sve neotkazane rezervacije i svi pregledi, bez vremenskog ograničenja; svako otvaranje detalja
   terena upisuje novi zapis, a ograničenje od 3 jedinice po paru primjenjuje se pri treniranju.

   **Zašto ponavljanje, a ne broj u `Label`:** one-class Matrix Factorization po definiciji
   tretira svaku **opaženu** ćeliju matrice jednako (vrijednost 1), a `Alpha` i `C` opisuju samo
   neopažene ćelije. Vrijednost upisana u `Label` zato ne bi imala nikakav učinak. Jačina se
   izražava tako što par ulazi u matricu onoliko puta koliko ima jedinica – svaki dodatni unos
   povećava doprinos tog para funkciji gubitka. (ML.NET dokumentacija za
   `MatrixFactorizationTrainer`: one-class varijanta radi s tim da su sve opažene vrijednosti 1.
   Provjereno i na ML.NET 0.23.0 s parametrima iz sekcije 3: `Label` 5 umjesto 1 daje iste skorove,
   a par ponovljen pet puta mijenja skorove.)

2. **Provjera pragova**
   Ako je interakcija manje od `MinInteractions`, ili je korisnika/terena manje od minimuma,
   treniranje se preskače (matrica bi bila prerijetka): ako model još ne postoji, sistem ostaje
   na popularnosti, a ako postoji ranije istreniran ili s diska učitan model, on ostaje u upotrebi.

3. **Pipeline**
   ID korisnika i terena se mapiraju u ključeve (`MapValueToKey`), pa se trenira
   `MatrixFactorizationTrainer` s parametrima iz sekcije 3.

4. **Objava i perzistencija**
   Novi model atomarno zamjenjuje stari u memorijskom kešu (singleton `IRecommenderModel`,
   zaštićen lock-om – API zahtjevi skoruju bez prekida i tokom re-treniranja). Model se
   zatim snima na disk (`models/recommender.zip` + sidecar `.ids` sa spiskom poznatih
   korisnika i terena, potreban za ispravno učitavanje poslije restarta). Ako snimanje na disk ne
   uspije, greška se loguje kao upozorenje, a novi model ostaje u upotrebi u memoriji. U Docker
   okruženju datoteka modela nije na trajnom volumenu, pa se poslije ponovnog kreiranja kontejnera
   model gradi treningom pri startu.

---

## 6. Životni ciklus modela (`RecommenderTrainingService`)

Pozadinski servis (`BackgroundService`) upravlja modelom kroz cijeli život aplikacije:

1. **Warm start** – pri pokretanju API-ja pokuša učitati sačuvani model s diska, pa preporuke
   rade odmah, bez čekanja prvog treniranja.
2. **Treniranje pri startu** – odmah zatim trenira model nad aktuelnim podacima.
3. **Periodično re-treniranje** – ponavlja treniranje svakih 6 sati (računato od završetka
   prethodnog treniranja), čime nove rezervacije i pregledi ulaze u model bez ikakve ručne
   intervencije.
4. **Ručno re-treniranje** – administrator može pokrenuti trening odmah, endpointom iz sekcije 7.
   Endpoint vraća 204 i kad je treniranje preskočeno zbog premalo podataka (to se vidi samo u
   logu); greška pri ručnom treniranju vraća 500 i loguje se, a stari model ostaje u upotrebi.
   Desktop aplikacija nema dugme za ovo – endpoint se poziva direktno preko API-ja (npr. Swagger).

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
- **Sadržajni atributi samo u dopuni:** sam Matrix Factorization uči isključivo iz obrazaca
  korištenja – sport, grad i cijena nisu njegov ulaz. Sport i grad ulaze tek u poredak
  dopunskih preporuka (sekcija 4, koraci 3 i 4): kandidati se prvo poredaju po afinitetu
  (sport i grad korisnika), a tek među jednako bliskim terenima odlučuje popularnost.
- **Nepoznati korisnici i tereni:** model može skorovati samo korisnike i terene koje je
  vidio pri treniranju. Novi korisnici dobijaju popularnost do prvog sljedećeg treninga
  nakon njihove prve interakcije; isto vrijedi za novododane terene.
- **Obrada u memoriji:** sve interakcije se učitavaju u memoriju pri treniranju. Za očekivani
  obim ovog sistema (stotine korisnika, desetine terena) to je ispravan izbor; kod višestruko
  većih podataka trening bi trebalo premjestiti u izdvojeni posao.
- **Native zavisnost:** ML.NET Matrix Factorization zahtijeva `libgomp1` (OpenMP) u Linux
  kontejneru – instalirana je u runtime sloju `CourtSide.Api/Dockerfile`.
