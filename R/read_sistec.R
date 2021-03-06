#' Read sistec files
#'
#' The package provides support if your data comes
#' from [setec](http://portal.mec.gov.br/setec-secretaria-de-educacao-profissional-e-tecnologica)
#' or [web](https://sistec.mec.gov.br/). You just need to pass the folder's path were are your files.
#' See Details if you need help to download the data from Sistec.
#'
#' @param path The sistec file's path.
#' @param start A character with the date to start the comparison. The default is the minimum
#' value found in the data. The date has to be in this format: "yyyy.semester".
#' Ex.: "2019.1" or "2019.2".
#' @return A data frame.
#'
#' @details You can download the Sistec's student registration using your proper account on
#' Sistec.  Be sure that your data has these variables:
#'
#'  - On setec: "Nome Aluno", "Numero Cpf", "Co Ciclo Matricula", "Situacao Matricula",
#'   "No Curso", "Dt Data Inicio" and "Unidade Ensino".
#'  - On web: "NO_ALUNO", "NU_CPF", "CO_CICLO_MATRICULA", "NO_STATUS_MATRICULA", "NO_CICLO_MATRICULA",
#'  "DT_DATA_INICIO" and "CO_UNIDADE_ENSINO".
#'
#' Tip: To take every student for your institution/campus using web, search by student name and use " ".
#'
#' @examples
#' # this dataset is not a real one. It is just for test purpose.
#' sistec <- read_sistec(system.file("extdata/examples/sistec",
#'   package = "sistec"
#' ))
#'
#' sistec
#'
#' # example selecting the period
#' sistec_2019_2 <- read_sistec(
#'   system.file("extdata/examples/sistec", package = "sistec"),
#'   start = "2019.2"
#' )
#'
#' sistec_2019_2
#' @export
read_sistec <- function(path = "", start = NULL) {
  if (path == "") stop("You need to specify the path.")

  temp <- list.files(path = path, pattern = "*.csv")
  temp <- paste0(path, "/", temp)

  vars_setec <- c(
    "Nome Aluno", "Numero Cpf", "Co Ciclo Matricula", "Situa\u00e7\u00e3o Matricula",
    "No Curso", "Dt Data Inicio", "Unidade Ensino"
  )

  # using this while there is no CO_UNIDADE_ENSINO in sistec file
  vars_web_without_unidade_ensino <- c(
    "NO_ALUNO", "NU_CPF", "CO_CICLO_MATRICULA", "NO_STATUS_MATRICULA",
    "NO_CICLO_MATRICULA", "DT_DATA_INICIO"
  )
  
  vars_web <- c(
    "NO_ALUNO", "NU_CPF", "CO_CICLO_MATRICULA", "NO_STATUS_MATRICULA",
    "NO_CICLO_MATRICULA", "DT_DATA_INICIO", "CO_UNIDADE_ENSINO"
  )

  sep <- detect_sep(temp[1])

  vars_sistec <- names(utils::read.csv(temp[1],
    sep = sep, check.names = FALSE, header = TRUE, encoding = "UTF-8"
  ))

  num_vars_setec <- sum(vars_sistec %in% vars_setec)
  num_vars_web <- sum(vars_sistec %in% vars_web)
  num_vars_web_without_unidade_ensino <- sum(
    vars_sistec %in% vars_web_without_unidade_ensino
  )
  
  co_unidade_ensino_exist <- any(grepl("CO_UNIDADE_ENSINO$", vars_sistec))

  if (num_vars_setec > 0) {
    if (num_vars_setec < 7) {
      stop(paste(
        "Not found:", paste(vars_setec[!vars_setec %in% vars_sistec], collapse = ", ")
      ))
    } else {
      sistec <- read_sistec_setec(path)
    }
  } else if(co_unidade_ensino_exist){
    if (num_vars_web > 0) { 
      if (num_vars_web < 7) {
        stop(paste(
          "Not found:", paste(vars_web[!vars_web %in% vars_sistec], collapse = ", ")
        ))
      } else {
        encoding <- detect_encoding(temp[1], sep, "NO_CICLO_MATRICULA")
        sistec <- read_sistec_web(path, encoding, sep)
      }
    }
  } else if (num_vars_web_without_unidade_ensino > 0) {
    if (num_vars_web_without_unidade_ensino < 6) {
      stop(paste(
        "Not found:",
        paste(
          vars_web_without_unidade_ensino[!vars_web_without_unidade_ensino %in% vars_sistec],
          collapse = ", "
        )
      ))
    } else {
      encoding <- detect_encoding(temp[1], sep, "NO_CICLO_MATRICULA")
      sistec <- read_sistec_web_without_unidade_ensino(path, encoding, sep)
    }
  } else {
    stop("Not found Sistec variables in your file.")
  }

  sistec <- filter_sistec_date(sistec, start)
  sistec
}

