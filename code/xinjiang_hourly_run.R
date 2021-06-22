suppressMessages(library(xml2))
suppressMessages(library(tidyverse))
suppressMessages(library(data.table))
suppressMessages(library(glue))
suppressMessages(library(rvest))
suppressMessages(library(curl))
suppressMessages(library(here))
######################

dir <- here()
data_dir <- paste0(dir,"/data/")
code_dir <- paste0(dir,"/code/")

feeds <- fread(paste0(code_dir,"ref_files/feeds.csv"))
print(glue("getting feeds...."))
print(feeds)
feedlist <- map(feeds$rss, ~read_html(.x))
timenow <- strftime(Sys.time(), format="%Y%m%d%H%M")
# map(feedlist, ~as.character(.x)) %>% write_lines(glue("{data_dir}/feed_dumps/feed_dump_hourly_{timenow}.html"))

topics <- feeds$en

for (i in topics){
  if (!dir.exists(paste0(data_dir,i))){
    dir.create(paste0(data_dir,i))
  }
}

for (i in 1:nrow(feeds)){

  col1 <- NULL
  df1 <- data.frame(col1,stringsAsFactors = FALSE)
  
  data <- read_html(feeds[i]$rss)
  topic <- feeds[i]$en
  
  print(glue("starting topic '{topic}'"))
  
  links <- xml_find_all(data, "//link") %>% xml_attr("href")
  
  if(length(links) < 2){
    next
    print("no links, going to next")
  }
  
  links <- str_remove(links, "https\\:\\/\\/www\\.google\\.com\\/url\\?rct\\=j&sa\\=t&url\\=")
  links <- links[2:length(links)]
  links <- gsub("(.*?)\\&.*$", "\\1", links)
  dflinks <- data.frame(links)
  
  titles <- xml_find_all(data, "//title")
  titles <- titles %>% xml_text()
  titles <- titles[2:length(titles)]
  titles <- str_remove_all(titles, "\\<b\\>")
  titles <- str_remove_all(titles, "\\<\\/b\\>")
  titles <- str_remove_all(titles, "\\/")
  titles <- str_remove_all(titles, "\\(")
  titles <- str_remove_all(titles, "\\)")
  titles <- str_remove_all(titles, "\\W+")
  titles <- str_remove_all(titles, "\\p{Arabic}")
  
  dftitles <- data.frame(titles)

  pubdates <- xml_find_all(data, "//published") %>% xml_text()
  pubdates <- gsub("\\:", "-", pubdates)
  pubdates <- gsub("T", "--", pubdates)
  pubdates <- gsub("Z", "", pubdates)
  dfpubdates <- data.frame(pubdates)

  content <- xml_find_all(data, "//content") %>% xml_text()
  content <- str_remove_all(content, "\\p{Arabic}")
  dfcontent <- data.frame(content)
  
  timenow <- strftime(Sys.time(), format="%Y%m%d%H%M")
  
  html_file_names <- paste0(substr(titles, 1, 20),"---", pubdates,".html")
  html_file_names <- tibble(html_file_names)
  df_for_output <- bind_cols(dflinks, dftitles, dfpubdates, dfcontent, html_file_names)
  
  fwrite(df_for_output, paste0(data_dir,topic,".csv"), append=TRUE)
  
  df_input <- fread(paste0(data_dir, topic, ".csv"), fill = TRUE)
  
  df_input <- df_input %>% distinct(links, .keep_all = TRUE)
  
  df_input <- df_input %>% 
    mutate(html_file_names = str_remove_all(html_file_names, "\\/"))
  
  fwrite(df_input, paste0(data_dir,topic,".csv"))

  
  for (j in 1:nrow(df_input)){

    cur_url <- df_input$links[j]
    print(glue("working on {cur_url}"))
    file_name <- df_input$html_file_names[j]
    file_name_dir <- paste0(data_dir,topic,"/",file_name) 
    
    timenow <- strftime(Sys.time(), format="%Y%m%d%H%M")
    if(!file.exists(file_name_dir)){
      tryCatch(
        expr = {
          # system(glue("./monolith-gnu-linux-x86_64 {cur_url} -o {file_name_dir} -s"))
          system(glue("curl {cur_url} -o {file_name_dir}"))
          message(glue("wrote    {file_name} | {timenow}"))
        },
        error = function(e){
          message(glue("error    {file_name} | {timenow}"))
          print(e)
        },
        warning = function(w){
          message(glue("warning  {file_name} | {timenow}"))
          print(w)
        }
      )
    }
    
    
    tryCatch(
      expr = {
        # system(glue("./monolith-gnu-linux-x86_64 {cur_url} -o {file_name_dir} -s"))
        file_status <- ifelse(grepl("您要找的资源已被删除", read_file(file_name_dir)), 0, 1)
        file_size <- round(file.size(file_name_dir)/1000)
        df_input$file_status[j] <- file_status
        df_input$file_size[j] <- file_size
      },
      error = function(e){
        message(glue("error    {file_name} | {timenow}"))
        # print(e)
      },
      warning = function(w){
        message(glue("warning  {file_name} | {timenow}"))
        # print(w)
      }
    )
    
    var <- df_input$sent_to_archive[j]
    
    if(identical(NA, var)){
      print("var is NULL. sending it to archive.org")
      system(glue("curl -s -I https://web.archive.org/save/{cur_url}"))
      df_input$sent_to_archive[j] <- TRUE
    }else if(identical(NA, var)){
      print("var is NA. sending it to archive.org")
      system(glue("curl -s -I https://web.archive.org/save/{cur_url}"))
      df_input$sent_to_archive[j] <- TRUE
    }else if(identical(FALSE, var)){
      print("var is FALSE. sending it to archive.org")
      system(glue("curl -s -I https://web.archive.org/save/{cur_url}"))
      df_input$sent_to_archive[j] <- TRUE
    }else if(identical(TRUE, var)){
      print("var TRUE. sent to archive already")
    }
      
    # this is still in the j loop.
  }
  fwrite(df_input, paste0(data_dir,topic,".csv")) # end of the j loop; it's going to write out everything that happened in the j
  # this is in the i loop
}
