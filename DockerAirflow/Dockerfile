FROM apache/airflow:latest

USER airflow
RUN pip install --upgrade pip

USER root
RUN sudo apt update
RUN sudo apt install -y openjdk-17-jre-headless


ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin

USER airflow

RUN pip install spotipy --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install pydantic  --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install pandas  --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install sqlalchemy  --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install psycopg2-binary  --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install apache-airflow-providers-apache-spark  --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install apache-airflow --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install pyspark --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install apache-airflow-providers-amazon --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install vine --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install oauthlib --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install pyparser --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install snowflake --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install sshtunnel --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install requests_oauthlib --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install prompt_toolkit --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install slack_sdk   --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install rsa --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install apache-airflow-providers-common-compat --target=/opt/airflow/lib/python3.12/site-packages/
RUN pip install websocket --target=/opt/airflow/lib/python3.12/site-packages/