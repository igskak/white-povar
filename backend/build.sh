#!/bin/bash
set -e

echo "=== White Povar Backend Build Script ==="
echo "Python version: $(python --version)"
echo "Current directory: $(pwd)"
echo "Listing files:"
ls -la

echo "=== Installing dependencies ==="
pip install --upgrade pip setuptools wheel
echo "Installing from requirements-minimal.txt..."
pip install -r requirements-minimal.txt

echo "=== Build completed successfully ==="