#' @importFrom dplyr %>% sym
read_sistec_web <- function(path, encoding, sep) {
  temp <- list.files(path = path, pattern = "*.csv")
  temp <- paste0(path, "/", temp)

  co_unidade_ensino <- co_unidade_ensino()
  classes <- "character"

  sistec <- lapply(temp, utils::read.csv,
    sep = sep, stringsAsFactors = FALSE, colClasses = classes, encoding = encoding
  ) %>%
    dplyr::bind_rows() %>%
    dplyr::left_join(co_unidade_ensino, by = "CO_UNIDADE_ENSINO") %>%
    dplyr::transmute(
      S_NO_ALUNO = !!sym("NO_ALUNO"),
      S_NU_CPF = num_para_cpf(!!sym("NU_CPF")),
      S_CO_CICLO_MATRICULA = !!sym("CO_CICLO_MATRICULA"),
      S_NO_STATUS_MATRICULA = !!sym("NO_STATUS_MATRICULA"),
      S_NO_CURSO = correct_course_name(!!sym("NO_CICLO_MATRICULA")),
      S_DT_INICIO_CURSO = sistec_convert_beginning_date(!!sym("DT_DATA_INICIO")),
      S_NO_CAMPUS = !!sym("S_NO_CAMPUS")
    )

  class(sistec) <- c("sistec_data_frame", class(sistec))
  sistec
}

#' @importFrom dplyr %>% sym
read_sistec_web_without_unidade_ensino <- function(path, encoding, sep) {
  temp <- list.files(path = path, pattern = "*.csv")
  temp <- paste0(path, "/", temp)

  classes <- "character"
  
  sistec <- lapply(temp, utils::read.csv,
    sep = sep, stringsAsFactors = FALSE, colClasses = classes, encoding = encoding
  ) %>%
    dplyr::bind_rows() %>%
    dplyr::transmute(
      S_NO_ALUNO = !!sym("NO_ALUNO"),
      S_NU_CPF = num_para_cpf(!!sym("NU_CPF")),
      S_CO_CICLO_MATRICULA = !!sym("CO_CICLO_MATRICULA"),
      S_NO_STATUS_MATRICULA = !!sym("NO_STATUS_MATRICULA"),
      S_NO_CURSO = correct_course_name(!!sym("NO_CICLO_MATRICULA")),
      S_DT_INICIO_CURSO = sistec_convert_beginning_date(!!sym("DT_DATA_INICIO")),
      S_NO_CAMPUS = "SEM_CODIGO"
    )
  
  class(sistec) <- c("sistec_data_frame", class(sistec))
  sistec
}

#' @importFrom dplyr %>% sym
read_sistec_setec <- function(path, encoding = "UTF-8") {
  temp <- list.files(path = path, pattern = "*.csv")
  temp <- paste0(path, "/", temp)

  classes <- c(Numero.Cpf = "character")

  sistec <- lapply(temp, utils::read.csv,
    sep = ";", stringsAsFactors = FALSE, colClasses = classes, encoding = encoding
  ) %>%
    dplyr::bind_rows() %>%
    dplyr::transmute(
      S_NO_ALUNO = !!sym("Nome.Aluno"),
      S_NU_CPF = num_para_cpf(!!sym("Numero.Cpf")),
      S_CO_CICLO_MATRICULA = !!sym("Co.Ciclo.Matricula"),
      S_NO_STATUS_MATRICULA = !!sym("Situa\u00e7\u00e3o.Matricula"), # Situação.Matricula
      S_NO_CURSO = correct_course_name(!!sym("No.Curso")),
      S_DT_INICIO_CURSO = sistec_convert_beginning_date(!!sym("Dt.Data.Inicio")),
      S_NO_CAMPUS = sistec_campus_name(!!sym("Unidade.Ensino"))
    )

  class(sistec) <- c("sistec_data_frame", class(sistec))
  sistec
}

sistec_convert_beginning_date <- function(date) {
  first_slash <- stringr::str_locate_all(date[1], "/|-")[[1]][1]

  if (first_slash == 3) {
    year <- stringr::str_sub(date, 7, 10)
    month <- as.numeric(stringr::str_sub(date, 4, 5))
    semester <- ifelse(month > 6, 2, 1)
    paste0(year, ".", semester)
  } else {
    year <- stringr::str_sub(date, 1, 4)
    month <- as.numeric(stringr::str_sub(date, 6, 7))
    semester <- ifelse(month > 6, 2, 1)
    paste0(year, ".", semester)
  }
}

## It will be deprecated
# sistec_course_name <- function(course) {
#   course <- stringr::str_remove(course, " - .*$")
#   course <- stringr::str_replace_all(course, "\\\\|\"|/|:|\\?|\\.", "_")
# }

sistec_campus_name <- function(campus) {
  campus <- stringr::str_sub(campus, 42)
  sistec_correct_campus_name(campus)
}

sistec_correct_campus_name <- function(campus) {
  stringr::str_replace(campus, "REU E LIMA", "ABREU E LIMA")
}

filter_sistec_date <- function(x, start) {
  year_regex <- "[12][09][0-9]{2}.[12]"

  if (is.null(start)) {
    start <- min(
      stringr::str_extract(x$S_DT_INICIO_CURSO, year_regex),
      na.rm = FALSE
    )
  }

  dplyr::filter(x, !!sym("S_DT_INICIO_CURSO") >= start)
}
