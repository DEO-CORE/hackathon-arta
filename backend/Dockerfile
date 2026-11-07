FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.lock ./
RUN pip install --no-cache-dir -r requirements.lock
RUN useradd --create-home --uid 10001 arta
COPY --chown=arta:arta . .
RUN mkdir -p /app/var/storage && chown -R arta:arta /app/var
USER arta
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
