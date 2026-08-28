test = list(
  name = "q2",
  cases = list(
    ottr::TestCase$new(
      hidden = FALSE,
      name = NA,
      points = 1.0,
      code = {
        testthat::expect_true(is.function(block_size))
        testthat::expect_equal(block_size(c(1, 1, 2), 1), 2)
        testthat::expect_equal(block_size(c(1, 1, 2), 2), 1)
      }
    )
  )
)