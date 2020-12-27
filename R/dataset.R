kaggle_download <- function(name, token = NULL) {

  if ("kaggle" %in% pins::board_list()) {
    file <- pins::pin_get(name, board = "kaggle")
  } else if (!is.null(token)) {
    pins::board_register_kaggle(name="guessthecorrelation-kaggle", token = token,
                                cache = tempfile(pattern = "dir"))
    on.exit({pins::board_deregister("guessthecorrelation-kaggle")}, add = TRUE)
    file <- pins::pin_get(name,
                          board = "guessthecorrelation-kaggle",
                          extract = FALSE)
  } else {
    stop("Please register the Kaggle board or pass the `token` parameter.")
  }

  file
}

#' Guess The Correlation dataset
#'
#' Prepares the Guess The Correlation dataset available in Kaggle [here](https://www.kaggle.com/c/guess-the-correlation)
#'
#' We use pins for downloading and managing authetication.
#' If you want to download the dataset you need to register the Kaggle board as
#' described in [this link](https://pins.rstudio.com/articles/boards-kaggle.html).
#' or pass the `token` argument.
#'
#' @param root path to the data location
#' @param token a path to the json file obtained in Kaggle. See [here](https://pins.rstudio.com/articles/boards-kaggle.html)
#'   for additional info.
#' @param split string. 'train' or 'submition'
#' @param transform function that receives a torch tensor and return another torch tensor, transformed.
#' @param download wether to download or not
#'
#' @export
guess_the_correlation_dataset <- torch::dataset(
  "GuessTheCorrelation",
  initialize = function(root, token = NULL, split = "train", transform = NULL, download = FALSE) {

    self$transform <- transform
    # donwload ----------------------------------------------------------
    data_path <- fs::path(root, "guess-the-correlation")

    if (!fs::dir_exists(data_path) && download) {
      file <- kaggle_download("c/guess-the-correlation", token)
      fs::dir_create(data_path)
      fs::file_copy(stringr::str_subset(file, "csv$"), data_path)
      from <- stringr::str_subset(file, "csv$")
      to <- gsub("csv", "zip", from)
      file.rename(from, to)

      sapply(c(to, stringr::str_subset(file, "zip")), function(x) zip::unzip(x, exdir = data_path))
    }

    if (!fs::dir_exists(data_path))
      stop("No data found. Please use `download = TRUE`.")

    # variavel resposta -------------------------------------------------

    if(split == "train") {
      self$walker <- readr::read_csv(fs::path(data_path, "train.csv"), col_types = c("cn"))
      self$.path <- file.path(data_path, "train_imgs")
    } else if(split == "submition") {
      self$walker <- readr::read_csv(fs::path(data_path, "example_submition.csv"), col_types = c("cn"))
      self$walker$corr <- NA_real_
      self$.path <- file.path(data_path, "test_imgs")
    }
  },

  .getitem = function(index) {
    force(index)
    if(length(index) != 1 || index <= 0) value_error("index should be a single integer greater than zero.")

    sample <- self$walker[index, ]

    id <- sample$id
    y <- sample$corr
    x <- torchvision::magick_loader(file.path(self$.path, paste0(sample$id, ".png")))
    x <- torchvision::transform_to_tensor(x)[1]$unsqueeze(1)

    if (!is.null(self$transform))
      sample <- self$transform(sample)

    return(list(x = x, y = y, id = id))
  },

  .length = function() {
    nrow(self$.walker)
  }
)
