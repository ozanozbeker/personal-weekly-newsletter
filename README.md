# Personal Weekly Newsletter

Cal Newport discusses the concept of creating your own personal weekly newsletter in his podcast, [Deep Questions](https://www.thedeeplife.com/listen/). I liked the idea so this is my effort to implement it in my effort of living the "deep life".

This single document project scrapes my favorite blogs to see if there are new posts, and sends myself a weekly email notifying which blogs have new posts, with a link.

## Scraping the Blogs

The blogs I'm currently reading are listed in `blogs.csv`. While I call it blogs, some authors also have talks and projects that I'm also interested in.

Instead of scraping the listings page page of each blog, which can vary across blogs, this script just looks at the sitemap of the blogs to see if new articles have been created since the previous week. Sitemaps can usually be found in the `sitemap.xml` or `sitemap_index.xml` file. I keep a track of the posts that have been in my newsletter already in `scraped_urls.csv`. 

-   I was originally going to use the timestamp/lastmod/etc., but while going through different blogs I noticed that the lastmod changes for posts very differently based on how the website is publish, so using the mod time is not a reliable method. For now,  the `scraped_urls.csv` will work and maybe I'll come up with a better method later if the file becomes too big. The biggest downfall of this method is that the first time a blog is scraped, every article in its history is added to the newsletter, but it's not the end of the world.

## Build & Send Email

[{gt}](https://gt.rstudio.com/) will create an HTML table which will be the body of the email, [{blastula}](https://rstudio.github.io/blastula/index.html) will send the email using my Gmail account for SMTP, & GitHub actions will create a runner weekly to run the code.
