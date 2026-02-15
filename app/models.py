from sqlalchemy import Column, Integer, String, Boolean, DateTime
from datetime import datetime, timezone
from database import Base

class Task(Base):
    __tablename__ = "tasks"
    id = Column(Integer, primary_key=True, index=True) #ID for DB indexing
    #title = Column(String, index=True)
    username = Column(String, index=True, nullable=False)
    taskassigned = Column(String, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    completed = Column(Boolean, default=False)