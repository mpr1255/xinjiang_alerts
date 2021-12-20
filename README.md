# About the project

> DEPRECATED. 
> Stopped updating this; rewrote the code and started using SQLite backend; integrated xinjiang alerts into all my other alerts.

#####################################

This is an open source project written in `R` that checks the Google Alerts RSS feed for the terms 新疆 (Xinjiang) and 维吾尔 (Uyghur) hourly, and archives all results in both the Wayback Machine and saving the HTML. The HTML files are stored in this repo. CSV files also in this repo contain the wayback machine's archived link.

## How it works
The script checks `/code/ref_files/feeds.csv` every hour. That has search terms and the corresponding Google Alerts rss feed. This is the extensible side of the project --- you can add more search terms to that. I have a closed version tracking over a dozen keywords.

As best I can figure, a google alert is generated every time google finds a news article, web site, blog, or similar that mentions the target term. The entire RSS feed is eventually refreshed at indeterminate intervals (i.e. it does not accumulate to some arbitrary length). Thus, it needs to be checked regularly. Not to mention the entire point of this -- that we're trying to capture official and semi-official internet ephemera on sensitive topics, so we have to be quick.

Then, it opens that RSS feed, dumps all the URLs into `{topic}.csv`, eliminates duplicates, and goes through and archives them. It archives them in two ways: 

1. cURL to store locally(/on github); 
2. cURL to archive.org. 

I will probably add a twitter bot later so it also tweets out all the new links it's finding. 

## Why?
Because important data is quite often deleted soon after being published. I originally wrote this for my own topic, organ trafficking, but it is obviously useful for the Xinjiang issue so I'm making it public with that research community in mind. 

### Why cURL?
I tried monolith (https://github.com/Y2Z/monolith) and the html files it grabbed were indeed perfect -- but way too big. 8mb, 28mb etc. Just curling the text is orders of magnitude smaller. Assuming this will eventually grow to hundreds of thousands of links, it will get unwieldy. For historical purposes there may be a case for using monolith for perfect preservation of the content --- someone should do that and host it. 

## User guide
Several ways to use this: 

1. Just check the `data/{topic}` folder and you'll see a tonne of URLS -- that is going to get unwieldy soon though; 
2. Check the `data/xinjiang.csv` or `data/uyghur.csv` and you'll be able to see the title and excerpt that google alerts originally served up. You'll also see if there's a html file saved or not (and if it was successful; i.e. 0 or 1), plus the size of the html file. It's likely that very small files failed and what's saved is a corrupt file.
3. Clone the entire repo locally and get updates to your machine; 
4. etc.

# Low-hanging fruit for development
## better error checking
It could follow-up with missed articles better. The most extreme case would be searching their exact title through the google json custom search API or Baidu API and just archiving the top few results... 

## make it asynchronous
Whether in R or if it's rewritten in python, there's no good reason we should have to wait around for either curling the htmls to disk or the archive.org check. It would ideally be asynchronous. 

## host it
Really this should be running in a Rocker container on Github actions or as a cloud script in GCP. Just haven't been able to get to that. Plus, developing that and hosting it would cost.

Also, the curl would probably have to be made asynchronous to really make sense as a hosted solution. Right now, it has to wait every time it curls the archive.org link, and that takes time. Trying to do it asychronously (with WAIT=FALSE in the curl call or suppressing stdout) was unreliable. It has automatic timeouts both for the local curl and the archiving, but it's still slow. It would chew up a lot of minutes if I ran it on github actions or google cloud platform at present, as it churns and waits for every link. curl_fetch_multi() would do probably solve it.
