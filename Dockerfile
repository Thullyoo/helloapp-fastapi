FROM python:3.11-slim

WORKDIR /hello-app

COPY main.py .

RUN pip install fastapi uvicorn

EXPOSE 5000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5000"]
