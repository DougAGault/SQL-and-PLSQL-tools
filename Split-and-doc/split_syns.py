import re
import datetime
import sys

# Check if the command-line argument is provided
if len(sys.argv) < 2 :
    print("Usage: python script.py ")
    sys.exit(1)

# Get the input file name from the command-line argument
input_filename = sys.argv[1]

# Get today's date in the format YYYY.MM.DD
today_date = datetime.datetime.now().strftime("%Y.%m.%d")

# Function to create a file for each synonym
def create_synonym_file(synonym_name, statement):
    filename = f"{synonym_name}.sql"
    contents = f"""--liquibase formatted sql
-- ------------------------------------------------------------------------------
--changeset purify:{synonym_name}.create.{today_date} runOnChange:true
{statement}
--rollback drop synonym {synonym_name}
"""
    with open(filename, 'w') as file:
        file.write(contents)

# Read the input file
with open(input_filename, 'r') as file:
    for line in file:
        # Extract the synonym name using regex
        match = re.search(r'CREATE OR REPLACE SYNONYM "(.*?)" FOR', line)
        if match:
            synonym_name = match.group(1)
            # Call the function to create a file with the synonym name
            create_synonym_file(synonym_name, line.strip())

print("Synonym files have been created.")
