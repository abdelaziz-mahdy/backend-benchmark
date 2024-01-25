

docker run -it --rm -v $(pwd)/:/app -w /app mcr.microsoft.com/dotnet/sdk:8.0 /bin/bash -c "dotnet tool install --global dotnet-ef; export PATH=\"$PATH:/root/.dotnet/tools\"; dotnet ef migrations add AutoMigrations --context NoteContext --output-dir Migrations"
