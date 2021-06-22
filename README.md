# xinjiang_alerts
This is a simple script that is currently running locally. 

Ideally it would be developed further, and hosted remotely (for example, simply using GitHub Actions, or on GCP. The main reason I haven't done that is cost).* 

## How it works
The script checks `feeds.csv` every hour. That has search terms and the corresponding Google Alerts rss feed. This is the extensible side of the project --- you can add more search terms to that. I just used 新疆 and 维吾尔. 

As best I can figure, a google alert is generated every time google finds a news article, web site, blog, or similar that mentions the target term. The entire RSS feed is eventually refreshed at indeterminate intervals (i.e. it does not accumulate to some arbitrary length). Thus, it needs to be checked regularly. Not to mention the entire point of this -- that we're trying to capture official and semi-official internet ephemera on sensitive topics, so we have to be quick.

Then, it opens that RSS feed, dumps all the URLs into `{topic}.csv`, eliminates duplicates, and goes through and archives them. It archives them in two ways: 

1. cURL to store locally(/on github); 
2. cURL to archive.org. 

I will probably add a twitter bot later so it also tweets out all the new links it's finding. 

## Why?
Because important data is quite often deleted soon after being published. I originally wrote this for my own topic, organ trafficking, but it is obviously useful for the Xinjiang issue so I'm making it publish with that research community in mind. 

## User guide
Several ways to use this: 

1. Just check the data/{topic} folder and you'll see a tonne of URLS -- that is going to get unwieldy soon though; 
2. Check the xinjiang.csv and you'll be able to see the title and excerpt that google alerts originally served up. You'll also see if there's a html file saved or not (and if it was successful; i.e. 0 or 1), plus the size of the html file. It's likely that very small files failed and what's saved is a corrupt file.
3. Clone the entire repo locally and get updates to your machine; 
4. Etc.

* Some issues re cost and hosting: 
The code is not tight, it uses lots of dependencies, R is slow anyway, and it has to wait every time it curls the archive.org link. Why? Because trying to do it asychronously (with WAIT=FALSE in the curl call or suppressing stdout) was unreliable. It has automatic timeouts both for the local curl and the archiving, but it's still slow. It would chew up a lot of minutes if I ran it on github actions or google cloud platform or whatever. But yes, that would be better.