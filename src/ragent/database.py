from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import Text, create_engine, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, sessionmaker

Path("data").mkdir(exist_ok=True)

DATABASE_URL = "sqlite:///data/chatbot_memory.db"

engine = create_engine(
    DATABASE_URL, connect_args={"check_same_thread": False}
)

# Crucial: expire_on_commit=False allows reading object attributes after db.close()
SessionLocal = sessionmaker(
    bind=engine, autoflush=False, expire_on_commit=False
)


class Base(DeclarativeBase):
    pass


class Conversation(Base):
    __tablename__ = "conversation"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    thread_id: Mapped[str] = mapped_column(unique=True, index=True)
    title: Mapped[str] = mapped_column(default="New Chat")
    created_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )


class ChatMessages(Base):
    __tablename__ = "chat_messages"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    thread_id: Mapped[str] = mapped_column(index=True)
    role: Mapped[str]
    content: Mapped[str]
    created_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(timezone.utc)
    )


class LongTermMemory(Base):
    __tablename__ = "long_term_memory"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    thread_id: Mapped[str] = mapped_column(index=True)
    memory: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(timezone.utc)
    )

def init_db():
    Base.metadata.create_all(bind=engine)

def create_or_update_conversation(
    thread_id: str, first_message: str | None = None
):
    db = SessionLocal()
    try:
        conversation = (
            db.query(Conversation)
            .filter(Conversation.thread_id == thread_id)
            .first()
        )

        if not conversation:
            title = "New Chat"
            if first_message:
                cleaned_msg = first_message.strip()
                title = (
                    cleaned_msg[:40] + "..."
                    if len(cleaned_msg) > 40
                    else cleaned_msg
                )

            conversation = Conversation(thread_id=thread_id, title=title)
            db.add(conversation)
        else:
            conversation.updated_at = datetime.now(timezone.utc)

        db.commit()
    finally:
        db.close()


def save_chat_messages(thread_id: str, role: str, content: str):
    db = SessionLocal()
    try:
        db.add(ChatMessages(thread_id=thread_id, role=role, content=content))
        conversation = (
            db.query(Conversation)
            .filter(Conversation.thread_id == thread_id)
            .first()
        )
        if conversation:
            conversation.updated_at = datetime.now(timezone.utc)

        db.commit()
    finally:
        db.close()


def get_chat_history(thread_id: str):
    db = SessionLocal()
    try:
        return (
            db.query(ChatMessages)
            .filter(ChatMessages.thread_id == thread_id)
            .order_by(ChatMessages.created_at.asc())
            .all()
        )
    finally:
        db.close()


def list_conversation():
    db = SessionLocal()
    try:
        return (
            db.query(Conversation)
            .order_by(Conversation.updated_at.desc())
            .all()
        )
    finally:
        db.close()


def save_memory(thread_id: str, memory: str):
    db = SessionLocal()
    try:
        db.add(LongTermMemory(thread_id=thread_id, memory=memory))
        db.commit()
        return "Memory saved Successfully"
    finally:
        db.close()


def search_memory(thread_id: str, query: str | None = None):
    db = SessionLocal()
    try:
        q = db.query(LongTermMemory).filter(
            LongTermMemory.thread_id == thread_id
        )

        # Added filtering logic if query parameter is provided
        if query:
            q = q.filter(LongTermMemory.memory.contains(query))

        memories = q.order_by(LongTermMemory.created_at.desc()).limit(20).all()

        if not memories:
            return "No saved memory found"
        return "\n".join([f"- {m.memory}" for m in memories])
    finally:
        db.close()

def rename_conversation(thread_id: str, title: str) -> bool:
    db = SessionLocal()
    try:
        conversation = db.query(Conversation).filter(Conversation.thread_id == thread_id).first()
        if not conversation:
            return False
        conversation.title = title.strip()[:80]
        db.commit()
        return True
    finally:
        db.close()


def delete_conversation(thread_id: str) -> bool:
    db = SessionLocal()
    try:
        db.query(ChatMessages).filter(ChatMessages.thread_id == thread_id).delete()
        db.query(LongTermMemory).filter(LongTermMemory.thread_id == thread_id).delete()
        deleted = db.query(Conversation).filter(Conversation.thread_id == thread_id).delete()
        db.commit()
        return deleted > 0
    finally:
        db.close()