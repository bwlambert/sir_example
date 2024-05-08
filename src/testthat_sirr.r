library(testthat)
library(deSolve)

# Load the SIR model functions
source("sirr.r")

# context("Testing SIR Model Functions")

# Test SIR model differential equations
test_that("SIR model equations output correct values", {
  state <- c(S = 999, I = 1, R = 0)
  parameters <- c(beta = 0.3, gamma = 0.1)
  result <- sir_model(0, state, parameters)
  expect_is(result, "list")
  expect_true(all(sapply(result, is.numeric)))
})

# Test the calculation of effective sample size
test_that("Effective sample size calculation is correct", {
  weights <- c(0.1, 0.2)
  x <- adequate_ESS(weights, 0.5)
  print(x)
  threshold <- 0.5
  result <- adequate_ESS(weights, threshold)
  print(result)
  expect_is(result, "logical")
  expect_equal(result, TRUE)
})

# Test particle sampling based on weights
test_that("Particles are sampled according to weights", {
  weights <- c(0.1, 0.0, 0.9)
  particles <- list(c(I = 10), c(I = 20), c(I = 30))

  # sample particles 100 times, append to list
  indices <- replicate(100, sample_particles(weights, particles))

  #indices <- sample_particles(weights, particles)
  #expect_is(indices, "integer")
  #expect_length(indices, length(particles))
  # Expect most indices to be of the highest weight

  # collapse all indices into a single vector
  indices <- unlist(indices)
  counts <- table(indices)
  #print("Counts of indices")
  #print(counts)

  # expect that 2 is not found in indices
  expect_false(2 %in% indices)
 
  # expect that 3 is found more often than 1
  expect_true(counts['3'] > counts['1']) 

})

# Test handling of degeneracy in weights
test_that("Handling degeneracy reweights and samples appropriately", {
  observed_I <- c(10, 10, 10, 10)
  
  weights <- rep(0.001, 1000)
  particles <- replicate(1000, c(I = 30), simplify = FALSE)

  # Now, set first particle to have I = 10
  particles[[1]] <- c(I = 10)

  time <- 2
 
  #print("Unique weights before reweighing")
  #print(length(unique(weights)))
  #print("Weights before reweighing")
  #print(weights)
  new_weights <- reweigh_in_case_of_degeneracy(weights, particles, observed_I, time, 5000)
  #print("Unique weights after reweighing")
  #print(length(unique(new_weights)))
  #print("New weights")
  #print(new_weights)

  # Check if the first weight is set high
  expect_true(new_weights[1] == 1e+3)

  # expect that the first weight is the max weight
  expect_true(new_weights[1] == max(new_weights))

  # At this point, it appears the reweighing is working as expected
  # Now, we need to sample the particles:

  #expect_true(any(new_weights == 1000))  # Check if any weights were set high
  new_particles <- sample_particles(new_weights, particles)

  # print unique new particles
  print("Unique new particles")
  print(unique(new_particles))
  print(length(unique(new_particles)))
  expect_length(unique(new_particles), 1) # Will often succeed!

  # save a list of length of unique particles from 10 calls:
  all_unique_particles <- replicate(10, length(unique(sample_particles(new_weights, particles))))
  print("All unique particles")
  print(all_unique_particles)

  expect_true(all(all_unique_particles == 1))


})
