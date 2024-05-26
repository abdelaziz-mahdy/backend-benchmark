import uvicorn
from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from database import SessionLocal, engine
from fastapi.responses import PlainTextResponse

import crud, models, schemas

models.Base.metadata.create_all(bind=engine)

app = FastAPI()

# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.post("/api/notes/", response_model=schemas.Note)
def create_note(note: schemas.NoteCreate, db: Session = Depends(get_db)):
    return crud.create_note(db=db, note=note)

@app.get("/api/notes/", response_model=list[schemas.Note])
def read_notes(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    notes = crud.get_notes(db, skip=skip, limit=limit)
    return notes
@app.get("/", response_class=PlainTextResponse)
def read_root():
    return "notes api"
@app.get("/api/no_db_endpoint", response_class=PlainTextResponse)
async def no_db_endpoint():
    return "No db endpoint"

@app.get("/api/no_db_endpoint2", response_class=PlainTextResponse)
async def no_db_endpoint2():
    return "No db endpoint2"
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
