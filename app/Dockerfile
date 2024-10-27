# Use a lightweight Python base image
FROM python:3.8-slim

# Set the working directory inside the container
WORKDIR /app

# Install system dependencies required for Scrapy
RUN apt-get update && apt-get install -y \
    gcc \
    libxml2-dev \
    libxslt1-dev \
    libffi-dev \
    libssl-dev \
    python3-dev \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy the requirements file into the container
COPY requirements.txt /app/

# Install dependencies from requirements.txt
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copy the local Scrapy project and Flask API into the container
COPY . /app

ENV PYTHONPATH=/app

# Expose the Flask port
EXPOSE 5000

# Start the Flask server when the container starts
CMD ["python", "app.py"]
