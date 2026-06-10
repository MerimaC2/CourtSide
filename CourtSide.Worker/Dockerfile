# Build
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY . .
RUN dotnet restore CourtSide.Worker/CourtSide.Worker.csproj
RUN dotnet publish CourtSide.Worker/CourtSide.Worker.csproj -c Release -o /app/publish /p:UseAppHost=false

# Runtime (aspnet base: CourtSide.Shared references Microsoft.AspNetCore.App for SignalR types)
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "CourtSide.Worker.dll"]
