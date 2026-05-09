import sqlite3

def get_full_schema(db_path: str) -> str:
    """Reads the database and returns a formatted schema string for the LLM."""
    try:
        # 1. Connect to the database
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # 2. Get all table names inside the database
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = cursor.fetchall()

        schema_text = ""
        
        # 3. Loop through each table to get its columns
        for table in tables:
            table_name = table[0]
            
            # Skip SQLite's internal background tables
            if table_name.startswith("sqlite_"):
                continue

            # 4. Fetch column details for this specific table
            cursor.execute(f"PRAGMA table_info({table_name});")
            columns = cursor.fetchall()

            # Format the output beautifully for the LLM: column_name (DATA_TYPE)
            column_details = [f"{col[1]} ({col[2]})" for col in columns]
            
            schema_text += f"Table: {table_name}\n"
            schema_text += f"Columns: {', '.join(column_details)}\n\n"

        conn.close()
        return schema_text.strip()
        
    except sqlite3.Error as e:
        return f"Database error: {e}"

if __name__ == "__main__":
    # Test our function!
    print("Extracting schema from helpdesk.db...\n")
    full_schema = get_full_schema("setup.db")
    
    print("================ FULL DATABASE SCHEMA ================")
    print(full_schema)
    print("======================================================")