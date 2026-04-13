#!/bin/sh
# Start Ollama server in background
ollama serve &
SERVE_PID=$!

# Wait for server to be ready
echo "Waiting for Ollama server..."
sleep 5
until ollama list > /dev/null 2>&1; do
  sleep 2
done
echo "Ollama server ready"

# Pull model if not already present
if ! ollama list | grep -q "llama3.2:1b"; then
  echo "Pulling llama3.2:1b (first run only, ~1.3GB)..."
  ollama pull llama3.2:1b
  echo "Model ready"
else
  echo "Model llama3.2:1b already present"
fi

# Keep server running
wait $SERVE_PID
