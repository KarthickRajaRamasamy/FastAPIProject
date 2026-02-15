# Stage1: Builder

FROM python:3.13-slim AS builder
WORKDIR /build

#install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends gcc python3-dev

#copy and install dependencies to a local folder
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Stage2: Runtime

FROM python:3.13-slim AS runner
WORKDIR /app

#create non-root user account
RUN groupadd -r appuser && useradd  -r -g appuser appuser

#Copy only the installed python packages from the builder stage
COPY --from=builder /root/.local /home/appuser/.local
COPY ./app ./app

#App can find the envionment variable
ENV PATH=/home/appuser/.local/bin:$PATH
ENV PYTHONPATH=/app

#changing ownership for the non-user
RUN chown -R appuser:appuser /app
USER appuser

#port to expose the app
EXPOSE 8000

#command to start the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]