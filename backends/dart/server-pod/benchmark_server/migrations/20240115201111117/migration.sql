BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "note" (
    "id" serial PRIMARY KEY,
    "title" text NOT NULL,
    "content" text NOT NULL
);


--
-- MIGRATION VERSION FOR benchmark
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('benchmark', '20240115201111117', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20240115201111117', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20240115074235544', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20240115074235544', "timestamp" = now();


COMMIT;
