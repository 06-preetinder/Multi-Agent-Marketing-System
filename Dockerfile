FROM python:3.11-slim
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# jsonrpcserver==3.5.6 imports Mapping/Sequence/MutableMapping directly from
# `collections`, which was removed in Python 3.10 (they live in collections.abc
# now). This was verified end-to-end: without this patch the app fails to
# import at all on Python 3.10+. Patching the installed package here — rather
# than pinning to an old Python image and hoping it stays available forever —
# keeps this working on any current Python version.
RUN SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])") && \
    sed -i 's/from collections import Mapping, Sequence/from collections.abc import Mapping, Sequence/' "$SITE_PACKAGES/jsonrpcserver/request_utils.py" && \
    sed -i 's/from collections import MutableMapping/from collections.abc import MutableMapping/' "$SITE_PACKAGES/jsonrpcserver/methods.py"
COPY . .

ENV PYTHONUNBUFFERED=1
EXPOSE 5000

# Neo4j and Redis are both optional — the app degrades gracefully if
# NEO4J_URI / REDIS_URL aren't set. No required environment variables.
CMD ["python", "app.py"]
