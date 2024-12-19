FROM apache/airflow:latest

USER airflow
RUN pip install --upgrade pip

USER root
RUN sudo apt update
RUN sudo apt install -y openjdk-17-jre-headless


ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin

USER airflow

RUN pip install spotipy 
RUN pip install pydantic 
RUN pip install pandas  
RUN pip install sqlalchemy  
RUN pip install psycopg2-binary  
RUN pip install apache-airflow-providers-apache-spark  
RUN pip install apache-airflow 
RUN pip install pyspark 
RUN pip install apache-airflow-providers-amazon 
RUN pip install vine 
RUN pip install oauthlib 
RUN pip install pyparser 
RUN pip install snowflake 
RUN pip install sshtunnel 
RUN pip install requests_oauthlib 
RUN pip install prompt_toolkit 
RUN pip install slack_sdk   
RUN pip install rsa 
RUN pip install apache-airflow-providers-common-compat 
RUN pip install websocket 