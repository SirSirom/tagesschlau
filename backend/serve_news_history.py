import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


HOST = "localhost"
PORT = 9100
HISTORY_FILE = "news_history.json"


def load_history():
    history_path = Path(HISTORY_FILE)
    if not history_path.exists():
        return {}

    with history_path.open("r", encoding="utf-8") as file:
        return json.load(file)


class HistoryRequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/history":
            self.send_response(404)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Not found"}).encode("utf-8"))
            return

        history = load_history()
        response_body = json.dumps(history, ensure_ascii=False, indent=4).encode("utf-8")

        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(response_body)))
        self.end_headers()
        self.wfile.write(response_body)

    def log_message(self, format, *args):
        return


def run_server():
    server = ThreadingHTTPServer((HOST, PORT), HistoryRequestHandler)
    print(f"Server running at http://{HOST}:{PORT}/history")
    server.serve_forever()


if __name__ == "__main__":
    run_server()
