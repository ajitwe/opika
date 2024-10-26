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

# Install Scrapy using pip
# RUN pip install --upgrade pip && pip install scrapy scrapy-user-agents scrapy-proxy-pool scrapy-splash

# Install dependencies from requirements.txt
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copy the local Scrapy project into the container
COPY . /app

# Set an environment variable for dynamic URL input
ENV TARGET_URL=""

# Run Scrapy from the project folder where scrapy.cfg exists
CMD ["sh", "-c", "cd myproject && scrapy crawl myspider -a url=$TARGET_URL -o /data/output.csv"]
