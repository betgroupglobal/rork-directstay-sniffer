from __future__ import annotations

import os
import sys
from pathlib import Path

from flask import Flask, jsonify, request

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))

os.environ.setdefault("CRAWLER_DB_PATH", "/tmp/crawler.db")

from stays_crawler.server import build_crawler, handle_guesty_webhook, handle_search_payload, _verify_guesty_signature

app = Flask(__name__)
_crawler = None


def _get_crawler():
    global _crawler
    if _crawler is None:
        _crawler = build_crawler()
    return _crawler


@app.after_request
def _cors(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET,POST,OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type,X-Guesty-Signature,X-Guesty-Event"
    return response


@app.route("/health", methods=["GET", "OPTIONS"])
def health():
    if request.method == "OPTIONS":
        return "", 204
    return jsonify({"status": "ok"}), 200


@app.route("/api/v1/crawl", methods=["POST", "OPTIONS"])
def crawl():
    if request.method == "OPTIONS":
        return "", 204
    payload = request.get_json(silent=True)
    if payload is None:
        return jsonify({"error": "invalid json"}), 400
    status, body = handle_search_payload(payload, _get_crawler())
    return jsonify(body), int(status)


@app.route("/api/v1/webhooks/guesty", methods=["POST", "OPTIONS"])
def guesty_webhook():
    if request.method == "OPTIONS":
        return "", 204
    payload = request.get_json(silent=True)
    if payload is None:
        return jsonify({"error": "invalid json"}), 400
    raw = request.get_data(as_text=True)
    signature = request.headers.get("X-Guesty-Signature", "")
    if not _verify_guesty_signature(raw, signature):
        return jsonify({"error": "invalid webhook signature"}), 401
    event = request.headers.get("X-Guesty-Event", "")
    status, body = handle_guesty_webhook(payload, _get_crawler().store, event)
    return jsonify(body), int(status)
