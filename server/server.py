"""
    ccloselessplayer server
"""
from io import BytesIO
from logging.config import dictConfig
from subprocess import PIPE, Popen

import requests
from flask import Flask, request, send_file  # type: ignore
from flask_caching import Cache

dictConfig({
    'version': 1,
    'formatters': {'default': {
        'format': '[%(asctime)s] %(levelname)s in %(module)s: %(message)s',
    }},
    'handlers': {'wsgi': {
        'class': 'logging.StreamHandler',
        'stream': 'ext://flask.logging.wsgi_errors_stream',
        'formatter': 'default'
    }},
    'root': {
        'level': 'INFO',
        'handlers': ['wsgi']
    }
})

USERAGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36"

app = Flask(__name__)

cache = Cache(app, config={
    "CACHE_TYPE": "SimpleCache",
    "CACHE_DEFAULT_TIMEOUT": 600
})
log = app.logger

@app.route("/", methods=["GET"])
@cache.cached(make_cache_key=lambda:request.args.get("url", "")+request.args.get("chn", "0"))
def index():
    if "url" in request.args.keys():
        url = request.args.get("url", "")
        chn = request.args.get("chn", "0")
        log.info(f"Requested: {url}")

        # Request source media
        response = requests.get(url, stream=True, headers={
                                "user-agent": USERAGENT})
        response.raise_for_status()

        # call ffmpeg
        p = Popen(["ffmpeg", "-i", 'pipe:', "-af", f"pan=mono|c0=c{chn}", '-ac', '1', '-vn', '-sn', '-acodec', 'pcm_u8', "-ar", "48000", "-f", "u8",  "pipe:"],
                  stdin=PIPE,
                  stdout=PIPE,
                  )
        out = p.communicate(response.raw.read())[0]

        return send_file(BytesIO(out), mimetype="application/octet-stream")
    else:
        return """
        <h1>ccloselessplayer server</h1>
        <p>Hello there!</p>
        <p>API:
        <pre>GET /?url=url&chn=chn</pre>
        <b>url</b>: The media URL
        <br/>
        <b>chn</b>: Audio channel ID, default to 0
        </p>
        """
