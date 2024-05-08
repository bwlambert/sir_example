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
  print(paste("ESS:", ess))
  return(ess > threshold)
}

resample_in_case_of_degeneracy <- function(weights, particles, observed_I, time) {
  # if no particles have weight -- choose the one closest to the data
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
      # print mean of particles I
      # print(paste("mean of particles I:", mean(sapply(particles, function(x) x["I"])))

      # replace all particles with the closest one (Corrected from the original code)
      #indices <- rep(min_index, num_particles)

      # set the weight of the closest particle to 1 (This also corrects)
      #weights <- rep(0, num_particles)

      #weights <- rep(0.0001, num_particles)

      # Choose the particle closest to the observed data 
      weights[min_index] <- 1e3
    }
  #return(list(weights, particles))
  return(weights)
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
    
    #print(weights)

    ##      # if no particles have weight -- choose the one closest to the data
    ## if(!is.na(data[i]) & length(unique(smp.wt))==1){
    ##     smp.wt[which.min(abs(params[3]*apply(states[i,2,,],2,sum) - data[i]))] <- 1e3*smp.wt[which.min(abs(params[3]*apply(states[i,2,,],2,sum) - data[i]))]
    ## }
    
    print(paste("Time:", time))
    healthy = TRUE
    if (!adequate_ESS(weights, 250)) {
      healthy = FALSE
    }
  #  # add a threshold to avoid degeneracy
  #  if (!adequate_ESS(weights, 250)) {
  #    print(sum(weights^2))
  #    healthy = FALSE
  #    print("Degeneracy detected, resampling...")
  #    # find the particle closest to observed_I
  #    min_diff <- Inf
  #    for (i in seq_along(particles)) {
  #      diff <- abs(particles[[i]]["I"] - observed_I[time + 1])
  #      if (diff < min_diff) {
  #        min_diff <- diff
  #        min_index <- i
  #      }
  #    }
  #    # Print the index of the closest particle, the particles I value and the observed I value
  #    print(paste("min_index:", min_index, "particle I:", particles[[min_index]]["I"], "observed I:", observed_I[time + 1]))
  #    # print mean of particles I
  #    # print(paste("mean of particles I:", mean(sapply(particles, function(x) x["I"])))

  #    # replace all particles with the closest one (Corrected from the original code)
  #    #indices <- rep(min_index, num_particles)

  #    # set the weight of the closest particle to 1 (This also corrects)
  #    #weights <- rep(0, num_particles)

  #    #weights <- rep(0.0001, num_particles)

  #    # Choose the particle closest to the observed data 
  #    weights[min_index] <- 1e3
  #  }

    weights <- resample_in_case_of_degeneracy(weights, particles, observed_I, time)

    #write_particles_to_disk(particles, paste0("particles",time,".csv"))
    # Resample particles based on weights
    indices <- sample(seq_along(particles), size = num_particles, replace = TRUE, prob = weights)

    if (!healthy) {
      print(paste("Number of unique weights:", length(unique(weights))))
      #print(unique(weights))
      # print the number of unique particles 
      print(paste("Number of unique particles:", length(unique(indices))))
    }
    

    particles <- particles[indices]
    weights <- rep(1 / num_particles, num_particles)
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
initial_state <- c(S = 1000000, E = 1, I = 2500, R = 0)

timesteps <- 20
times <- seq(0, timesteps, by = 1)  
#observed_I <- rnorm(length(times), mean = 20, sd = 5)  # Simulated observed infected cases

# Create a sinusoidal observed data with noise
#observed_I <- 2000 + 100 * sin(2 * pi * times / timesteps) + rnorm(length(times), mean = 0, sd = 5)
# write observed data to disk
#write.csv(observed_I, "observed_I.csv", row.names = FALSE)

observed_I <- read.csv("observed_I.csv")$x

N <- 10000000  # Total population
# Define the initial states and parameters
initial_state <- c(S = (1000000-1500), I = 1500, R = 0)  # Adjusted initial conditions
parameters <- c(beta = 0.3, gamma = 1/14)   # Removed sigma, as it's not used in SIR


results <- run_particle_filter(beta, gamma, observed_I, N, initial_state, times)
print(results$neg_log_likelihood)



