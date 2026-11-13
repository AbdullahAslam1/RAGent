import os 
import certifi
os.environ["SSL_CERT_FILE"] = certifi.where()
os.environ["REQUESTS_CA_BUNDLE"] = certifi.where()

from dotenv import load_dotenv , find_dotenv
load_dotenv(find_dotenv())

import json
import uuid
from pathlib import Path

import uvicorn
from fastapi import FastAPI , Request , UploadFile , File , Form
from fastapi.responses import StreamingResponse , JSONResponse
from fastapi.concurrency import run_in_threadpool

from langchain_core.messages import HumanMessage , AIMessage , AIMessageChunk , ToolMessage

from agent import get_agent
from database import (
    init_db, save_chat_messages, get_chat_history,
    create_or_update_conversation, list_conversation,
    rename_conversation, delete_conversation,
)
from rag import add_document_to_rag, delete_thread_documents, SUPPORTED_EXTENSIONS

from tool import set_current_thread_id
from fastapi.middleware.cors import CORSMiddleware 
from rag import add_document_to_rag, SUPPORTED_EXTENSIONS


app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

Path("data").mkdir(exist_ok=True)
Path("uploads").mkdir(exist_ok=True)

MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB

init_db()

@app.get("/health")
async def health():
    return {"status" : 'ok'}


@app.get("/conversations")
async def conversations():
    items = list_conversation()
    return {
        "conversations": [
            {
                "thread_id": item.thread_id,
                "title": item.title,
                "created_at" : item.created_at.isoformat(),
                "updated_at" : item.updated_at.isoformat(),   
            }
            for item in items
        ]
    }


@app.get("/history/{thread_id}")
async def history(thread_id : str):
    messages = get_chat_history(thread_id)
    return {
        "messages" : [
            {"role": msg.role, "content" : msg.content}
            for msg in messages
        ]
    }

@app.post("/upload")
async def upload_document(
    file: UploadFile = File(...),
    thread_id: str = Form(...),
):
    filename = file.filename or "uploaded_file"
    suffix = Path(filename).suffix.lower()

    if suffix not in SUPPORTED_EXTENSIONS:
        return JSONResponse(
            {"success": False, "message": "Unsupported file type. Upload a PDF or TXT file."},
            status_code=400,
        )

    content = await file.read()

    if len(content) > MAX_UPLOAD_BYTES:
        return JSONResponse(
            {"success": False, "message": "File too large (max 10 MB)."},
            status_code=400,
        )

    # Path(...).name strips any folder parts from the client's filename
    safe_name = Path(filename).name.replace(" ", "_")
    file_path = f"uploads/{uuid.uuid4()}_{safe_name}"

    with open(file_path, "wb") as f:
        f.write(content)

    try:
        create_or_update_conversation(thread_id, f"Document: {safe_name}")
        # Embedding is slow, so run it off the main event loop
        save_chat_messages(thread_id, "system", f"Uploaded document: {safe_name}")
        result = await run_in_threadpool(add_document_to_rag, file_path, thread_id, safe_name)
        return {
            "success": True,
            "message": f"Uploaded {safe_name} and created {result['chunks']} chunks.",
        }
    except Exception as e:
        return JSONResponse({"success": False, "message": str(e)}, status_code=500)

@app.patch("/conversations/{thread_id}")
async def rename(thread_id: str, request: Request):
    try:
        data = await request.json()
    except Exception:
        return JSONResponse({"error": "Invalid JSON body."}, status_code=400)

    title = (data.get("title") or "").strip()
    if not title:
        return JSONResponse({"error": "Title is required."}, status_code=400)

    if not rename_conversation(thread_id, title):
        return JSONResponse({"error": "Conversation not found."}, status_code=404)
    return {"success": True}


@app.delete("/conversations/{thread_id}")
async def delete(thread_id: str):
    found = delete_conversation(thread_id)

    try:
        await run_in_threadpool(delete_thread_documents, thread_id)
    except Exception:
        pass  # a vector-store cleanup problem shouldn't block deleting the chat

    if not found:
        return JSONResponse({"error": "Conversation not found."}, status_code=404)
    return {"success": True}


def sse_data(payload: dict) -> str:
    return f"data: {json.dumps(payload , ensure_ascii=False)}\n\n" 


def should_stream_chunk(chunk , metadata) -> bool:
    metadata = metadata or {}
    node_name = str(metadata.get("langgraph_node", "")).lower()

# Block tool node outputs
    if "tool" in node_name:
        return False

    # Block Tool Messages
    if isinstance(chunk, ToolMessage):
        return False

    # Allow only AI-generated text messages
    if not isinstance(chunk, (AIMessage, AIMessageChunk)):
        return False

    # Block valid or invalid tool calls (Fixed typo: tool_calls)
    if getattr(chunk, "tool_calls", None) or getattr(chunk, "invalid_tool_calls", None):
        return False

    # Safely check additional_kwargs for raw tool calls (Fixed operator evaluation)
    additional_kwargs = getattr(chunk, "additional_kwargs", {}) or {}
    if additional_kwargs.get("tool_calls"):
        return False

    return True 


def extract_text_from_chunk(chunk) -> str:
    content = getattr(chunk , "content", "")
    if not content:
        return ""
    if isinstance(content , str):
        return content
    if isinstance(content , list):
        parts = []
        for item in content:
            if isinstance(item , str):
                parts.append(item)
            elif isinstance(item , dict):
                    if isinstance(item.get("text"), str):
                        parts.append(item["text"])

        return "".join(parts)

    return ""


@app.post("/chat/stream")
async def chat_stream(request: Request):
    try:
        data = await request.json()
    except Exception:
        return JSONResponse({"error": "Invalid JSON body."}, status_code=400)

    user_message = data.get("message", "")
    thread_id = data.get("thread_id", "default")
    selected_model = data.get("model", "gemini-3.8-flash")  # Fixed typo: model

    if not user_message.strip():
        return JSONResponse({"error": "Message is required."}, status_code=400)

    agent = get_agent(selected_model)

    create_or_update_conversation(thread_id, user_message)
    save_chat_messages(thread_id, "user", user_message)

    set_current_thread_id(thread_id)

    config = {"configurable": {"thread_id": thread_id}}

    def event_generator():
        final_answer = ""
        try:
            inputs = {"messages": [HumanMessage(content=user_message)]}

            for chunks, metadata in agent.stream(inputs, config=config, stream_mode="messages"):
                if not should_stream_chunk(chunks, metadata):
                    continue

                token = extract_text_from_chunk(chunks)
                if token:
                    final_answer += token
                    yield sse_data({"token": token})

            # Save and complete OUTSIDE the streaming loop
            if final_answer.strip():
                save_chat_messages(thread_id, "assistant", final_answer)

            yield sse_data({"done": True})

        except Exception as e:
            yield sse_data({"error": str(e)})
            yield sse_data({"done": True})

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )

if __name__ == "__main__":
    uvicorn.run("app:app" , host="0.0.0.0", port = 8080 , reload=True)


    