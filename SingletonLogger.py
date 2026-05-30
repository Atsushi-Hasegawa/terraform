
import logging
import sys

def singleton(cls):
    """シングルトンパターンを実現するデコレータ"""
    instances = {}
    def get_instance(*args, **kwargs):
        if cls not in instances:
            instances[cls] = cls(*args, **kwargs)
        return instances[cls]
    return get_instance

@singleton
class Logger:
    """
    シングルトンパターンのロガークラス。
    loggingモジュールをラップして、アプリケーション全体で単一のロガーインスタンスを共有します。
    """
    _logger = None

    def __init__(self, name='my_app', level=logging.INFO):
        """
        ロガーを初期化します。
        この初期化は最初のインスタンス生成時に一度だけ実行されます。
        """
        if self._logger is None:
            self._logger = logging.getLogger(name)
            self._logger.setLevel(level)

            # コンソール出力用のハンドラを作成
            handler = logging.StreamHandler(sys.stdout)
            handler.setLevel(level)

            # ログのフォーマットを定義
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            handler.setFormatter(formatter)

            # ハンドラをロガーに追加
            if not self._logger.handlers:
                self._logger.addHandler(handler)

    def get_logger(self):
        """設定済みのロガーインスタンスを返します。"""
        return self._logger

# --- 使用例 ---
if __name__ == '__main__':
    # Loggerクラスのインスタンスを複数回取得
    logger1 = Logger().get_logger()
    logger2 = Logger().get_logger()

    # 両方のインスタンスが同じものであることを確認
    print(f"Logger 1 ID: {id(logger1)}")
    print(f"Logger 2 ID: {id(logger2)}")
    print(f"Is logger1 the same as logger2? {logger1 is logger2}")

    # ログメッセージを出力
    logger1.info("This is an info message from logger1.")
    logger2.warning("This is a warning message from logger2.")
    logger1.error("This is an error message.")
