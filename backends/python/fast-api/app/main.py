"""FastAPI with async SQLAlchemy over asyncpg, served by uvicorn workers."""
import os
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Response
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

WORKERS = int(os.getenv("BENCH_CPUS", "1"))
DATABASE_URL = "postgresql+asyncpg://{u}:{p}@{h}:{port}/{db}".format(
    u=os.getenv("DATABASE_USER", "postgres"),
    p=os.getenv("DATABASE_PASSWORD", "postgres"),
    h=os.getenv("DATABASE_HOST", "db"),
    port=os.getenv("DATABASE_PORT", "5432"),
    db=os.getenv("DATABASE_NAME", "postgres"),
)

# 20 connections in total, split across workers (same budget as other backends).
engine = create_async_engine(DATABASE_URL, pool_size=max(1, 20 // WORKERS), max_overflow=0)
Session = async_sessionmaker(engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


class Note(Base):
    __tablename__ = "note"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str]
    content: Mapped[str]


class NoteIn(BaseModel):
    title: str
    content: str


class NoteOut(NoteIn):
    id: int


async def get_session():
    async with Session() as session:
        yield session


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await engine.dispose()


app = FastAPI(lifespan=lifespan)


@app.get("/health")
async def health():
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    except Exception as e:  # noqa: BLE001 - report any DB error as not ready
        return Response(f"not ready: {e}", status_code=503)
    return Response("ok")


@app.get("/no_db_endpoint/")
async def no_db_endpoint():
    return {"message": "No db endpoint"}


@app.get("/notes/", response_model=list[NoteOut])
async def list_notes(limit: int = 20, offset: int = 0, session: AsyncSession = Depends(get_session)):
    rows = await session.scalars(select(Note).order_by(Note.id).limit(max(limit, 0)).offset(max(offset, 0)))
    return [NoteOut(id=n.id, title=n.title, content=n.content) for n in rows]


@app.get("/notes/{note_id}", response_model=NoteOut)
async def get_note(note_id: int, session: AsyncSession = Depends(get_session)):
    note = await session.get(Note, note_id)
    if note is None:
        raise HTTPException(status_code=404, detail="not found")
    return NoteOut(id=note.id, title=note.title, content=note.content)


@app.post("/notes/", response_model=NoteOut, status_code=201)
async def create_note(body: NoteIn, session: AsyncSession = Depends(get_session)):
    note = Note(title=body.title, content=body.content)
    session.add(note)
    await session.commit()
    return NoteOut(id=note.id, title=note.title, content=note.content)
