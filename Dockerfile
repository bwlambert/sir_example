# Use an official R base image
FROM r-base:latest

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy the current directory contents into the container at /usr/src/app
COPY src/ .

# Run commands to set USER_ENV variable
RUN user=$(whoami) && \
    echo "USER_ENV=$user" > /etc/environment

# Install R packages as root
RUN Rscript -e 'install.packages(c("testthat", "deSolve", "stats"), repos="http://cran.rstudio.com/", lib="/usr/local/lib/R/site-library")'

# Make sure run_commands.sh is executable
RUN chmod +x run_commands.sh

# Run run_commands.sh when the container launches
CMD ["./run_commands.sh"]

