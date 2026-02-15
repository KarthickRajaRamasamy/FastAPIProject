from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional
from database import SessionLocal, engine, get_db
from datetime import datetime
from models import Base, Task

# Create the database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Task Tracker API")

#pydantic schemas
class TaskCreate(BaseModel):
    username: str
    taskassigned: str | None = None

class TaskResponse(BaseModel):
    id: int
    username: str
    taskassigned: str
    completed: bool
    created_at: datetime

    class Config:
        from_attributes =  True

#endpoint update
@app.post("/tasks", response_model=TaskResponse)
def create_task(task: TaskCreate, db: Session = Depends(get_db)):
    db_task = Task(**task.dict())
    db.add(db_task)
    db.commit()
    db.refresh(db_task)
    return db_task

@app.get("/tasks", response_model=list[TaskResponse])
def get_tasks(db: Session = Depends(get_db)):
    return db.query(Task).all()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)