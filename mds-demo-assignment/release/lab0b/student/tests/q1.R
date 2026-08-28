test = list(
  name = "q1",
  cases = list(
    ottr::TestCase$new(
      hidden = FALSE,
      name = NA,
      points = 1.0,
      code = {
        testthat::expect_true(!is.null(r_courses))
        testthat::expect_equal(as.numeric(r_courses), 3)
      }
    )
  )
)