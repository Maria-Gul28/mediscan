FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
# Render injects $PORT (Fly used 8080, so keep that as the default)
CMD gunicorn -b 0.0.0.0:${PORT:-8080} app:app --timeout 90