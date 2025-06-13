FROM python:3.10-slim
WORKDIR /app
COPY simulate.py .
RUN pip install azure-storage-blob
CMD ["python", "simulate.py"]
