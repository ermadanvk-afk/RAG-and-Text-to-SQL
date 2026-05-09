import os
import sqlite3
from dotenv import load_dotenv
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import PromptTemplate

# Naya import! Hum apne naye script se function laa rahe hain
from get_schema import get_full_schema 

# Load the API Key
load_dotenv()

def clean_sql(raw_sql: str) -> str:
    """Defensive Programming: Removes markdown formatting from the LLM output."""
    cleaned = raw_sql.replace("```sqlite", "").replace("```sql", "").replace("```", "").strip()
    return cleaned

def execute_sql(db_path: str, query: str):
    """Connects to SQLite, runs the query, and fetches the results."""
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute(query)
        results = cursor.fetchall()
        conn.close()
        return results
    except sqlite3.Error as e:
        return f"Database error: {e}"

def generate_and_run_sql(user_question: str):
    llm = ChatGoogleGenerativeAI(model="gemini-2.5-flash", temperature=0)

    # --- DYNAMIC SCHEMA EXTRACTION ---
    print("Fetching live database schema...")
    db_schema = get_full_schema("setup.db")

    # The Robust Text-to-SQL Prompt (Few-Shot Version)
    prompt_template = """You are an expert SQLite developer. 
    Based on the following database schema, write a valid SQLite query that answers the user's question.

    CRITICAL ENGINEERING RULES FOR MESSY DATA:
    1. Inconsistent Casing: You MUST use LOWER() when comparing string values in WHERE clauses. 
    2. Missing/Orphaned References: Always use LEFT JOIN instead of INNER JOIN.

    Schema:
    {schema}

    Example Question: How many open tickets are there?
    Example SQL: SELECT COUNT(ticket_id) FROM tickets WHERE LOWER(status) = 'open';

    Question: {question}

    SQL Query:"""

    prompt = PromptTemplate.from_template(prompt_template)
    chain = prompt | llm
    
    print(f"User Question: {user_question}")
    print("Thinking... Generating SQL...")
    
    response = chain.invoke({"schema": db_schema, "question": user_question})
    raw_sql = response.content
    
    clean_query = clean_sql(raw_sql)
    print(f"\n--- CLEANED SQL ---")
    print(clean_query)
    
    print(f"\n--- REAL DATABASE RESULT ---")
    db_result = execute_sql("setup.db", clean_query)
    print(db_result)

if __name__ == "__main__":
    # Test it with a table that wasn't in our hardcoded schema before!
    generate_and_run_sql("How many organizations are there in the database?")