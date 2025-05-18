# Use an official Python runtime as the base image
FROM python:3.11-slim

# Set environment variables to prevent Python from writing .pyc files and buffering stdout
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set the working directory
WORKDIR /app

# Copy the current directory contents into the container
COPY . /app

# Install MySQL connector
RUN pip install mysql-connector-python

# Run the Python script
CMD ["python", "db_conn.py"]
