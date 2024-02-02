#!/bin/zsh

# Load Oh My Zsh if it's not already loaded
if [[ -z "$ZSH" ]]; then
  export ZSH="$HOME/.oh-my-zsh"
  source $ZSH/oh-my-zsh.sh
fi

# Set the NULL_GLOB option to avoid errors if no .pck files are found
setopt NULL_GLOB

# Find all .pck files in the current directory and pass them to split_and_doc.py
for file in *.pck; do
  if [[ -f "$file" ]]; then
    echo "Processing $file..."
    python3 split_and_doc.py "$file"
  else
    echo "No .pck files found."
    exit 1
  fi
done

# Unset the NULL_GLOB option if needed
unsetopt NULL_GLOB
