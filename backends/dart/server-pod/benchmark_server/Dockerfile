FROM dart:3.2.5 AS build

WORKDIR /app
COPY . .

RUN dart pub get
RUN dart compile exe bin/main.dart -o bin/server

FROM alpine:latest

# Install curl in the final image
RUN apk add --no-cache curl

ENV runmode=development
ENV serverid=default
ENV logging=normal
ENV role=monolith

COPY --from=build /runtime/ /
COPY --from=build /app/bin/server server
COPY --from=build /app/config/ config/
COPY --from=build /app/web/ web/
COPY --from=build /app/migrations/ migrations/

EXPOSE 8000
EXPOSE 8081
EXPOSE 8082

CMD ./server --apply-migrations &&  ./server --mode=$runmode --server-id=$serverid --logging=$logging --role=$role
