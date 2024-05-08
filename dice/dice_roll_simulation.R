# Function to roll a single 6-sided die
roll_die <- function() {
  return(sample(1:6, 1))
}
# Function to roll multiple dice and return the sum
roll_multiple_dice <- function(num_dice) {
dice_rolls <- replicate(num_dice, roll_die())
return(sum(dice_rolls))
}
# Function to simulate multiple rolls of multiple dice
simulate_multiple_rolls <- function(num_rolls, num_dice) {
rolls <- replicate(num_rolls, roll_multiple_dice(num_dice))
return(rolls)
}
