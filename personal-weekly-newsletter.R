# Initialize ----
library(blastula) # Build email
library(stringr)  # String Manipulation
library(dplyr)    # Data Manipulation
library(purrr)    # Functional Programming
library(readr)    # Data Read/Write
library(httr2)    # HTTP Requests
library(xml2)     # XML Processing
library(gt)       # HTML Tables

# Scrape Blogs ----
message("Reading input CSV files...")
blogs = read_csv("blogs.csv", col_types = "ccc")
scraped_urls = read_csv("scraped_urls.csv", col_types = "c")

message("Creating requests for blog sitemaps...")
reqs = blogs |> 
  pull(host) |> 
  str_c("/sitemap.xml") |> 
  map(request)

message("Performing requests...")
resps = req_perform_sequential(reqs, on_error = "continue")

message("Extracting new posts from successful responses...")
extract_new_posts = function(resp) {

  site = str_remove(resp_url(resp), "/sitemap.xml")

  content = blogs |> 
    filter(host == site) |> 
    pull(content)

  regex_filter = str_c(site, "/", str_split(content, "\\|")[[1]], "/.", collapse = "|")

  xml = resp_body_xml(resp)
  ns = xml_ns(xml)

  urls_with_lastmod = xml_find_all(xml, ".//d1:url", ns = ns) # might have to switch "d1" with `names(ns[1])`

  results = site |> 
    tibble(
      url = urls_with_lastmod |> 
        xml_find_all(".//d1:loc", ns = ns) |> 
        xml_text()
    ) |>
    filter(
      # !url %in% scraped_urls$url,
      str_starts(url, regex_filter)
    ) |> 
    mutate(
      post = url |> 
        str_remove("/index[.]html") |> 
        str_remove(str_remove_all(regex_filter, "/[.](?=\\|)|/[.]$")) |> 
        str_replace_all("/", "-") |> 
        str_remove("\\d{4}-\\d{2}-\\d{2}") |> 
        str_replace_all("-", " ") |> 
        str_squish() |> 
        str_to_title(),
      post = if_else(post == "", "Post name failed to parse", post)
    )
  
  message(str_c("Extracted ", nrow(results), " new posts from ", site))
  return(results)
}

results = resps_successes(resps) |> 
  map(extract_new_posts) |> 
  list_rbind() |> 
  left_join(blogs |> select(-content), join_by(site == host))

message("Updating scraped URLs...")
results |> 
  select(url) |> 
  union(scraped_urls) |> 
  write_csv("scraped_urls.csv")

# Build Email ----
message("Building the email table...")
table = results |> 
  select(author, post, url) |> 
  gt() |> 
  tab_header(
    title = "Personal Weekly Newsletter",
    subtitle = format(Sys.Date(), "%B %m, %Y")
  ) |> 
  fmt_url(
    columns = url,
    label = from_column("post"),
    show_underline = FALSE
  ) |> 
  cols_hide(post) |>
  cols_label(
    author = "Author",
    url = "Post"
  ) |> 
  cols_width(
    author ~ px(125),
    url ~ px(475)
  )

# Send Email ----
message("Sending the email...")
tryCatch({
  smtp_send(
    email = compose_email(as_raw_html(table)),
    subject = str_c("Personal Weekly Newsletter | ", format(Sys.Date(), "%B %m, %Y")),
    to = Sys.getenv("OUTLOOK_EMAIL"),
    from = Sys.getenv("SMTP_USER"),
    credentials = creds_envvar(
      provider = "gmail",
      user = Sys.getenv("SMTP_USER"),
      pass_envvar = "SMTP_PASSWORD"
    ),
    verbose = TRUE
  )
  message("Email sent successfully.")
}, error = function(e) {
  message(str_c("Error sending email: ", e$message))
})

message("Script completed.")