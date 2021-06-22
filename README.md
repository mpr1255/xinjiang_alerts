# xinjiang_alerts
This is a simple script that is currently running locally. 

Ideally it would be developed further, and hosted remotely (for example, simply using GitHub Actions, or on GCP. The main reason I haven't done that is cost).* 

## How it works
The script checks `/code/ref_files/feeds.csv` every hour. That has search terms and the corresponding Google Alerts rss feed. This is the extensible side of the project --- you can add more search terms to that. I just used 新疆 and 维吾尔. 

As best I can figure, a google alert is generated every time google finds a news article, web site, blog, or similar that mentions the target term. The entire RSS feed is eventually refreshed at indeterminate intervals (i.e. it does not accumulate to some arbitrary length). Thus, it needs to be checked regularly. Not to mention the entire point of this -- that we're trying to capture official and semi-official internet ephemera on sensitive topics, so we have to be quick.

Then, it opens that RSS feed, dumps all the URLs into `{topic}.csv`, eliminates duplicates, and goes through and archives them. It archives them in two ways: 

1. cURL to store locally(/on github); 
2. cURL to archive.org. 

I will probably add a twitter bot later so it also tweets out all the new links it's finding. 

## Why?
Because important data is quite often deleted soon after being published. I originally wrote this for my own topic, organ trafficking, but it is obviously useful for the Xinjiang issue so I'm making it public with that research community in mind. 

### Why curl?
I tried monolith (https://github.com/Y2Z/monolith) and the html files it grabbed were indeed perfect -- but way too big. 8mb, 28mb etc. Just curling the text is orders of magnitude smaller. Assuming this will eventually grow to hundreds of thousands of links, it will get unwieldy. For historical purposes there may be a case for using monolith for perfect preservation of the content --- someone should do that and host it. 

## User guide
Several ways to use this: 

1. Just check the `data/{topic}` folder and you'll see a tonne of URLS -- that is going to get unwieldy soon though; 
2. Check the `data/xinjiang.csv` or `data/uyghur.csv` and you'll be able to see the title and excerpt that google alerts originally served up. You'll also see if there's a html file saved or not (and if it was successful; i.e. 0 or 1), plus the size of the html file. It's likely that very small files failed and what's saved is a corrupt file.
3. Clone the entire repo locally and get updates to your machine; 
4. etc.

# Low-hanging fruit for development
## integrate the archive link
Right now the curl packet goes off to archive the link, but I haven't tried to capture that and integrate it back into the csv file. That would be a good idea. 

That could also be done through the curl library inside R itself, but I just opted for the shell because it is simpler (and I was expecting to be able to do it asynchronously).

## better error checking
It could follow-up with missed articles better. The most extreme case would be searching their exact title through the google json custom search API or Baidu API and just archiving the top few results... 

* Some issues re cost and hosting: 
The code is not tight, it uses lots of dependencies, R is slow anyway, and it has to wait every time it curls the archive.org link. Why? Because trying to do it asychronously (with WAIT=FALSE in the curl call or suppressing stdout) was unreliable. It has automatic timeouts both for the local curl and the archiving, but it's still slow. It would chew up a lot of minutes if I ran it on github actions or google cloud platform or whatever. But yes, that would be better and feel free. 
