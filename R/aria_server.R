#' @rdname aria
#' @importFrom shiny isolate
#' @export
aria_server <- function(version = "test", logs = TRUE) {
  function(input, output, session) {
    # close the R session when Chrome closes
    session$onSessionEnded(function() {
      if (version == "desktop") {
        shiny::stopApp()
        q("no")
      }
    })

    comparison <- shiny::reactiveValues(x = FALSE)
    aria_values <- shiny::reactiveValues(
      temp_dir = tempdir(),
      download_count = 0,
      session_id = generate_session_id()
    )

    # delete files and reload the app after download ARIA output
    shiny::observeEvent(aria_values$download_count, {
        unlink(paste0(aria_values$temp_dir, "/", aria_values$session_id), recursive = TRUE)
        comparison$x <- FALSE
        if (version != "desktop") {
          session$reload()
        }
      },
      ignoreInit = TRUE
    )

    output$download_online <- shiny::downloadHandler(
      filename = "ARIA.zip",
      content = function(file) {
        # go to a temp dir to avoid permission issues

        if (isolate(aria_values$download_count == 0)) {
          owd <- setwd(aria_values$temp_dir)
          on.exit(setwd(owd))
          files <- NULL

          write_output(
            x = isolate(comparison$x),
            output_path = paste0(aria_values$temp_dir, "/", aria_values$session_id),
            output_folder_name = "ARIA"
          )

          aria_values$download_count <- 1

          # create the zip file
          if_windows <- tolower(Sys.getenv("SystemRoot"))
          if (grepl("windows", if_windows)) {
            shell(paste0(
              "cd ", aria_values$session_id, "&& zip -r ",
              file, " ARIA"
            ))
          } else {
            system(paste0(
              "cd ", aria_values$session_id, "; zip -r ",
              file, " ARIA"
            ))
          }
        } else {
          if (version != "desktop") {
            session$reload()
          }
        }
      }
    )

    output$download_offline <- shiny::renderText({
      if (is.null(input$download_offline)) {
        return()
      }
      if (input$download_offline == 0) {
        return()
      }

      if (is.list(isolate(comparison$x))) {
        if_windows <- tolower(Sys.getenv("SystemRoot"))
        if (grepl("windows", if_windows)) {
          output_path <- utils::choose.dir()
          output_path <- gsub("\\\\", "/", output_path)
        } else {
          output_path <- tcltk::tk_choose.dir()
        }

        # output_path <- shiny_output_path(output_path)

        write_output(
          x = isolate(comparison$x),
          output_path = output_path,
          output_folder_name = "ARIA"
        )

        "Download realizado com sucesso!"
      } else {
        ""
      }
    })


    output$contents <- shiny::renderText({
      if (logs == TRUE) {
        aria_logs(
          aria_values$session_id,
          input$rfept$datapath[1],
          input$sistec$datapath[1],
          comparison$x,
          aria_values$temp_dir,
          aria_values$download_count
        )
      }

      if (is.null(input$compare_button)) {
        comparison$x <- FALSE
      } else if (isolate(input$compare_button == 0)) {
        comparison$x <- FALSE
      } else {
        comparison$x <- isolate(
          shiny_comparison(
            input$sistec$datapath[1],
            input$rfept$datapath[1],
            input$year
          )
        )
      }

      isolate(output_screen(
        input$sistec$datapath[1],
        input$rfept$datapath[1],
        comparison$x
      ))
    })

    output$compare_button <- shiny::renderUI({
      if (all(
        !is.null(input$sistec$datapath[1]),
        !is.null(input$rfept$datapath[1])
      )) {
        aria_compare_button()
      }
    })

    output$download_button <- shiny::renderUI({
      if (!is.null(input$compare_button)) {
        if (input$compare_button != 0) {
          aria_download_button(version)
        }
      }
    })
  }
}
