# RAG-Based AI Enterprise Helpdesk Tool — Setup Guide

A CLI-based AI enterprise helpdesk tool powered by Retrieval-Augmented Generation (RAG), combining a SQL engine for structured data queries and a vector database for semantic policy document search.

---

## Dependencies

Install all required Python packages using the command below:

```bash
pip install -U langchain-google-genai langchain-huggingface langchain-community langchain-core chromadb unstructured markdown sentence-transformers python-dotenv
```

---

## Environment Configuration

Create a `.env` file in the root directory of the project and add your Google Gemini API key:

```
GOOGLE_API_KEY=your_api_key_here
```

> **Note:** The file must be named exactly `.env`. If you do not have an API key, you can search for **"how to get a free Google Gemini API key"** on YouTube for a step-by-step guide.

---

## Step 1 — Setting Up the Workspace

**1.1 Create the Project Directory**

Create a new folder for the project. You can name it `Project` or any preferred name:

```bash
mkdir Project
cd Project
```

**1.2 Add Required Files**

Place the following inside your project directory:

- `docs/` — A folder containing all company policy context documents.
- `helpdesk_seed.sql` — The SQL file containing the helpdesk data tables.

Your directory should look like this:

```
Project/
├── docs/
│   └── (policy documents here)
├── helpdesk_seed.sql
├── set_db.py
├── set_rag.py
├── get_schema.py
├── final_testsql.py
├── main.py
└── .env
```

**1.3 Create a Virtual Environment**

Setting up a virtual environment keeps dependencies isolated and prevents conflicts.

**On Windows:**

```bash
python -m venv venv
venv\Scripts\activate
```

**On Linux / macOS:**

```bash
python3 -m venv venv
source venv/bin/activate
```

> Once activated, your terminal prompt will show `(venv)` at the beginning, confirming the environment is active.

**1.4 Install SQLite**

- Download SQLite from the [official SQLite website](https://www.sqlite.org/download.html).
- Extract the downloaded files and place the folder on your C drive, for example:

```
C:\sqlite\
```

**1.5 Add SQLite to Environment Variables (Windows)**

So that SQLite can be used from any terminal location, add its path to your system's environment variables:

1. Open **System Properties** → **Advanced** → **Environment Variables**.
2. Under **System Variables**, select `Path` and click **Edit**.
3. Click **New** and add the path to your SQLite folder:

```
C:\sqlite
```

4. Click **OK** to save. Verify by running the following in a new terminal:

```bash
sqlite3 --version
```

---

## Step 2 — Setting Up the Databases

**2.1 Setting Up the Helpdesk SQL Database**

Run `set_db.py` to create the SQLite database named `setup.db` and populate it using the data from `helpdesk_seed.sql`:

```bash
python set_db.py
```

This script reads `helpdesk_seed.sql`, creates `setup.db`, and loads all the helpdesk data tables into it.

**2.2 Setting Up the Vector Database (RAG)**

Run `set_rag.py` to generate embeddings for all policy documents inside the `docs/` folder and store them in a vector database used for semantic similarity search:

```bash
python set_rag.py
```

> Make sure your `.env` file with the `GOOGLE_API_KEY` is present before running this script.

---

## Step 3 — Preparing the Text-to-SQL Engine

**3.1 Extract the Database Schema**

The Text-to-SQL engine requires full context of every table in the database. Run `get_schema.py` to extract and save the schema:

```bash
python get_schema.py
```

**3.2 Test the SQL Query Pipeline**

`final_testsql.py` serves as the central module that converts natural language queries into SQL, sends them to the database, and returns the results. Run it to verify the pipeline is working:

```bash
python final_testsql.py
```

---

## Step 4 — Launch the Application

With all components in place, run `main.py` to start the RAG-based AI enterprise helpdesk tool in the command-line interface:

```bash
python main.py
```

The tool is now active and ready to answer queries using both the SQL database and the RAG policy document search engine.

---

## Quick Reference — Script Summary

| Script | Purpose |
|---|---|
| `set_db.py` | Creates `setup.db` and loads `helpdesk_seed.sql` data |
| `set_rag.py` | Generates embeddings and builds the vector database |
| `get_schema.py` | Extracts database table schemas for the SQL engine |
| `final_testsql.py` | Converts queries to SQL and fetches results from the database |
| `main.py` | Launches the complete AI helpdesk tool in the CLI |
