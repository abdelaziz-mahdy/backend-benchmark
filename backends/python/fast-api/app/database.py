import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

DATABASE_URL = f"postgresql://{os.getenv('DATABASE_USER')}:{os.getenv('DATABASE_PASSWORD')}@{os.getenv('DATABASE_HOST')}:5432/{os.getenv('DATABASE_NAME')}"

engine = create_engine(
    DATABASE_URL,
    pool_size=20,  # Increase pool size
    max_overflow=30,  # Increase overflow limit
    pool_timeout=30,  # Set pool timeout
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()
