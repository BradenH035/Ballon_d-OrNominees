knitr::opts_chunk$set(echo = TRUE)

# Install packages
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
library(dplyr)

if (!requireNamespace("shiny", quietly = TRUE)) install.packages("shiny")
library(shiny)

if (!requireNamespace("plotly", quietly = TRUE)) install.packages("plotly")
library(plotly)

if (!requireNamespace("ggplot2", quietly = TRUE)) install.packages("ggplot2")
library(ggplot2)

if (!requireNamespace("rsconnect", quietly = TRUE)) install.packages("rsconnect")
library(rsconnect)

if (!requireNamespace("tidyverse", quietly = TRUE)) install.packages("tidyverse")
library(tidyverse)


rsconnect::setAccountInfo(
  name='bradenh035', 
  token='AE8A3D561FDA083A8ABF2580D6960E3B', 
  secret='TfIv3WSlUuG0gESXgvBPoKBuErc2umK9M3AOjF8x')

stats <- read_csv('https://raw.githubusercontent.com/BradenH035/Ballon_d-OrNominees/refs/heads/main/2024%20Ballon%20Dor%20Nominees%20League%20Stats.csv')

# Filter out relevant data
condensedStats <- data.frame(
  name = stats$player,
  age = stats$age,
  position = stats$pos,
  nation = stats$nation,
  team = stats$team,
  league = stats$league,
  matchesPlayed = stats$`Playing Time-MP`,
  starts = stats$`Playing Time-Starts`,
  totalMinutes = stats$`Playing Time-Min`,
  goals = stats$`Performance-Gls`,
  assists = stats$`Performance-Ast`,
  goalContributions = stats$`Performance-G+A`,
  yellowCards = stats$`Performance-CrdY`,
  redCards = stats$`Performance-CrdR`,
  avgPointsPerMatch = stats$`Team Success-PPM`,
  plusMinus = stats$`Team Success-+/-`,
  carries = stats$`Carries-Carries`,
  totalCarryDistance = stats$`Carries-TotDist`,
  tackles = stats$`Tackles-Tkl`,
  interceptions = stats$Int,
  xG_season = stats$`Expected-xG`,
  xA_season = stats$`Expected-xA`,
  ga_per90 = stats$`Per 90 Minutes-G+A`
)

condensedStats <- condensedStats |>
  mutate(
    avgMinutesPlayed = round(totalMinutes / matchesPlayed, 2),
    xGA_season = xG_season + xA_season,
    gaPerGame = round(goalContributions / matchesPlayed, 2)
  ) 

# Helper code from class
reset_selection <- function(x, brush) {
  brushedPoints(x, brush, allRows = TRUE)$selected_
}

histogram <- function(df, selected_) {
  df |>
    mutate(
      selected_ = selected_,
      tacklesAndInterceptions = tackles + interceptions) |>
    ggplot(aes(x = reorder(name, tacklesAndInterceptions), y = tacklesAndInterceptions, fill = position, alpha = as.numeric(selected_))) + 
    geom_bar(stat = "identity") +
    labs(title="Total Tackles and Interceptions", x="Player", y = "Count") +
    coord_flip() +
    theme(
      plot.title = element_text(size = 10),      
      axis.title.x = element_text(size = 8),
      axis.title.y = element_text(size = 8),
      legend.position = "none"
    )
}

scatterplot <- function(df, selected_) {
  (df %>%
     mutate(
       selected_ = selected_,
       position = factor(position, levels = c("FW", "FW,MF", "MF", "DF", "GK"))
     ) %>%
     ggplot(aes(x = totalMinutes / 100, y = goalContributions)) +
     geom_point(
       aes(
         alpha = as.numeric(selected_), 
         text = paste("Player:", name, "<br>",
                      "Team:", team, "<br>",
                      "League:", league, "<br>",
                      "Age:", age, "<br>",
                      "G/A per 90:", ga_per90)
       )
     ) +
     facet_grid(. ~ position) +
     xlim(15, 40) +
     labs(
       title = "Goal Contributions vs. Minutes Played (by Position)", 
       x = "Total Minutes Played (hundreds)", 
       y = "Goal Contributions"
     ) +
     theme(
       plot.title = element_text(size = 10),      
       axis.title.x = element_text(size = 8),     
       axis.title.y = element_text(size = 8),
       strip.text = element_text(size = 10),
       strip.background = element_rect(fill = "lightgray") 
     )) %>%
    ggplotly(tooltip = "text")
}

scatterplot2 <- function(df, selected_) {
  df |>
    mutate(selected_ = selected_) |>
    ggplot(aes(x = avgPointsPerMatch, y = plusMinus)) +
    geom_point(aes(col = position), size=2.5) + 
    labs(title = "Team Success: Individual Plus-Minus Rating vs. Points Won per Match", x = "Points Won (per match)", y = "Plus-Minus Rating") +
    scale_x_continuous(limits=c(1,3), breaks=seq(1,3, by=0.5)) +
    theme(
      plot.title = element_text(size = 10),      
      axis.title.x = element_text(size = 8),
      axis.title.y = element_text(size = 8)
    )
}


ui <- fluidPage(
  titlePanel("Ballon d'Or Nominees for the 2024 Season"),
  tabPanel("Notes", 
           h3("Notes:"),
           p("1. Goal Contributions: measures both goals and assists"),
           p('2. Each game is worth 0-3 points. A team will get 3 points for a win, 1 point for a tie, and 0 points for a loss. The statistic "Points won per match" represents the average point value this team earned per game. This award measures team success as well as individual greatness.'),
           p("3. Plus-Minus is a good way to measure the impact a player has on each game. All of these players have a positive impact on their teams, but some are more important to their team than others. A higher value here means that the team performs much better with this player than without them."),
           p("4. Positions: FW = Forward, MF = Midfield, DF = Defender, GK = Goalkeeper. Some players may play more than one position"),
           p("5. There is only one goalkeeper nominated for this award: Emiliano Martinez. He had a great performance in the World Cup, but it is difficult to compare him to the field players, since they share very few stats.")
  ),
  tabPanel("Select Input",
           selectInput("league", "Select a league", 
                       choices = c("All", unique(condensedStats$league)),
                       selected = "All")
  ),
  tabPanel("Faceted Plot", 
           fluidRow(
             column(12, plotlyOutput("scatter"))
           )
  ),
  
  tabPanel("Statistics",
           fluidRow(
             column(6, plotOutput("scatter2", brush = "plot_brush")),
             column(6, plotOutput("hist"))
           )
  ),
  tabPanel("Table",
           dataTableOutput("table")
  )
)

server <- function(input, output) {
  filteredData <- reactive({
    temp <- condensedStats
    if(!(input$league == "All")) {
      temp <- temp |> filter(league == input$league)
    }
    temp
  })
  
  selected <- reactiveVal(rep(TRUE, nrow(condensedStats)))
  
  observeEvent(filteredData(), {
    selected(rep(TRUE, nrow(filteredData())))
  })
  
  observeEvent(
    input$plot_brush,
    selected(reset_selection(filteredData(), input$plot_brush))
  )
  
  output$scatter <- renderPlotly({
    scatterplot(filteredData(), selected())
  })
  
  output$hist <- renderPlot({
    histogram(filteredData(), selected())
  })
  
  output$scatter2 <- renderPlot({
    scatterplot2(filteredData(), selected())
  })
  
  output$table <- renderDataTable({
    filteredData() |>
      filter(selected()) |>
      select(name, team, league, matchesPlayed, goals, assists, yellowCards, redCards, carries, totalCarryDistance, tackles, interceptions, gaPerGame)
  })
}

shinyApp(ui, server)