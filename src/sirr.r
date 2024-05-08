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
  #print(paste("threshold:", threshold))
  return(ess > threshold)
}

reweigh_in_case_of_degeneracy <- function(weights, particles, observed_I, time,threshold) {
  # if no particles have weight -- choose the one closest to the data
  healthy = TRUE
  # add a threshold to avoid degeneracy
  if (!adequate_ESS(weights, threshold)) {
    #print(sum(weights^2))
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
    # SPOILER # set all weights to 0 except for the chosen particle
    # weights <- rep(0, length(weights))
    # Choose the particle closest to the observed data 
    weights[min_index] <- 1e3
  }
  #return(list(weights, particles))
  return(weights)
}

sample_particles <- function(weights, particles) {
  num_particles <- length(particles)
  indices <- sample(seq_along(particles), size = num_particles, replace = TRUE, prob = weights)
  return(indices)
}

# Particle filter function for SIR model
#run_particle_filter <- function(beta,  gamma, observed_I, N, initial_state, times, num_particles = 1000, threshold = 250) {
run_particle_filter <- function(beta,  gamma, observed_I, N, initial_state, times, num_particles, threshold) {
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
    if (!adequate_ESS(weights, threshold)) {
      healthy = FALSE
      weights <- reweigh_in_case_of_degeneracy(weights, particles, observed_I, time, threshold)
    }

    # Resample particles based on weights
    indices <- sample_particles(weights, particles)

    if (!healthy) {
      # print the number of unique particles 
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
