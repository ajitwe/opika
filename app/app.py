import crochet
import logging
import scrapy
from flask import Flask, request, jsonify
from scrapy.crawler import CrawlerRunner
from scrapy.utils.project import get_project_settings
from twisted.python.failure import Failure
from scrapy import signals
from scrapy.signalmanager import dispatcher

# Initialize Crochet
crochet.setup()

# Set up logging
logging.basicConfig(level=logging.INFO)

# Initialize Flask
app = Flask(__name__)

# Initialize Scrapy's CrawlerRunner with Scrapy settings
runner = CrawlerRunner(get_project_settings())

# Global variable to store scraped results
scrape_results = []

class QuotesSpider(scrapy.Spider):
    name = "myspider"

    def __init__(self, url=None, *args, **kwargs):
        super(QuotesSpider, self).__init__(*args, **kwargs)
        self.start_urls = [url] if url else ['http://quotes.toscrape.com']

    def parse(self, response):
        for quote in response.css('div.quote'):
            yield {
                'text': quote.css('span.text::text').get(),
                'author': quote.css('small.author::text').get(),
                'tags': quote.css('div.tags a.tag::text').getall(),
            }

# Handle results passed through signals
def handle_results(item, response, spider):
    scrape_results.append(item)

# Error handling for spider failures
def handle_spider_error(failure: Failure):
    logging.error(f"Spider encountered an error: {failure.getTraceback()}")

# API endpoint to start scraping
@app.route('/scrape', methods=['POST'])
def scrape():
    global scrape_results
    scrape_results = []  # Reset results for each new scrape

    # Get the URL(s) from the POST request body
    data = request.get_json()
    urls = data.get('urls', [])

    if not urls:
        return jsonify({"error": "Please provide at least one URL"}), 400

    try:
        # Start the spider using Crochet for asynchronous handling
        run_spider(urls)
        return jsonify({"message": "Scraping started, check results endpoint for data."})
    except Exception as e:
        logging.error(f"Error while starting scraping: {str(e)}")
        return jsonify({"error": str(e)}), 500

# API endpoint to retrieve results after scraping
@app.route('/results', methods=['GET'])
def get_results():
    return jsonify(scrape_results)

# Run the Scrapy spider asynchronously using Crochet
@crochet.run_in_reactor
def run_spider(urls):
    # Connect Scrapy signals to collect results
    dispatcher.connect(handle_results, signal=signals.item_passed)

    # Run the spider, and handle errors using addErrback
    deferred = runner.crawl(QuotesSpider, url=urls[0])
    deferred.addErrback(handle_spider_error)

if __name__ == '__main__':
    # Start Flask app without the auto-reloader (which causes issues with Crochet)
    app.run(debug=True, use_reloader=False, host='0.0.0.0', port=5000)
