import sqlite3

def initialize_database():
    print("Setting up the database...")
    
    # This creates a new file called 'helpdesk.db' and connects to it
    conn = sqlite3.connect('setup.db')
    cursor = conn.cursor()

    # Read the messy SQL file they gave you
    with open('helpdesk_seed.sql', 'r', encoding='utf-8') as f:
        sql_script = f.read()

    # Execute all the queries in the script
    cursor.executescript(sql_script)

    # Save changes and close the connection
    conn.commit()
    conn.close()

    print("Success! 'helpdesk.db' has been created and populated.")

if __name__ == "__main__":
    initialize_database()