"""统一错误格式：{"error": {"code", "message"}}，前端会把 message 显示在弹窗里。"""


class AppError(Exception):
    def __init__(self, code: str, message: str, status: int = 500):
        super().__init__(message)
        self.code = code
        self.message = message
        self.status = status


def error_body(code: str, message: str) -> dict:
    return {"error": {"code": code, "message": message}}
