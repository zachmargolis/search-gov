# background

Some pages in the Analytics section require searches to have been conducted against
a site with some results being clicked. It also requires that logstash is set up
to process the logs generated by these search sessions. When working on these pages
it can be difficult to generate enough data in order to test changes to the reports
that drive the pages, and a way to generate fake search and click data can be
useful.

the analytics pages are:

* Site Overview - http://localhost:3000/sites/{site_id}
* Queries - http://localhost:3000/sites/{site_id}/queries/new
* Clicks - http://localhost:3000/sites/{site_id}/clicks/new
* Monthly Reports - http://localhost:3000/sites/{site_id}/monthly_reports

# usage

The logstash scripts that normally index search sesssions do so by creating
"search" documents and "click" documents in elasticsearch while parsing the
weblogs of [usasearch](https://github.com/GSA/usasearch) deployments. Running
the data generator rake tasks takes the place of logstash and issues its own
POST requests to your elasticsearch instance to generate "search" and "click"
documents for fake search sessions.

It works by first generating a pool of random search phrases along with their
results. Then it conducts a number of search sessions. For each search session
it randomly picks a search phrase from the pool and then randomly selects
some of the results for that search as clicks.

Some analytics pages distinguish human traffic from bot traffic. The logstash
scripts that parse weblogs index human traffic into one elasticsearch index
and both bot and human traffic into another elasticsearch index. Most of
the reports in the analytics section deal only with human-generated traffic,
so when working with those you might want to set up the rake tasks to only
generate human traffic by setting HUMAN_PROBABILITY_PCT to 100 (see the
"constants" section below).

## rake tasks

There are two rake tasks: one for generating data for just one day, and one for
generating data for the current month. The single-day rake task is suitable
for generating data when working on the Site Overview page, and the full-month
rake task is suitable for working on the rest of the analytics pages.

```
rake fake:searches:day[site_handle,variation_count,search_session_count]
rake fake:searches:month[site_handle,variation_count,search_session_count]
```

The `fake:searches:day` task generates search sessions for the current day,
and the `fake:searches:month` task generates search sessions for the
current month.

Each rake task takes three arguments: the site handle, variation count, and
search session count.

The site handle identifies which site the traffic is being generated for.
It's the `affiliates.name` value in the database for your site.

The variation count is the number of random search phrases (along with their
results) that are generated when building the search pool.

The search session count is how many searches the task should create. You
generally want to generate fewer search sessions for single-day analytics
testing and more search sessions for full-month analytics testing.

## constants

There are also three constants in `lib/tasks/fake_searches.rake` that control
aspects of the generated data. These are constants instead of rake task
arguments because they aren't expected to change much. These could be converted
to rake task arguments down the road if that turns out to be useful.

### HUMAN_PROBABILITY_PCT

This is the probability that any generated search session was performed by a
human (as opposed to a bot).

### RESULTS_PER_SEARCH

This is the number of results to generate for each random search phrase when
building the search pool. Set this to 0 in order to see results in the
"Queries with No Results" reports.

### CLICKS_PER_SEARCH

This is the number of clicks to generate for each search session. Set this
to a very low value in order to see results in the "Queries with Low Click
Thrus" reports.


## deleting analytics data

You may find it useful to remove all analytics data from time to time. You
can do this by deleting all the logstash indexes with the following command
which assumes that you're using a local elasticsearch instance on port 9200:

```
curl -sX DELETE 'http://localhost:9200/*logstash*'
```

# report thresholds

The "Queries with No Results" and "Queries with Low Click Thrus" reports
require certain thresholds to be met for queries to be included in them.

For Monthly Reports, a no-result query needs to occur at least 20 times to
show up, and a low-ctr query needs to occur at least 20 times to show up.

For the Site Overview (dashboard) page, a no-result query needs to occur at
least 10 times, and a low-ctr query needs to occur at least 20 times.

A good way to ensure thresholds are being met is to just use a search
pool that's much smaller than the number of search sessions, e.g.:

```
rake 'fake:searches:day[my_site,10,500]'
```

# search modules

It's important to have at least one search module set up in your database.

```
mysql> select * from search_modules;
+----+-------+------------------------+---------------------+---------------------+
| id | tag   | display_name           | created_at          | updated_at          |
+----+-------+------------------------+---------------------+---------------------+
|  1 | ISPEL | I14y spelling override | 2015-05-28 12:58:18 | 2015-05-28 12:58:18 |
|  2 | I14Y  | I14y document          | 2015-05-28 12:58:18 | 2015-05-28 12:58:18 |
|  3 | NEWS  | RSS Feeds              | 2015-07-09 14:57:18 | 2015-07-09 14:57:18 |
|  4 | QRTD  | Routed Query           | 2015-07-28 18:35:19 | 2015-07-28 18:35:19 |
+----+-------+------------------------+---------------------+---------------------+
4 rows in set (0.00 sec)
```

If there are no search modules in your database, then nothing will show up
in the Impressions and Clicks by Module report on the Monthly Reports page.
Also, a "search" document created with no modules component indicates to
analytics reports that there were no results for that search, so having no
modules configured could also interfere with testing the Queries with No
Results report on the Monthly Reports page.