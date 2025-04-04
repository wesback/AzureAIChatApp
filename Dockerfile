FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Install system dependencies for PyMuPDF and Pillow
RUN apt-get update && apt-get install -y \
    build-essential \
    libffi-dev \
    libssl-dev \
    libjpeg-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt /app/

# Install required Python packages
RUN pip install --no-cache-dir -r requirements.txt

# Copy the Streamlit application to the container
COPY app.py /app/

# Make port 8501 available to the world outside this container
EXPOSE 8501

# Run streamlit when the container launches
CMD ["streamlit", "run", "app.py", "--server.address=0.0.0.0"]
