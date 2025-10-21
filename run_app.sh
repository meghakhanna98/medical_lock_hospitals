#!/bin/bash

# Medical Lock Hospitals Shiny App Setup Script
# This script sets up the environment and runs the Shiny app

echo "Setting up Medical Lock Hospitals Data Explorer..."

# Check if R is installed
if ! command -v R &> /dev/null; then
    echo "Error: R is not installed. Please install R first."
    echo "Visit https://www.r-project.org/ to download R."
    exit 1
fi

# Check if database exists
if [ ! -f "medical_lock_hospitals.db" ]; then
    echo "Error: Database file 'medical_lock_hospitals.db' not found."
    echo "Please run 'python3 create_database.py' first to create the database."
    exit 1
fi

# Install required R packages
echo "Installing required R packages..."
Rscript install_packages.R

# Check if packages installed successfully
if [ $? -eq 0 ]; then
    echo "Packages installed successfully!"
else
    echo "Warning: Some packages may not have installed correctly."
    echo "You may need to install them manually."
fi

# Run the Shiny app
echo "Starting Shiny app..."
echo "The app will open in your default web browser."
echo "To stop the app, press Ctrl+C in this terminal."

Rscript -e "shiny::runApp('app.R', port=3838, host='0.0.0.0')"
