from pyspark.sql import SparkSession

def main():
    # Initialize Spark session
    spark = SparkSession.builder.master("spark://spark-master:7077").appName("TestApp").getOrCreate()
    # Example: Load a simple DataFrame and perform some transformations
    data = [("Alice", 1), ("Bob", 2), ("Cathy", 3)]
    columns = ["Name", "Value"]
    df = spark.createDataFrame(data, columns)

    print('In Pyspark Test Script')
    # Show the DataFrame
    print(df.show()) 

#``    # Perform a transformation (e.g., adding a new column)
#``    df_with_new_column = df.withColumn("NewValue", df["Value"] * 2)
#``
#``    # Show the new DataFrame
#``    df_with_new_column.show()
#``
#``    # Stop the Spark session
#``    spark.stop()

if __name__ == "__main__":
    main()
