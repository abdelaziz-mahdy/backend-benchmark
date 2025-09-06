BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "note" (
    "id" bigserial PRIMARY KEY,
    "title" text NOT NULL,
    "content" text NOT NULL
);


--
-- MIGRATION VERSION FOR benchmark
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('benchmark', '20250901234818398', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20250901234818398', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20240516151843329', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20240516151843329', "timestamp" = now();


COMMIT;
