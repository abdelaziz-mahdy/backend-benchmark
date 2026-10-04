FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY *.csproj ./
RUN dotnet restore
COPY . ./
RUN dotnet publish -c Release -o /out --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
ENV DOTNET_gcServer=1 ASPNETCORE_ENVIRONMENT=Production
COPY --from=build /out ./
EXPOSE 8000
ENTRYPOINT ["dotnet", "csharp-crud-api.dll"]
