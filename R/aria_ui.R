#' @rdname aria
#' @importFrom shiny fluidPage navbarPage tabPanel sidebarLayout sidebarPanel
#' @importFrom shiny tags br
#' @export
aria_ui <- function(version = "test") {
  fluidPage(
    navbarPage(
      paste0("ARIA v", aria_version()),
      tabPanel(
        "SISTEC",
        sidebarLayout(
          sidebarPanel(
            tags$head(tags$style(aria_head_tags())),
            aria_input_rfept(),
            aria_input_sistec(),
            aria_input_years(),
            br(),
            aria_input_compare_button(),
            aria_input_download_button()
          ),
          aria_main_panel(version)
        )
      ),
      tabPanel("MANUAL", manual_screen())
    )
  )
}

aria_head_tags <- function() {
  shiny::HTML(".shiny-input-container {margin-bottom: 0px} 
               .progress.active.shiny-file-input-progress { margin-bottom: 0px } 
               #year {margin-botton: 20px} 
               .checkbox { margin-top: 0px}")
}

aria_input_rfept <- function() {
  shiny::fileInput("rfept", "Escolha os arquivos do sistema acad\u00eamico",
    multiple = TRUE,
    buttonLabel = "Arquivos",
    placeholder = "Nada Selecionado",
    accept = c(
      "text/csv",
      "text/comma-separated-values,text/plain",
      ".csv"
    )
  )
}

aria_input_sistec <- function() {
  shiny::fileInput("sistec", "Escolha os arquivos do Sistec",
    multiple = TRUE,
    buttonLabel = "Arquivos",
    placeholder = "Nada Selecionado",
    accept = c(
      "text/csv",
      "text/comma-separated-values,text/plain",
      ".csv"
    )
  )
}

aria_input_years <- function() {
  years <- utils::read.csv(system.file("extdata/shiny/period_input.csv", package = "sistec"),
    header = TRUE, colClasses = "character"
  )

  shiny::selectInput("year", "Comparar a partir de:",
    choices = years$PERIOD,
    selected = "2019.1"
  )
}

aria_input_compare_button <- function() {
  shiny::div(
    style = "display: inline-block;vertical-align:top",
    shiny::uiOutput("compare_button")
  )
}

aria_input_download_button <- function() {
  shiny::div(
    style = "display: inline-block;vertical-align:top",
    shiny::uiOutput("download_button")
  )
}

aria_compare_button <- function() {
  shiny::actionButton("compare_button", "Comparar")
}

aria_download_button <- function(version) { 
  if (version == "desktop") {
    shiny::actionButton("download_offline", "Salvar resultados")
  } else {
    shiny::downloadButton("download_online", "Salvar resultados")
  }
}

#' @importFrom shiny mainPanel strong br htmlOutput
aria_main_panel <- function(version) { 
  if (version == "desktop") {
    mainPanel(
      strong(htmlOutput("contents")),
      br(), br(), br(), br(),
      strong(htmlOutput("download_offline"))
    )
  } else {
    mainPanel(
      strong(htmlOutput("contents"))
    )
  }
}
