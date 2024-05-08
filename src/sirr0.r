library(deSolve)
library(stats)

# SIR model differential equations
sir_model <- function(t, state, parameters) {
  with(as.list(c(state, parameters)), {
    dS <- -beta * S * I / (S + I + R)  # The force of infection acts directly on S to I
    dI <- beta * S * I / (S + I + R) - gamma * I
    dR <- gamma * I
    
    return(list(c(dS, dI, dR)))
  })
}

adequate_ESS <- function(weights,threshold) {
  # weights are assumed to be normalized
  ess = 1 / sum(weights^2)
  #print(paste("ESS:", ess))
  return(ess > threshold)
}

# Particle filter function for SEIR model
run_particle_filter <- function(beta,  gamma, observed_I, N, initial_state, times, num_particles = 1000) {
  parameters <- c(beta = beta, gamma = gamma)
  
  particles <- replicate(num_particles, initial_state, simplify = FALSE)
  # add noise to the initial state
  # particles <- lapply(particles, function(x) x + rnorm(length(x), mean = 0, sd = 0.1 * x))

  for (i in seq_along(particles)) {
    particles[[i]]["I"] <- particles[[i]]["I"] + rnorm(1, mean = 0, sd = 0.1 * particles[[i]]["I"])
  }

  weights <- rep(1 / num_particles, num_particles)
  neg_log_likelihood <- 0
  
  update_particles <- function(time, observed_I) {
    for (i in seq_along(particles)) {
      # Run model simulation for each particle
      #out <- ode(y = particles[[i]], times = c(time, time + 1), func = seir_model, parms = parameters)
      out <- ode(y = particles[[i]], times = c(time, time + 1), func = sir_model, parms = parameters)
      particles[[i]] <- out[nrow(out), -1]  # Update state to last time point
      
      # Calculate weight based on proximity to observed data
      predicted_I <- particles[[i]]["I"]
      likelihood <- dnorm(observed_I[time + 1], mean = predicted_I, sd = sqrt(predicted_I), log = TRUE)
      weights[i] <- weights[i] + likelihood
    }
    
    # Calculate negative log likelihood
    max_weight <- max(weights)
    adjusted_weights <- exp(weights - max_weight)
    sum_weights <- sum(adjusted_weights)
    log_likelihood <- max_weight + log(sum_weights) - log(length(weights))
    neg_log_likelihood <<- neg_log_likelihood - log_likelihood
    
    # Normalize weights
    weights <- adjusted_weights / sum_weights
    
    print(paste("Time:", time))
    healthy = TRUE
    # add a threshold to avoid degeneracy
    if (!adequate_ESS(weights, 250)) {
      print(sum(weights^2))
      healthy = FALSE
      print("Degeneracy detected, resampling...")
      # find the particle closest to observed_I
      min_diff <- Inf
      for (i in seq_along(particles)) {
        diff <- abs(particles[[i]]["I"] - observed_I[time + 1])
        if (diff < min_diff) {
          min_diff <- diff
          min_index <- i
        }
      }
      # Print the index of the closest particle, the particles I value and the observed I value
      print(paste("min_index:", min_index, "particle I:", particles[[min_index]]["I"], "observed I:", observed_I[time + 1]))

      # Choose the particle closest to the observed data 
      weights[min_index] <- 1e3
    }

    # Resample particles based on weights
    indices <- sample(seq_along(particles), size = num_particles, replace = TRUE, prob = weights)

    if (!healthy) {
      print(paste("Number of unique particles:", length(unique(indices))))
    }

    particles <- particles[indices]
  }
  
  # Run particle filter over time
  for (t in seq_along(times)[-length(times)]) {
    update_particles(t, observed_I)
  }
  
  return(list(particles = particles, neg_log_likelihood = neg_log_likelihood))
}



## Example usage
beta <- 0.3
sigma <- 1 / 5.2
gamma <- 1 / 18

timesteps <- 20
times <- seq(0, timesteps, by = 1)  

# Create a sinusoidal observed data with noise
observed_I <- 2000 + 100 * sin(2 * pi * times / timesteps) + rnorm(length(times), mean = 50, sd = 5)

N <- 10000000  # Total population
# Define the initial states and parameters
initial_state <- c(S = (N-1500), I = 1500, R = 0)  # Adjusted initial conditions
parameters <- c(beta = 0.3, gamma = 1/14)   # Removed sigma, as it's not used in SIR
number_of_particles <- 1000

results <- run_particle_filter(beta, gamma, observed_I, N, initial_state, times)
print(paste0("Negative log likelihood:", results$neg_log_likelihood))




