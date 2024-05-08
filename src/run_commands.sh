#!/bin/bash

# Run the unit tests
Rscript testthat_sirr.r

# Check if the previous command was successful
if [ $? -eq 0 ]; then
    echo "Tests passed, running main script."
    Rscript run_sirr.r
else
    echo "Tests failed, not running main script."
fi

