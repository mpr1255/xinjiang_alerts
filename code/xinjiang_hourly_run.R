suppressMessages(library(xml2))
suppressMessages(library(tidyverse))
suppressMessages(library(data.table))
suppressMessages(library(glue))
suppressMessages(library(rvest))
suppressMessages(library(curl))
suppressMessages(library(here))
suppressMessages(library(urltools))
######################

# I have to do this to make it work. OK?
if(dir.exists("/home/a/")){
  dir <- "/home/a/projects/xinjiang_alerts/"
}else{
  dir <- "/mnt/c/projects/xinjiang_alerts/"
}

data_dir <- paste0(dir,"data/")
code_dir <- paste0(dir,"code/")

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
    print(paste("creating dir",paste0(i)))
    
  }
}

for (i in topics){
  if (!file.exists(paste0(data_dir,i,".csv"))){
    file.create(paste0(data_dir,i,".csv"))
    print(paste("creating",paste0(i,".csv")))
  }
}


for (i in 1:nrow(feeds)){

  col1 <- NULL
  df1 <- data.frame(col1,stringsAsFactors = FALSE)
  
  data <- read_html(feeds[i]$rss)
  topic <- feeds[i]$en
  
  print(glue("starting topic '{topic}'"))
  
  links <- xml_find_all(data, "//link") %>% xml_attr("href")
  
  links <- links[!str_detect(links,pattern="alerts\\/feeds")]
  links <- links[str_detect(links,pattern="http")]
  
  if(length(links) > 0){
    
    links <- str_remove(links, "https\\:\\/\\/www\\.google\\.com\\/url\\?rct\\=j&sa\\=t&url\\=")
    links <- gsub("(.*?)\\&.*$", "\\1", links)
    links <- map_chr(links, ~url_decode(.x))
    
    
    dflinks <- tibble(links)
    
    titles <- xml_find_all(data, "//title")
    titles <- titles %>% xml_text()
    titles <- titles[2:length(titles)]
    titles <- str_remove_all(titles, "\\<b\\>")
    titles <- str_remove_all(titles, "\\<\\/b\\>")
    titles <- str_remove_all(titles, "\\/")
    titles <- str_remove_all(titles, "\\(")
    titles <- str_remove_all(titles, "\\)")
    titles <- str_replace_all(titles, "\\W+", " ")
    titles <- str_remove_all(titles, "\\p{Arabic}")
    
    dftitles <- tibble(titles)
    
    pubdates <- xml_find_all(data, "//published") %>% xml_text()
    pubdates <- gsub("\\:", "-", pubdates)
    pubdates <- gsub("T", "--", pubdates)
    pubdates <- gsub("Z", "", pubdates)
    dfpubdates <- tibble(pubdates)
    
    content <- xml_find_all(data, "//content") %>% xml_text()
    content <- str_remove_all(content, "\\p{Arabic}")
    dfcontent <- tibble(content)
    
    timenow <- strftime(Sys.time(), format="%Y%m%d%H%M")
    
    html_file_names <- paste0(substr(titles, 1, 20),"---", pubdates,".html")
    html_file_names <- tibble(html_file_names)
    df_for_output <- bind_cols(dflinks, dftitles, dfpubdates, dfcontent, html_file_names)
    
    fwrite(df_for_output, paste0(data_dir,topic,".csv"), append=TRUE)
    
  }
  
  if(identical(character(0),read_lines(paste0(data_dir, topic, ".csv")))){
    print("df input is empty")
    next
  }
  
  df_input <- fread(paste0(data_dir, topic, ".csv"), fill = TRUE)
  # names(df_input) <- c("links","titles","pubdates","content","html_file_names")
  
  # ,"file_status","file_size","sent_to_archive"
  
  if(nrow(df_input) == 0){
    print("df input is empty")
    next
  }
  
  
  
  df_input <- df_input %>% distinct(links, .keep_all = TRUE)
  
  df_input <- df_input %>% 
    filter(str_detect(links, pattern="http|www"))
  
  df_input <- df_input %>% 
    mutate(html_file_names = str_remove_all(html_file_names, "\\/"),
           links = map_chr(links, ~url_decode(.x))) 
  
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
    }else{
      print(glue("{file_name} exists"))
    }
    
    
    tryCatch(
      expr = {
        file_size <- round(file.size(file_name_dir)/1000)
        
        file_status <- ifelse(grepl("您要找的资源已被删除", read_file(file_name_dir)), 0, 1)
        file_status <- ifelse(file_size > 5, 1, 0)
        
        df_input$file_status[j] <- file_status
        df_input$file_size[j] <- file_size
        
        if(file_status == 0){
          print("problem with the file...")
        }
        
        
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
    
    archiveit <- function(x){
      print("checking archiving and archiving if necessary....")
      
      checkarchive <<- curl_fetch_disk(glue("http://archive.org/wayback/available?url={x}"), tempfile())
      parsed_response <<- jsonlite::parse_json(read_lines(checkarchive$content))
      
      if(length(parsed_response$archived_snapshots) == 0){
        print("there is no archive url. Trying now...")
        archive <<- curl_fetch_disk(glue("https://web.archive.org/save/{x}"), tempfile())
        
        if(archive$status_code == 200){
          print(glue("archive successful: adding {archive$url}"))
          df_input$sent_to_archive[j] <<- archive$url
        }else{
          print("archive failed!")
          df_input$sent_to_archive[j] <<- glue("failed | {timenow}")
        }
        
      }else if(parsed_response$archived_snapshots$closest$available == TRUE){
        print("archive url is available")
        archiveurl <<- parsed_response$archived_snapshots$closest$url[1]
        df_input$sent_to_archive[j] <<- archiveurl
        
      }else{
        print("the parsed response is empty but there's no URL available. That ain't right. Need to check this.")
      }
    } #end archiveit function
    
    tryCatch(
      expr = {

        if(!grepl("web\\.archive", var)){
          if(!grepl("failed", var)){
            print("archiving....")
            archiveit(cur_url)
          }else{
            print("archive previously failed")
          }
        }else{
            print("already archived")
          }
          # if(identical(NULL, var)){
          #   archiveit(cur_url)
          # }else if(identical(NA, var)){
          #   archiveit(cur_url)
          # }else if(identical(FALSE, var)){
          #   archiveit(cur_url)
          # }else if(identical(TRUE, var)){
          #   archiveit(cur_url)
          # }else if(grepl("TRUE", var)){
          #   archiveit(cur_url)
          # }else if(var == ""){
          #   archiveit(cur_url)
          # }
          # else if (grepl("failed", var)){
          #   print(paste0("archive previously failed on", str_split(var, '\\|')[[1]][2], " but trying again anyway"))
          #   archiveit(cur_url)
          # }
      }, # this is for expr
        error = function(e){
          message(glue("error    {cur_url} archive fail | {timenow}"))
          print(e)
        },
        warning = function(w){
          message(glue("warning  {cur_url} archive fail | {timenow}"))
          print(w)
        }
      )
      
    
  
  } # close j loop
  
  fwrite(df_input, paste0(data_dir,topic,".csv")) # end of the j loop; it's going to write out everything that happened in the j
  
} # close i loop

