import os
from pathlib import Path
import sqlite3
from dotenv import find_dotenv, load_dotenv

# Auto-locate and load the .env file
load_dotenv(find_dotenv())

from langchain_core.messages import SystemMessage
from langchain_google_genai import ChatGoogleGenerativeAI
from langgraph.checkpoint.sqlite import SqliteSaver
from langgraph.graph import START, MessagesState, StateGraph
from langgraph.prebuilt import ToolNode, tools_condition

# Relative import for modules in the same directory
from tool import tools  

Path("data").mkdir(exist_ok=True)

# Set valid default model and allowed models
DEFAULT_MODEL = os.getenv("GEMINI_MODEL", "gemini-3.8-flash")

ALLOWED_MODELS = {
# Primary default for software engineering, multi-step agent loops, & reasoning
    "gemini-3.8-flash",

    # Top reasoning model for complex architecture, STEM, & deep planning
    "gemini-3.1-pro",

    # High-speed GA fallback for balanced latency & everyday generation
    "gemini-3.7-flash",

    # Ultra-low-latency, budget-friendly tier for extraction & classification
    "gemini-3.5-flash-lite",
}

SYSTEM_PROMPT = """
You are a helpful Agentic AI assistant.

You can:
1. Answer normal questions.
2. Use a calculator for math.
3. Remember important user information using the memory tool.
4. Recall memory when useful.
5. Search the web for latest/current information using web_search.

Rules:
- If the user asks about latest news, current events, recent updates, today's information, current prices, current people, current versions, or anything time-sensitive, use web_search.
- If the user asks you to remember something, use remember_this.
- If the user asks about previous preferences or saved facts, use recall_memory.
- Use calculator for math questions.
- When using web search, summarize clearly and mention that the answer is based on web search results.
- Be clear, helpful, and concise.

- If the user asks about an uploaded document or file, call search_uploaded_documents and answer ONLY from what it returns.
- If the retrieved chunks contain conflicting values, mention both and say the documents conflict. Do not pick one.
- Never invent information that is not in the retrieved text.
- If nothing relevant is found, say: "I am unable to answer this question based on the provided documents."

"""

def normalize_model_name(model_name : str | None)-> str:
    if not model_name:
        return DEFAULT_MODEL
    model_name = model_name.strip()
    if model_name not in ALLOWED_MODELS:
        return DEFAULT_MODEL
    return model_name

def build_agent(model_name :  str):
    selected_model = normalize_model_name(model_name)

    llm = ChatGoogleGenerativeAI(
        model = selected_model, 
        temperature = 0.3,
        streaming = True 
    )

    llm_with_tools = llm.bind_tools(tools)

    def chatbot_node(state: MessagesState):
        messages = [SystemMessage(content = SYSTEM_PROMPT)] + state["messages"]
        response = llm_with_tools.invoke(messages)
        return {"messages" : [response]}

    tool_node = ToolNode(tools)

    workflow =StateGraph(MessagesState)
    workflow.add_node("chatbot", chatbot_node)
    workflow.add_node("tools", tool_node)

    workflow.add_edge(START , "chatbot")
    workflow.add_conditional_edges('chatbot' , tools_condition)
    workflow.add_edge("tools" , "chatbot")

    conn = sqlite3.connect("data/langgraph_checkpoints.sqlite" , check_same_thread= False)
    checkpointer = SqliteSaver(conn)

    return workflow.compile(checkpointer = checkpointer)

_AGENT_CACHE = {}

def get_agent(model_name : str | None = None):
    selected_model = normalize_model_name(model_name)
    if selected_model not in _AGENT_CACHE:
        _AGENT_CACHE[selected_model] = build_agent(selected_model)
    return _AGENT_CACHE[selected_model]