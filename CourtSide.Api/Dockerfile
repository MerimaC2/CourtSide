# Build
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY . .
RUN dotnet restore CourtSide.Api/CourtSide.Api.csproj
RUN dotnet publish CourtSide.Api/CourtSide.Api.csproj -c Release -o /app/publish /p:UseAppHost=false

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
# Native deps: libgomp1 (ML.NET Matrix Factorization / recommender), libfontconfig1 (SkiaSharp/QuestPDF reports).
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/publish .
EXPOSE 80
ENTRYPOINT ["dotnet", "CourtSide.Api.dll"]
