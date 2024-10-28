import crochet
import logging
import boto3
import scrapy
from flask import Flask, request, jsonify
from scrapy.crawler import CrawlerRunner
from scrapy.utils.project import get_project_settings
from twisted.python.failure import Failure
from scrapy import signals
from scrapy.signalmanager import dispatcher
from io import StringIO
import csv
from scrapy.exceptions import CloseSpider

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
        self.scraped_data = []  # Store scraped data in memory
        self.s3_client = boto3.client('s3')
        self.bucket_name = 'your-s3-bucket-name'  # Replace with your S3 bucket name

    def parse(self, response):
        for quote in response.css('div.quote'):
            data = {
                'text': quote.css('span.text::text').get(),
                'author': quote.css('small.author::text').get(),
                'tags': quote.css('div.tags a.tag::text').getall(),
            }
            self.scraped_data.append(data)
            yield data  # Still allows Scrapy to output items if needed

    def close(self, reason):
        """Called when the spider finishes, uploads data to S3."""
        if not self.scraped_data:
            raise CloseSpider("No data scraped")
        
        # Convert scraped data to CSV
        csv_buffer = StringIO()
        csv_writer = csv.DictWriter(csv_buffer, fieldnames=['text', 'author', 'tags'])
        csv_writer.writeheader()
        for row in self.scraped_data:
            row['tags'] = ','.join(row['tags'])  # Join tags list into a single string for CSV
            csv_writer.writerow(row)
        
        # Upload the CSV to S3
        self.upload_to_s3(csv_buffer.getvalue())

    def upload_to_s3(self, file_data):
        """Uploads the data to S3."""
        try:
            # Create a unique S3 object name using the spider name and timestamp
            s3_file_name = f"scraped_data/{self.name}-quotes.csv"
            
            # Upload the CSV data to the S3 bucket
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=s3_file_name,
                Body=file_data
            )
            self.logger.info(f"Uploaded data to S3 bucket '{self.bucket_name}' as '{s3_file_name}'")
        except Exception as e:
            self.logger.error(f"Failed to upload data to S3: {str(e)}")
            raise

# Handle results passed through signals
def handle_results(item, response, spider):
    scrape_results.append(item)

# Error handling for spider failures
def handle_spider_error(failure: Failure):
    logging.error(f"Spider encountered an error: {failure.getTraceback()}")

# Health check endpoint for readiness and liveness probes
@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "healthy"}), 200

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