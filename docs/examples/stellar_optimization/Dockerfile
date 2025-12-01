# Use Constellaration base image (contains physics libraries)
FROM ghcr.io/proximafusion/constellaration:latest

# Install additional dependencies
RUN pip install --no-cache-dir \
    google-cloud-storage \
    ray[default]

# Copy training code
COPY train.py /app/
COPY requirements.txt /app/

WORKDIR /app

# Install any additional requirements
RUN pip install --no-cache-dir -r requirements.txt

# Run training script
CMD ["python", "train.py"]
