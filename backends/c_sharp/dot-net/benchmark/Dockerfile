FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

WORKDIR /app

# Copy csproj and restore as distinct layers
COPY *.csproj ./

RUN dotnet restore

# Copy everything else and build
COPY . ./

RUN dotnet publish -c Release -o out

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime

WORKDIR /app
# Install curl
RUN apt-get update && apt-get install -y curl

COPY --from=build /app/out ./

ENTRYPOINT ["dotnet", "csharp-crud-api.dll"]