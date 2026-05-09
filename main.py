import sqlite3
from dotenv import load_dotenv
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import PromptTemplate
from langchain_community.vectorstores import Chroma
from langchain_huggingface import HuggingFaceEmbeddings
from get_schema import get_full_schema

# Load environment variables
load_dotenv()

# Initialize Global Tools
llm = ChatGoogleGenerativeAI(model="gemini-2.5-flash", temperature=0)
embeddings = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")
vector_store = Chroma(persist_directory="./chroma_db", embedding_function=embeddings)

def route_query(question: str) -> str:
    """The Brain: Decides where to send the user's question."""
    prompt = PromptTemplate.from_template("""You are a query routing AI.
    1. If the question asks about policies, SOPs, workflows, or text info, return ONLY: RAG
    2. If the question asks for counts, analytics, ticket statuses, or database metrics, return ONLY: SQL
    3. If the question requires BOTH looking up a policy AND checking database stats, return ONLY: HYBRID

    Question: {question}
    Route:""")
    
    chain = prompt | llm
    return chain.invoke({"question": question}).content.strip()

def run_rag(question: str):
    """The Document Reader: Searches markdown files."""
    print("\n[System] Route chosen: RAG (Searching Documents...)")
    docs = vector_store.similarity_search(question, k=3)
    context = "\n\n".join([doc.page_content for doc in docs])
    sources = set([doc.metadata.get('source', 'Unknown') for doc in docs])
    
    prompt = PromptTemplate.from_template("""You are an enterprise support assistant.
    Use the context below to answer the question. Use your reasoning to map ambiguous terms.
    If the answer is missing, state "I do not have enough information."
    
    Context: {context}
    Question: {question}
    Answer:""")
    
    chain = prompt | llm
    answer = chain.invoke({"context": context, "question": question}).content
    
    print("\n================ AI ANSWER ================")
    print(answer)
    print("\n================ SOURCES USED ================")
    for source in sources:
        print(f"- {source}")
    print("===========================================\n")

def run_sql(question: str):
    """The Database Queryer: Writes SQL, executes it, and translates the result to English."""
    print("\n[System] Route chosen: SQL (Querying Database...)")
    db_schema = get_full_schema("setup.db")
    
    # STEP 1: GENERATE THE SQL (The "Smart" Prompt)

    sql_prompt = PromptTemplate.from_template("""You are an expert SQLite developer. 
    Write a valid SQLite query based on the schema to answer the user's question.
    Return ONLY the raw SQL query. Do not include markdown formatting.
    
    CRITICAL RULES FOR THIS SPECIFIC SCHEMA:
    1. Inconsistent Casing: ALWAYS use LOWER() when comparing strings in WHERE clauses (e.g., LOWER(priority) = 'critical').
    2. Missing References: ALWAYS use LEFT JOIN when joining tables like users, tickets, or organizations.
    3. Deleted Data: Exclude placeholder/deleted orgs (e.g., WHERE LOWER(org_name) NOT LIKE '%deleted%').
    4. SLA Policies: The sla_policies table contains multiple rules for the same priority. If the user asks for a general SLA, default to the global policy by adding `WHERE org_id IS NULL`.

    Schema:
    {schema}
    
    Question: {question}
    SQL Query:""")
    
    sql_chain = sql_prompt | llm
    raw_sql = sql_chain.invoke({"schema": db_schema, "question": question}).content
    clean_query = raw_sql.replace("```sqlite", "").replace("```sql", "").replace("```", "").strip()
    
    # STEP 2: EXECUTE THE SQL

    try:
        conn = sqlite3.connect("setup.db")
        cursor = conn.cursor()
        cursor.execute(clean_query)
        raw_db_results = cursor.fetchall()
        conn.close()
        
        # STEP 3: TRANSLATE TO HUMAN LANGUAGE (The Final Polish)

        human_prompt = PromptTemplate.from_template("""You are an enterprise support assistant.
        A user asked a question, and we queried our SQL database to find the answer.
        
        User's Question: {question}
        Raw Database Result: {db_result}
        
        Translate the raw database result into a clear, professional, and concise human-readable sentence. 
        If the result is empty or 0, clearly state that there are none. Do not mention the SQL query or the database itself.
        
        Answer:""")
        
        human_chain = human_prompt | llm
        final_answer = human_chain.invoke({
            "question": question, 
            "db_result": str(raw_db_results)
        }).content
        
        print("\n================ AI ANSWER ================")
        print(final_answer)
        print("===========================================\n")
        
    except Exception as e:
        print(f"\n[Error] Database execution failed: {e}")


def run_hybrid(question: str):
    """The Multi-Tasker: Runs both pipelines."""
    print("\n[System] Route chosen: HYBRID (Running both systems...)")
    run_rag(question)
    run_sql(question)

def process_user_query(question: str):
    print(f"\nUser Asked: '{question}'")
    print("Thinking...")
    
    route = route_query(question)
    
    if route == "RAG":
        run_rag(question)
    elif route == "SQL":
        run_sql(question)
    elif route == "HYBRID":
        run_hybrid(question)
    else:
        print(f"[Error] AI Router got confused and returned: {route}")

if __name__ == "__main__":
    # Let's test the whole system!
    print("=====================================================")
    print("🚀 Enterprise AI Support Assistant Started!")
    print("Type 'exit' or 'quit' to stop the assistant.")
    print("=====================================================")
    
    while True:
        # 1. Take input from the user in the CLI
        user_input = input("\n🧑‍💻 You (Ask a question): ")
        
        # 2. Check if the user wants to exit
        if user_input.lower() in ['exit', 'quit']:
            print("\nShutting down AI Assistant. Have a great day! 👋")
            break
            
        # 3. Ignore empty inputs
        if not user_input.strip():
            continue
            
        # 4. Process the live query!
        process_user_query(user_input)