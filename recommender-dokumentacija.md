# Sistem preporuke — dokumentacija (CourtSide)

> Status: implementirano. Kod prati ovu dokumentaciju (`CourtSide.Services/Recommender`).

## Pristup

CourtSide koristi **kolaborativno filtriranje (collaborative filtering)** zasnovano na
**ML.NET Matrix Factorization** algoritmu nad **implicitnim signalima** iz stvarne historije
korištenja (rezervacije + pregledi terena).

> Napomena: prijava teme u sekciji „Ciljevi" spominje „content-based"; mjerodavna je detaljna
> sekcija 6 prijave (collaborative filtering). Ova dokumentacija i implementacija prate sekciju 6.

## Signali (stvarno upisivani podaci)

- **Rezervacije** (`Reservation`) — primarni implicitni signal interesa korisnika za teren.
- **Pregledi terena** (`CourtViewLog`) — dopunski implicitni signal (historija pregleda).

Svi navedeni signali se zaista upisuju u bazu prilikom korištenja aplikacije i koriste se u modelu
(ne prikupljaju se podaci koji se zatim ignorišu).

## Algoritam

1. Iz historije se gradi matrica interakcija korisnik–teren.
2. `MatrixFactorizationTrainer` (implicit / one-class) uči latentne faktore.
3. Za prijavljenog korisnika model predviđa skor za terene koje korisnik **nije** ranije rezervisao.
4. Vraća se top **2–3** terena (sekcija „Preporučeno" na početnom ekranu mobilne app).

## Fallback (hladni start)

Ako korisnik nema dovoljno historije, prikazuju se **najpopularniji tereni u zadnjih 30 dana**
(po broju rezervacija).

## Objašnjive preporuke

Uz svaku preporuku vraća se objašnjenje, npr.:
- „Korisnici sa sličnim rezervacijama često biraju ovaj teren" (MF preporuka), ili
- „Najpopularniji teren u zadnjih 30 dana" (fallback).

## Upravljanje modelom

- Treniranje modela + perzistencija (sačuvani model fajl) + cache u memoriji.
- Periodični re-train kroz `IHostedService` / pozadinski posao.

## Implementacija

| Element | Detalj |
|---|---|
| Kod | `CourtSide.Services/Recommender/` (`RecommenderModel`, `RecommenderService`, `RecommenderTrainingService`) |
| Algoritam | ML.NET `MatrixFactorizationTrainer`, `LossFunctionType.SquareLossOneClass` (implicit/one-class) |
| Parametri | `ApproximationRank=32`, `NumberOfIterations=100`, `Lambda=0.025`, `Alpha=0.01`, `C=0.00001` |
| Signali | `Reservation` (status ≠ Cancelled) + `CourtViewLog`; svaka interakcija = pozitivan signal (`Label=1`) |
| Prag za treniranje | ≥ 6 interakcija, ≥ 2 korisnika, ≥ 2 terena; ispod toga samo fallback (popularnost) |
| Keš + perzistencija | singleton `IRecommenderModel` u memoriji; model `models/recommender.zip` + `*.ids` sidecar |
| Re-train | `RecommenderTrainingService` (BackgroundService): warm-load s diska na startu, trening na startu, pa svakih 6h |
| API | `GET /api/recommendations?count=3` (prijavljeni korisnik); `POST /api/courts/{id}/view` (log pregleda); `POST /api/recommendations/retrain` (admin, ručni re-train) |
| Izuzimanje | preporuke ne uključuju terene koje je korisnik već rezervisao |

> Native zavisnost: ML.NET MF traži `libgomp1` (OpenMP) — instalirana u runtime sloju `CourtSide.Api/Dockerfile`.
