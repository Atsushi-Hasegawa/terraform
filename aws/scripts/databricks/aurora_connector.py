from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import min, max, lit
from functools import reduce
from concurrent.futures import ThreadPoolExecutor
import json
import os

# SparkSession は Databricks 環境では自動的に利用可能です
# ローカルでテストする場合は以下をコメント解除してください
# spark = SparkSession.builder.appName("AuroraConnector").getOrCreate()

class AuroraConnector:
    """
    パフォーマンスと負荷分散を最適化した Aurora (MySQL) 汎用コネクタ。
    """
    
    def __init__(self, host, secret_scope="aurora-scope", user_key="username", pwd_key="password"):
        self.host = host
        # Databricks Secrets から認証情報を取得
        # ※ dbutils は Databricks 環境で自動的に利用可能です
        self.user = dbutils.secrets.get(scope=secret_scope, key=user_key)
        self.password = dbutils.secrets.get(scope=secret_scope, key=pwd_key)
        
        # --- パフォーマンス最適化のための JDBC オプション ---
        self.base_options = {
            "driver": "com.mysql.cj.jdbc.Driver",
            "user": self.user,
            "password": self.password,
            "fetchsize": "20000",              # 1回のリクエストで取得する行数（メモリと速度のバランス）
            "pushDownPredicate": "true",       # フィルタ（WHERE句）をDB側に押し込み、転送量を削減
            "sessionInitStatement": "SET NAMES utf8mb4",
            "rewriteBatchedStatements": "true",# バッチ処理の最適化
            "useSSL": "true",
            "serverTimezone": "UTC"
        }

    def _get_url(self, database):
        return f"jdbc:mysql://{self.host}:3306/{database}"

    def get_bounds(self, table_name, database, partition_col):
        """DBから最小値と最大値を自動取得し、パーティショニングを最適化する"""
        url = self._get_url(database)
        print(f"Fetching bounds for {database}.{table_name} on {partition_col}...")
        try:
            # 範囲取得のためのSQLを直接実行
            query = f"(SELECT MIN({partition_col}), MAX({partition_col}) FROM {table_name}) AS bounds_query"
            bounds_df = (spark.read.format("jdbc")
                        .options(**self.base_options)
                        .option("url", url)
                        .option("dbtable", query)
                        .load())
            bounds = bounds_df.collect()[0]
            return bounds[0], bounds[1]
        except Exception as e:
            print(f"Error fetching bounds for {database}.{table_name}: {e}")
            return None, None


    def read_table(self, table_name, database, partition_col=None, num_partitions=None):
        """
        単一テーブルの読み込み。
        partition_col が指定された場合、自動的に境界を取得して並列読み込みを行う。
        """
        options = self.base_options.copy()
        options["url"] = self._get_url(database)
        options["dbtable"] = table_name
        
        if partition_col and num_partitions:
            # データの範囲を動的に取得して、10台のインスタンスへ均等に負荷を分散
            lower, upper = self.get_bounds(table_name, database, partition_col)
            if lower is not None and upper is not None:
                options.update({
                    "partitionColumn": partition_col,
                    "numPartitions": str(num_partitions),
                    "lowerBound": str(lower),
                    "upperBound": str(upper)
                })
                print(f"Parallel Read: {database}.{table_name} (Range: {lower}-{upper}, Parts: {num_partitions})")
            else:
                print(f"Warning: Could not determine bounds for {database}.{table_name}. Falling back to single connection or default partitioning.")
        else:
             print(f"Single Read: {database}.{table_name}")
        
        return spark.read.format("jdbc").options(**options).load()

    def read_sharded_table(self, table_name, database_prefix, shard_ids, partition_col=None, num_partitions=None, max_concurrent_shards=3):
        """
        シャード分割されたテーブルを読み込む。
        max_concurrent_shards により、DBへの瞬間的な同時接続負荷を制御する。
        """
        def read_shard(shard_id):
            db_name = f"{database_prefix}{shard_id}"
            df = self.read_table(table_name, db_name, partition_col, num_partitions)
            return df.withColumn("shard_id", lit(shard_id))

        print(f"Reading {len(shard_ids)} shards for {table_name} with concurrency={max_concurrent_shards}...")
        
        # ThreadPoolExecutorのworkers数を制限することで、DBへの負荷を制御
        with ThreadPoolExecutor(max_workers=min(len(shard_ids), max_concurrent_shards)) as executor:
            shard_dfs = list(executor.map(read_shard, shard_ids))

        # UnionAll を安全に適用するために、空のリストの場合は空のDataFrameを返す
        if not shard_dfs:
            return spark.createDataFrame([], schema=spark.emptyDataFrame.schema)
        return reduce(DataFrame.unionAll, shard_dfs)

# --- 利用例 ---
if __name__ == "__main__":
    # 設定ファイルのパス
    config_file_path = "scripts/databricks/aurora_config.json"
    
    # 設定ファイルを読み込み
    if os.path.exists(config_file_path):
        with open(config_file_path, 'r') as f:
            config = json.load(f)
    else:
        raise FileNotFoundError(f"Configuration file not found at {config_file_path}")

    # Auroraコネクション設定の取得（例: "staging_reader"）
    connection_name = "staging_reader"
    conn_config = config["aurora_connections"].get(connection_name)
    if not conn_config:
        raise ValueError(f"Connection configuration for '{connection_name}' not found.")

    # AuroraConnectorの初期化
    connector = AuroraConnector(
        host=conn_config["host"],
        secret_scope=conn_config["secret_scope"],
        user_key=conn_config["user_key"],
        pwd_key=conn_config["pwd_key"]
    )

    # ロードプランの取得（例: "default_load"）
    load_plan_name = "default_load"
    load_plan = config["load_plans"].get(load_plan_name)
    if not load_plan:
        raise ValueError(f"Load plan for '{load_plan_name}' not found.")

    dataframes = {}
    for alias, table_config in load_plan.items():
        table_type = table_config.get("type", "single") # 'single' または 'sharded'
        
        if table_type == "sharded":
            print(f"Processing sharded table: {alias}")
            dataframes[alias] = connector.read_sharded_table(
                table_name=table_config["table_name"],
                database_prefix=table_config["database_prefix"],
                shard_ids=table_config["shard_ids"],
                partition_col=table_config.get("partition_col"),
                num_partitions=table_config.get("num_partitions"),
                max_concurrent_shards=table_config.get("max_concurrent_shards", 3)
            )
        elif table_type == "single":
            print(f"Processing single table: {alias}")
            dataframes[alias] = connector.read_table(
                table_name=table_config["table_name"],
                database=table_config["database"],
                partition_col=table_config.get("partition_col"),
                num_partitions=table_config.get("num_partitions")
            )
        else:
            print(f"Warning: Unknown table type '{table_type}' for alias '{alias}'. Skipping.")

    # 利用例: 読み込んだDataFrameの表示
    if "all_users_df" in dataframes:
        print("\n--- all_users_df Schema and Sample ---")
        dataframes["all_users_df"].printSchema()
        dataframes["all_users_df"].show(5)
    
    if "config_df" in dataframes:
        print("\n--- config_df Sample ---")
        dataframes["config_df"].show()

    if "product_catalog" in dataframes:
        print("\n--- product_catalog Sample ---")
        dataframes["product_catalog"].show()

