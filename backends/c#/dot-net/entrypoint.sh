#!/bin/bash

# Install dotnet-ef tool globally
echo "Installing dotnet-ef tool..."
dotnet tool install --global dotnet-ef

# Ensure the dotnet-ef tool is installed
if dotnet-ef --version; then

    # Ensure the database is up-to-date
    echo "Checking database migrations..."
    dotnet ef migrations add AutoMigrations --context NoteContext --output-dir Migrations
    dotnet ef database update --context NoteContext

    # Start the application
    echo "Starting application..."
    exec dotnet csharp-crud-api.dll

else
    echo "Failed to install dotnet-ef tool. Cannot proceed with migrations."
    exit 1
fi


