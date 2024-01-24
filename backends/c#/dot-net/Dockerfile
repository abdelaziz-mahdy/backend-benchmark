FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build

WORKDIR /app

# Copy csproj and restore as distinct layers
COPY *.csproj ./

RUN dotnet restore

# Copy everything else and build
COPY . ./

RUN dotnet publish -c Release -o out
RUN dotnet ef database update

FROM mcr.microsoft.com/dotnet/aspnet:7.0 AS runtime

WORKDIR /app

COPY --from=build /app/out ./

# ENTRYPOINT ["dotnet", "csharp-crud-api.dll"]

# Copy the entrypoint script
COPY entrypoint.sh ./

# Give execute permission to the entrypoint script
RUN chmod +x entrypoint.sh

# Define the entrypoint script as the entrypoint of the container
ENTRYPOINT ["./entrypoint.sh"]