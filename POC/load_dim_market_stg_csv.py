import pandas as pd 
from sqlalchemy import create_engine

# PostgreSQL connection details
username = 'postgres'
password = 'postgres'
host = 'localhost'  # Use '127.0.0.1' or the hostname of the database
port = 5432
database = 'postgres'


# Create a connection string
engine = create_engine(f'postgresql+psycopg2://{username}:{password}@{host}:{port}/{database}')

df=pd.read_csv('CountryCodes.csv')


# Push the DataFrame to PostgreSQL
table_name = 'dim_market_stg'  # Replace with your desired table name
try:
    df.to_sql(table_name, 
              engine, 
              if_exists='replace', 
              index=False,
              schema='public')
    print(f"DataFrame successfully written to table '{table_name}'.")
except Exception as e:
    print(f"Error occurred: {e}")

print('#### PUSHED TO DATABASE #####')
