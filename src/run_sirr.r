
source("sirr.r")

## Example usage
beta <- 0.3
sigma <- 1 / 5.2
gamma <- 1 / 18

timesteps <- 20
times <- seq(0, timesteps, by = 1)  

# Create a sinusoidal observed data with noise
observed_I <- 2000 + 100 * sin(2 * pi * times / timesteps) + rnorm(length(times), mean = 50, sd = 5)
# write observed data to disk
#write.csv(observed_I, "observed_I.csv", row.names = FALSE)

#observed_I <- read.csv("observed_I.csv")$x

threshold <- 250 # Threshold for resampling

N <- 10000000  # Total population
# Define the initial states and parameters
initial_state <- c(S = (N-1500), I = 1500, R = 0)  # Adjusted initial conditions
parameters <- c(beta = 0.3, gamma = 1/14)   # Removed sigma, as it's not used in SIR
number_of_particles <- 1000

results <- run_particle_filter(beta, gamma, observed_I, N, initial_state, times, number_of_particles, threshold)
print(paste0("Negative log likelihood:", results$neg_log_likelihood))




