BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "serverpod_session_log" ADD COLUMN "userId" text;
CREATE INDEX "serverpod_session_log_time_idx" ON "serverpod_session_log" USING btree ("time");

--
-- MIGRATION VERSION FOR benchmark
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('benchmark', '20260215190031443', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260215190031443', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
