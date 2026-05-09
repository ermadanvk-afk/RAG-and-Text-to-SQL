import os
import sys
from dotenv import load_dotenv
from langchain_chroma import Chroma
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import PromptTemplate
from langchain_classic.chains import RetrievalQA
# 1. Load Environment Variables (Secure API Key Handling)
load_dotenv()

# Verify API key exists to prevent crashing later
if not os.getenv("GOOGLE_API_KEY"):
    print("Error: GOOGLE_API_KEY not found. Please ensure your .env file is set up correctly.")
    sys.exit(1)

def run_full_rag(query: str):
    """
    Executes a RAG query against the local ChromaDB using Gemini.
    """
    try:
        # 2. Setup Embeddings and Connect to Vector DB
        # This allows the unified search across all documents in the docs/ folder
        embeddings = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")
        vectorstore = Chroma(persist_directory="./chroma_db", embedding_function=embeddings)
        
        # 3. Setup Gemini LLM
        # temperature=0 ensures the AI remains factual and doesn't hallucinate
        llm = ChatGoogleGenerativeAI(model="gemini-2.5-flash", temperature=0.5)

        # 4. Robust Prompt Engineering
        # These instructions act as strict guardrails for handling imperfect data
        template = """You are a professional enterprise support assistant. 
        Use the following pieces of retrieved context to answer the user's question. 
        
        CRITICAL INSTRUCTIONS:
        1. AMBIGUITY HANDLING: Enterprise documentation often contains implicit, inconsistent, or missing terminology. 
        2. REASONING: Use your reasoning capabilities to logically map the user's conversational terms to the closest matching official concepts found in the provided context.
        3. NO HALLUCINATIONS: Do not invent or assume numbers, policies, or facts. If the core answer cannot be logically deduced from the context, explicitly state "I do not have enough information in the provided documentation to answer this."
        4. Be specific, clear, and format your answer neatly.

        Context: {context}
        Question: {question}

        Answer:"""
        
        QA_CHAIN_PROMPT =PromptTemplate.from_template(template)

        # 5. Create the RAG Chain with Transparency
        # return_source_documents=True is critical for the evaluation criteria
        qa_chain = RetrievalQA.from_chain_type(
            llm=llm,
            retriever=vectorstore.as_retriever(search_kwargs={"k": 3}),
            return_source_documents=True,
            chain_type_kwargs={"prompt": QA_CHAIN_PROMPT}
        )

        # 6. Execute the Query
        print(f"\nThinking... Analyzing documents for: '{query}'\n")
        result = qa_chain.invoke({"query": query})

        # 7. Print the Answer and Sources
        print("================ AI ANSWER ================")
        print(result["result"])
        print("\n================ SOURCES USED ================")
        
        # Extract unique sources to avoid printing duplicate file names
        unique_sources = set([doc.metadata.get('source', 'Unknown') for doc in result["source_documents"]])
        for source in unique_sources:
            print(f"- {source}")
        print("===========================================\n")

    except Exception as e:
        print(f"An error occurred during execution: {e}")

if __name__ == "__main__":
    #easily test different generic queries here
    test_queries = [
        "What is the SLA for a security incident?",
        "What is the process for a security incident?",
        "Who can approve a refund of $1000?"
    ]
    
    # Run the first test query
    run_full_rag(test_queries[0])