test = list(
  name = "Q2-1-autograder",
  cases = list(
    ottr::TestCase$new(
      hidden = FALSE,
      name = NA,
      points = 1,
      success_message = "Answer 2.1 is correct, good job!",
      failure_message = "Answer 2.1 is wrong.",
      code = {
        testthat::expect_equal(
          digest::digest(round(y, 1)),
          "2522027d230e3dfe02d8b6eba1fd73e1"
        )
      }
    )
  )
)