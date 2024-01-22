# Use the official Dart image
FROM dart:3.0 AS build

# Set the working directory
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . .

# Get all the dependencies
RUN dart pub get

RUN dart pub global activate serverpod_cli

# Compile to native code for faster startup and performance
RUN dart compile exe bin/main.dart -o bin/main

# Set environment variables
ENV runmode=development
ENV serverid=default
ENV logging=normal
ENV role=monolith

# # Copy the necessary files from the build stage
# COPY --from=build /runtime/ /
# COPY --from=build /app/bin/main /app/bin/main
# COPY --from=build /app/config/ config/
# # COPY --from=build /app/generated/ generated/
# COPY --from=build /app/web/ web/

# Expose the necessary ports
EXPOSE 8080
EXPOSE 8081
EXPOSE 8082

# Command to run the application
CMD    dart bin/main.dart --apply-migrations && bin/main --mode $runmode --server-id $serverid --logging $logging --role $role