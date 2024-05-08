library(testthat)

# Load the code file
source("dice_roll_simulation.R")

# Test cases
test_that("roll_die returns values between 1 and 6", {
  rolls <- replicate(1000, roll_die())
  expect_true(all(rolls >= 1 & rolls <= 6))
})

test_that("simulate_multiple_rolls returns the expected distribution", {
  num_rolls <- 10000
  num_dice <- 3
  expected_mean <- num_dice * 3.5
  expected_sd <- sqrt(num_dice * 35 / 12)
  
  rolls <- simulate_multiple_rolls(num_rolls, num_dice)
  
  #expect_equal(mean(rolls), expected_mean)
  #expect_equal(sd(rolls), expected_sd)
  expect_equal(mean(rolls), expected_mean, tolerance = 0.1)
  expect_equal(sd(rolls), expected_sd, tolerance = 0.1)
})
